import Foundation
import Combine
import SwiftUI

final class StreamsViewModel: ObservableObject {
    // MARK: - Published state

    @Published var streams: [AudioStream] = []
    @Published var categories: [StreamCategory] = []
    @Published var credentials = BroadcastifyCredentials(username: "", password: "")

    /// When true the list shows drag handles and delete buttons.
    /// Persisted so the user doesn't have to re-enable mid-session.
    @Published var isEditMode: Bool = false {
        didSet { UserDefaults.standard.set(isEditMode, forKey: editModeKey) }
    }

    @Published var showMissingCredentialsAlert = false
    @Published var streamPlayError: String?
    @Published var showSettingsFromAlert = false

    // MARK: - Private

    private let player         = AudioStreamPlayer.shared
    private let streamsKey     = "shoutplex.streams"
    private let categoriesKey  = "shoutplex.categories"
    private let credentialsKey = "shoutplex.credentials"
    private let editModeKey    = "shoutplex.editMode"
    private var cancellables   = Set<AnyCancellable>()

    init() {
        load()
        player.$lastFailure
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (streamID, message) in
                guard let self else { return }
                if let idx = self.streams.firstIndex(where: { $0.id == streamID }) {
                    self.streams[idx].isPlaying = false
                }
                self.streamPlayError = message
            }
            .store(in: &cancellables)

        // Sync model when the user pauses all streams from Control Center / lock screen.
        player.onRemoteCommandPauseAll = { [weak self] in
            guard let self else { return }
            for idx in self.streams.indices where self.streams[idx].isPlaying {
                self.streams[idx].isPlaying = false
            }
            self.save()
        }

