import Foundation
import AVFoundation
import MediaPlayer

/// Manages a single AVPlayer instance for one audio stream, with panning via MTAudioProcessingTap.
final class StreamPlayerHandle {
    let streamID: UUID
    private(set) var player: AVPlayer
    private var panValue: Float = 0.0
    private var currentPanBox: PanBox?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?

    /// The current RMS level (0…1 linear) as measured by the audio tap.
    var currentLevel: Float { currentPanBox?.currentLevel ?? 0.0 }

    /// Called on the main queue when playback fails.
    var onPlaybackFailed: ((UUID, String) -> Void)?

    /// Called on the main queue whenever the player's timeControlStatus changes.
    var onTimeControlStatusChanged: ((UUID, AVPlayer.TimeControlStatus) -> Void)?

    init(stream: AudioStream, credentials: BroadcastifyCredentials?) {
        self.streamID = stream.id
        self.panValue = stream.panMode.panValue
        let playerItem = StreamPlayerHandle.makePlayerItem(for: stream, credentials: credentials)
        self.player = AVPlayer(playerItem: playerItem)
        self.player.volume = stream.volume
        observeItemStatus(playerItem)
        observeTimeControlStatus()
    }

    func play()  { player.play() }

    func pause() {
        player.pause()
        currentPanBox?.currentLevel = 0.0  // clear meter when paused
    }

    func updateVolume(_ volume: Float) {
        player.volume = volume
    }

    func updatePan(_ pan: Float) {
        guard panValue != pan,
              let item = player.currentItem else { return }
        panValue = pan
        currentPanBox?.currentLevel = 0.0
        currentPanBox = nil
        let newItem = rebuildItem(from: item)
        player.replaceCurrentItem(with: newItem)
        observeItemStatus(newItem)
    }

    // MARK: - Private

    /// Observes item status for two purposes:
    /// 1. Install the metering+panning tap once tracks are confirmed available (readyToPlay).
    /// 2. Surface playback errors to the caller.
    private func observeItemStatus(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .readyToPlay:
                guard self.currentPanBox == nil else { return }
                let box = StreamPlayerHandle.installTap(pan: self.panValue, on: item)
                DispatchQueue.main.async { self.currentPanBox = box }
            case .failed:
                let raw = item.error as NSError?
                let message: String
                if raw?.code == NSURLErrorUserAuthenticationRequired ||
                   raw?.code == NSURLErrorUserCancelledAuthentication {
                    message = "Authentication failed. Check your Broadcastify credentials in Settings."
                } else {
                    message = raw?.localizedDescription ?? "The stream could not be loaded."
                }
                DispatchQueue.main.async { self.onPlaybackFailed?(self.streamID, message) }
            default:
                break
            }
        }
    }

    /// Observes AVPlayer.timeControlStatus so the caller can update Now Playing when
    /// the stream transitions from buffering → actually playing.
    private func observeTimeControlStatus() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.onTimeControlStatusChanged?(self.streamID, player.timeControlStatus)
            }
        }
    }

    private func rebuildItem(from old: AVPlayerItem) -> AVPlayerItem {
        guard let urlAsset = old.asset as? AVURLAsset else { return old }
        return AVPlayerItem(asset: urlAsset)
    }

    private static func makePlayerItem(for stream: AudioStream, credentials: BroadcastifyCredentials?) -> AVPlayerItem {
        guard var components = URLComponents(string: stream.url) else {
            return AVPlayerItem(url: URL(string: stream.url)!)
        }
        if stream.isBroadcastify, let creds = credentials, !creds.isEmpty {
            components.user     = creds.username
            components.password = creds.password
        }
        let url = components.url ?? URL(string: stream.url)!
        return AVPlayerItem(url: url)
    }

    /// Attaches a metering + panning MTAudioProcessingTap to `item`.
    /// Uses trackless AVMutableAudioMixInputParameters (trackID = kCMPersistentTrackID_Invalid)
    /// so it works for live HTTP streams where AVPlayerItemTrack.assetTrack is nil.
    private static func installTap(pan: Float, on item: AVPlayerItem) -> PanBox {
        let panBox = PanBox(pan: pan)
        let panBoxPtr = Unmanaged.passRetained(panBox)

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: panBoxPtr.toOpaque(),
            init: { _, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                let ptr = MTAudioProcessingTapGetStorage(tap)
                Unmanaged<PanBox>.fromOpaque(ptr).release()
            },
            prepare: nil,
            unprepare: nil,
            process: { tap, numberFrames, flags, bufferListInOut, numberFramesOut, flagsOut in
                MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)

                let ptr = MTAudioProcessingTapGetStorage(tap)
                let box = Unmanaged<PanBox>.fromOpaque(ptr).takeUnretainedValue()
                let p = box.pan

                // ── RMS metering (always, before any pan gain) ──────────────────
                var sumOfSquares: Float = 0.0
                var sampleCount: Int = 0
                let bufCount = Int(bufferListInOut.pointee.mNumberBuffers)
                for bufIdx in 0..<bufCount {
                    withUnsafeMutablePointer(to: &bufferListInOut.pointee.mBuffers) { base in
                        let buf = (base + bufIdx).pointee
                        guard let data = buf.mData else { return }
                        let frames = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                        let samples = data.bindMemory(to: Float.self, capacity: frames)
                        if buf.mNumberChannels == 2 || bufIdx == 0 {
                            for i in 0..<frames { sumOfSquares += samples[i] * samples[i] }
                            sampleCount += frames
                        }
                    }
                }
                box.currentLevel = sampleCount > 0 ? sqrtf(sumOfSquares / Float(sampleCount)) : 0.0

                // ── Pan gain (skipped for center/stereo) ────────────────────────
                guard p != 0.0 else { return }
                let leftGain  = p <= 0 ? Float(1.0) : Float(1.0 - p)
                let rightGain = p >= 0 ? Float(1.0) : Float(1.0 + p)

                for bufIdx in 0..<Int(bufferListInOut.pointee.mNumberBuffers) {
                    withUnsafeMutablePointer(to: &bufferListInOut.pointee.mBuffers) { base in
                        let buf = (base + bufIdx).pointee
                        guard let data = buf.mData else { return }
                        let frames = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                        let samples = data.bindMemory(to: Float.self, capacity: frames)

                        if buf.mNumberChannels == 2 {
                            var i = 0
                            while i + 1 < frames {
                                samples[i]     *= leftGain
                                samples[i + 1] *= rightGain
                                i += 2
                            }
                        } else if bufIdx == 0 {
                            for i in 0..<frames { samples[i] *= leftGain }
                        } else if bufIdx == 1 {
                            for i in 0..<frames { samples[i] *= rightGain }
                        }
                    }
                }
            }
        )

        var tapOut: MTAudioProcessingTap? = nil
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tapOut)
        guard status == noErr, let tap = tapOut else {
            panBoxPtr.release()
            return panBox
        }

        // trackID = kCMPersistentTrackID_Invalid → applies to all audio tracks
        let params = AVMutableAudioMixInputParameters()
        params.audioTapProcessor = tap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        item.audioMix = mix

        return panBox
    }
}

