import SwiftUI

private enum StreamInputMode: String, CaseIterable {
    case fullURL        = "Full URL"
    case broadcastifyID = "Broadcastify Stream ID"
}

struct AddStreamView: View {
    @EnvironmentObject var vm: StreamsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name              = ""
    @State private var inputMode: StreamInputMode = .fullURL
    @State private var urlString         = ""
    @State private var broadcastifyID    = ""
    @State private var selectedCategoryID: UUID? = nil
    @FocusState private var primaryFieldFocused: Bool

    private static let broadcastifyBase = "https://audio.broadcastify.com/"

    /// The resolved URL that will actually be saved.
    private var resolvedURL: String {
        switch inputMode {
        case .fullURL:
            return urlString.trimmingCharacters(in: .whitespaces)
        case .broadcastifyID:
            let id = broadcastifyID.trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? "" : Self.broadcastifyBase + id
        }
    }

    private var isBroadcastify: Bool {
        URL(string: resolvedURL)?.host?.contains("broadcastify.com") ?? false
    }

    private var canAdd: Bool {
        !resolvedURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Input mode picker
                Section {
                    Picker("Stream Type", selection: $inputMode) {
                        ForEach(StreamInputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                // MARK: Stream details
                Section {
                    TextField("Display name (optional)", text: $name)

                    if inputMode == .fullURL {
                        TextField("https://…", text: $urlString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($primaryFieldFocused)
                    } else {
                        HStack(spacing: 4) {
                            Text(Self.broadcastifyBase)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            TextField("stream-id", text: $broadcastifyID)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($primaryFieldFocused)
                        }
                    }
                } header: {
                    Text("Stream Info")
                } footer: {
                    if inputMode == .fullURL {
                        Text("Supports Icecast and Shoutcast HTTP/HTTPS streams.")
                    } else {
                        Text("Enter the numeric or alphanumeric stream ID from your Broadcastify feed page.")
                    }
                }

                // MARK: Category picker
                if !vm.categories.isEmpty {
                    Section {
                        Picker("Category", selection: $selectedCategoryID) {
                            Text("Uncategorized").tag(nil as UUID?)
                            ForEach(vm.categories) { cat in
                                Text(cat.name).tag(cat.id as UUID?)
                            }
                        }
                    } header: {
                        Text("Category")
                    }
                }

                // MARK: Broadcastify auth notice
                if isBroadcastify {
                    Section {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Color.spBlue)
                            Text("Broadcastify credentials will be applied automatically from Settings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let label = name.isEmpty ? inferName(from: resolvedURL) : name
                        vm.add(name: label, urlString: resolvedURL, categoryID: selectedCategoryID)
                        dismiss()
                    }
                    .disabled(!canAdd)
                    .bold()
                    .tint(Color.spPink)
                }
            }
            .onAppear {
                primaryFieldFocused = true
                selectedCategoryID = vm.categories.first(where: { $0.name != "Uncategorized" })?.id
            }
            .onChange(of: inputMode) { _ in
                primaryFieldFocused = true
            }
        }
    }

    private func inferName(from urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
