import SwiftUI
import AVFoundation

@main
struct ShoutPlexApp: App {
    @StateObject private var streamsViewModel = StreamsViewModel()

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(streamsViewModel)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .mixWithOthers lets multiple AVPlayer instances play simultaneously
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioSession setup failed: \(error)")
        }
    }
}