// MARK: - PanBox (heap-allocated state for C callback)

private final class PanBox {
    var pan: Float
    // Written from the audio thread, read from the main thread.
    // Float reads/writes are atomic on ARM64 — no lock needed.
    var currentLevel: Float = 0.0
    init(pan: Float) { self.pan = pan }
}

// MARK: - AudioStreamPlayer (manages all active stream handles)

final class AudioStreamPlayer: ObservableObject {
    static let shared = AudioStreamPlayer()

    /// Publishes `(streamID, errorMessage)` whenever a stream fails. Observed by StreamsViewModel.
    @Published var lastFailure: (UUID, String)?

    /// RMS level (0…1 linear) per stream, refreshed every ~100 ms.
    @Published var levels: [UUID: Float] = [:]

    /// Streams whose player is trying to play but still buffering.
    @Published var bufferingStreams: Set<UUID> = []

    /// Called on the main queue when all streams are paused via a remote command (lock screen / Control Center).
    var onRemoteCommandPauseAll: (() -> Void)?

    private var handles: [UUID: StreamPlayerHandle] = [:]
    private var playingStreamIDs: Set<UUID> = []   // explicit source of truth for Now Playing count
    private var meterTimer: Timer?

    // MARK: - Sidechain ducking

    private var streamRoles: [UUID: StreamRole] = [:]
    /// Linear duck level applied to Secondary streams when any Primary is hot. Set from ViewModel.
    private var duckLevelLinear: Float = pow(10.0, -12.0 / 20.0)
    /// Current ramp position: 1.0 = fully unduck, duckLevelLinear = fully ducked.
    private var currentDuckMultiplier: Float = 1.0
    /// -30 dBFS: 10^(-30/20) ≈ 0.03162 — threshold for Primary "hot" detection.
    private static let primaryThreshold: Float = 0.03162

