import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: StreamsViewModel
    @State private var showAddStream  = false
    @State private var showSettings   = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if vm.streams.isEmpty && vm.categories.allSatisfy({ $0.streamIDs.isEmpty }) {
                    emptyState
                } else {
                    streamList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("NavbarLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gear")
                            .foregroundStyle(Color.spBlue)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { showAddStream = true } label: {
                        Label("Add Stream", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.spPink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddStream)        { AddStreamView() }
        .sheet(isPresented: $showSettings)         { SettingsView() }
        .sheet(isPresented: $vm.showSettingsFromAlert) { SettingsView() }
        .tint(Color.spPink)
    }

    // MARK: - Stream List

    private var streamList: some View {
        List {
            ForEach(vm.categories) { category in
                let categoryStreams = vm.orderedStreams(in: category)
                // Hide entirely empty categories when not in edit mode
                if vm.isEditMode || !categoryStreams.isEmpty {
                    Section {
                        ForEach(categoryStreams) { stream in
                            StreamRowView(stream: vm.binding(for: stream.id))
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                        .onMove { vm.moveStreams(in: category.id, from: $0, to: $1) }
                        .onDelete(perform: vm.isEditMode ? { vm.removeStreams(at: $0, from: category.id) } : nil)
                    } header: {
                        categoryHeader(for: category)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(vm.isEditMode ? .active : .inactive))
    }

    private func categoryHeader(for category: StreamCategory) -> some View {
        HStack {
            Text(category.name)
                .font(.subheadline.bold())
                .foregroundStyle(Color.spBlue)
                .textCase(nil)
            Spacer()
            if vm.isEditMode {
                Text("EDIT MODE")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.spPink)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(Color.spBlue)
            Text("No Streams")
                .font(.title2.bold())
            Text("Tap + to add an Icecast or\nShoutcast stream URL.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Add Stream") { showAddStream = true }
                .buttonStyle(.borderedProminent)
                .tint(Color.spPink)
        }
        .padding()
    }
}