        restorePlayback()
    }

    // MARK: - Stream helpers

    /// Returns streams belonging to a category, in category-defined order.
    func orderedStreams(in category: StreamCategory) -> [AudioStream] {
        category.streamIDs.compactMap { id in streams.first(where: { $0.id == id }) }
    }

    /// A Binding into the streams array for use in StreamRowView.
    func binding(for streamID: UUID) -> Binding<AudioStream> {
        Binding(
            get: { self.streams.first(where: { $0.id == streamID }) ?? AudioStream(name: "", url: "") },
            set: { newValue in
                if let idx = self.streams.firstIndex(where: { $0.id == streamID }) {
                    self.streams[idx] = newValue
                }
            }
        )
    }

    // MARK: - Stream Management

    func add(name: String, urlString: String, categoryID: UUID?) {
        guard !urlString.isEmpty else { return }
        let stream = AudioStream(name: name, url: urlString)
        streams.append(stream)

        // Determine target category, auto-creating "Uncategorized" if needed
        let targetID = categoryID ?? uncategorizedCategoryID()
        if let catIdx = categories.firstIndex(where: { $0.id == targetID }) {
            categories[catIdx].streamIDs.append(stream.id)
        }
        save()
    }

    func removeStreams(at offsets: IndexSet, from categoryID: UUID) {
        guard let catIdx = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        let idsToRemove = offsets.map { categories[catIdx].streamIDs[$0] }
        idsToRemove.forEach { id in
            if let stream = streams.first(where: { $0.id == id }), stream.isPlaying {
                player.remove(streamID: id)
            }
            streams.removeAll { $0.id == id }
        }
        categories[catIdx].streamIDs.remove(atOffsets: offsets)
        save()
    }

    func moveStreams(in categoryID: UUID, from source: IndexSet, to destination: Int) {
        guard let catIdx = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[catIdx].streamIDs.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func togglePlay(stream: AudioStream) {
        guard let idx = streams.firstIndex(where: { $0.id == stream.id }) else { return }
        if streams[idx].isPlaying {
            player.remove(streamID: stream.id)
            streams[idx].isPlaying = false
        } else {
            if stream.isBroadcastify && credentials.isEmpty {
                showMissingCredentialsAlert = true
                return
            }
            let creds = stream.isBroadcastify ? credentials : nil
            player.play(stream: streams[idx], credentials: creds)
            streams[idx].isPlaying = true
        }
        save()
    }

    func setPan(_ pan: PanMode, for stream: AudioStream) {
        guard let idx = streams.firstIndex(where: { $0.id == stream.id }) else { return }
        streams[idx].panMode = pan
        player.updatePan(pan.panValue, for: stream.id)
        save()
    }

    func setVolume(_ volume: Float, for stream: AudioStream) {
        guard let idx = streams.firstIndex(where: { $0.id == stream.id }) else { return }
        streams[idx].volume = volume
        player.updateVolume(volume, for: stream.id)
        save()
    }

    // MARK: - Category Management

    func addCategory(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        categories.append(StreamCategory(name: name))
        save()
    }

    func renameCategory(id: UUID, to name: String) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].name = name
        save()
    }

    func removeCategories(at offsets: IndexSet) {
        offsets.forEach { idx in
            let cat = categories[idx]
            // Move streams to Uncategorized rather than deleting them
            let targetID = uncategorizedCategoryID(excluding: cat.id)
            if let targetIdx = categories.firstIndex(where: { $0.id == targetID }),
               targetIdx != idx {
                categories[targetIdx].streamIDs.append(contentsOf: cat.streamIDs)
            } else {
                // If no other category exists, stop playback and delete the streams
                cat.streamIDs.forEach { id in
                    if let stream = streams.first(where: { $0.id == id }), stream.isPlaying {
                        player.remove(streamID: id)
                    }
                    streams.removeAll { $0.id == id }
                }
            }
        }
        categories.remove(atOffsets: offsets)
        save()
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Credentials

    func saveCredentials() {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: credentialsKey)
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(streams) {
            UserDefaults.standard.set(data, forKey: streamsKey)
        }
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: categoriesKey)
        }
    }

    private func load() {
        isEditMode = UserDefaults.standard.bool(forKey: editModeKey)

        if let data = UserDefaults.standard.data(forKey: streamsKey),
           let saved = try? JSONDecoder().decode([AudioStream].self, from: data) {
            streams = saved
        }
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let saved = try? JSONDecoder().decode([StreamCategory].self, from: data) {
            categories = saved
        }
        if let data = UserDefaults.standard.data(forKey: credentialsKey),
           let saved = try? JSONDecoder().decode(BroadcastifyCredentials.self, from: data) {
            credentials = saved
        }

        migrateUncategorizedStreams()
    }

    /// Restarts any streams that were playing when the app was last closed.
    /// Called after all subscriptions are wired up so failures are handled correctly.
    private func restorePlayback() {
        var needsSave = false
        for stream in streams where stream.isPlaying {
            // Broadcastify streams require credentials — skip if not configured.
            if stream.isBroadcastify && credentials.isEmpty {
                if let idx = streams.firstIndex(where: { $0.id == stream.id }) {
                    streams[idx].isPlaying = false
                    needsSave = true
                }
                continue
            }
            let creds = stream.isBroadcastify ? credentials : nil
            player.play(stream: stream, credentials: creds)
        }
        if needsSave { save() }
    }

    /// Ensures every stream appears in at least one category.
    /// Runs after load to handle both fresh installs and upgrades from the old flat-list model.
    private func migrateUncategorizedStreams() {
        let assignedIDs = Set(categories.flatMap { $0.streamIDs })
        let orphanIDs = streams.map(\.id).filter { !assignedIDs.contains($0) }
        guard !orphanIDs.isEmpty else { return }

        let targetID = uncategorizedCategoryID()
        if let idx = categories.firstIndex(where: { $0.id == targetID }) {
            categories[idx].streamIDs.append(contentsOf: orphanIDs)
        }
        save()
    }

    /// Returns the ID of the "Uncategorized" category, creating it if it doesn't exist.
    @discardableResult
    private func uncategorizedCategoryID(excluding excludedID: UUID? = nil) -> UUID {
        if let existing = categories.first(where: { $0.name == "Uncategorized" && $0.id != excludedID }) {
            return existing.id
        }
        var uncat = StreamCategory(name: "Uncategorized")
        categories.append(uncat)
        return uncat.id
    }
}