    private init() {
        // Must activate the playback audio session before anything else;
        // without this iOS will not surface Now Playing or lock-screen controls.
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default,
                options: [.allowBluetooth, .allowAirPlay, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        setupRemoteCommandCenter()

        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.levels = self.handles.mapValues { $0.currentLevel }
            self.bufferingStreams = Set(
                self.handles
                    .filter {
                        $0.value.player.rate > 0 &&
                        $0.value.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                    }
                    .keys
            )
            self.updateDucking()
        }
        RunLoop.main.add(t, forMode: .common)
        meterTimer = t
    }

    // MARK: Public API

    func play(stream: AudioStream, credentials: BroadcastifyCredentials?) {
        streamRoles[stream.id] = stream.role
        if let existing = handles[stream.id] {
            existing.play()
            if stream.role == .secondary {
                existing.updateVolume(currentDuckMultiplier)
            }
        } else {
            let handle = StreamPlayerHandle(stream: stream, credentials: credentials)
            handle.onPlaybackFailed = { [weak self] id, message in
                self?.lastFailure = (id, message)
                self?.handles[id]?.pause()
                self?.playingStreamIDs.remove(id)
                self?.updateNowPlaying()
            }
            // Re-fire Now Playing when stream transitions from buffering → actively playing.
            handle.onTimeControlStatusChanged = { [weak self] _, _ in
                self?.updateNowPlaying()
            }
            handles[stream.id] = handle
            handle.play()
            if stream.role == .secondary {
                handle.updateVolume(currentDuckMultiplier)
            }
        }
        playingStreamIDs.insert(stream.id)
        updateNowPlaying()
    }

    func pause(streamID: UUID) {
        handles[streamID]?.pause()
        playingStreamIDs.remove(streamID)
        updateNowPlaying()
    }

    func remove(streamID: UUID) {
        handles[streamID]?.pause()
        handles.removeValue(forKey: streamID)
        levels.removeValue(forKey: streamID)
        streamRoles.removeValue(forKey: streamID)
        playingStreamIDs.remove(streamID)
        updateNowPlaying()
    }

    func updateVolume(_ volume: Float, for streamID: UUID) {
        handles[streamID]?.updateVolume(volume)
    }

    func updatePan(_ pan: Float, for streamID: UUID) {
        handles[streamID]?.updatePan(pan)
    }

    func setRole(_ role: StreamRole, for streamID: UUID) {
        streamRoles[streamID] = role
        guard let handle = handles[streamID] else { return }
        if role == .secondary {
            handle.updateVolume(currentDuckMultiplier)
        } else {
            handle.updateVolume(1.0)
        }
    }

    func setDuckLevel(db: Double) {
        duckLevelLinear = Float(pow(10.0, db / 20.0))
    }

    // MARK: - Sidechain ducking engine

    private func updateDucking() {
        let anyPrimaryHot = handles.contains { (id, handle) in
            streamRoles[id] == .primary && handle.currentLevel > Self.primaryThreshold
        }

        let targetMultiplier: Float = anyPrimaryHot ? duckLevelLinear : 1.0
        guard currentDuckMultiplier != targetMultiplier else { return }

        let range = 1.0 - duckLevelLinear
        guard range > 0 else { return }

        let stepSize: Float = anyPrimaryHot
            ? range / 2.0    // 200 ms attack  (2 × 100 ms ticks)
            : range / 10.0   // 1 s   release (10 × 100 ms ticks)

        if anyPrimaryHot {
            currentDuckMultiplier = max(duckLevelLinear, currentDuckMultiplier - stepSize)
        } else {
            currentDuckMultiplier = min(1.0, currentDuckMultiplier + stepSize)
        }

        for (id, handle) in handles where streamRoles[id] == .secondary {
            handle.updateVolume(currentDuckMultiplier)
        }
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        let activeCount = playingStreamIDs.count

        guard activeCount > 0 else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:            "ShoutPLEX Multi-Stream",
            MPMediaItemPropertyArtist:           "\(activeCount) stream\(activeCount == 1 ? "" : "s") active",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let image = UIImage(named: "NavbarLogo") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote Command Center (lock screen controls)

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget  { [weak self] _ in self?.resumeAll();  return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.pauseAll();   return .success }
        center.stopCommand.addTarget  { [weak self] _ in self?.pauseAll();   return .success }
    }

    private func resumeAll() {
        handles.values.forEach { $0.play() }
        playingStreamIDs = Set(handles.keys)
        updateNowPlaying()
    }

    private func pauseAll() {
        handles.values.forEach { $0.pause() }
        playingStreamIDs.removeAll()
        updateNowPlaying()
        onRemoteCommandPauseAll?()
    }
}
