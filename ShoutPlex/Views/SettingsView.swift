import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: StreamsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Broadcastify
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.spBlue)
                            .frame(width: 24)
                        TextField("Username", text: $vm.credentials.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(Color.spBlue)
                            .frame(width: 24)
                        Group {
                            if showPassword {
                                TextField("Password", text: $vm.credentials.password)
                            } else {
                                SecureField("Password", text: $vm.credentials.password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Label("Broadcastify", systemImage: "lock.shield")
                } footer: {
                    Text("Credentials are stored only on this device and sent **directly and exclusively to Broadcastify** for authentication. They are never transmitted to or stored by ShoutPLEX or any third party.")
                }

                // MARK: Organization
                Section {
                    Toggle(isOn: $vm.isEditMode) {
                        Label("Edit Mode", systemImage: "arrow.up.arrow.down")
                    }
                    .tint(Color.spPink)

                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        Label("Manage Categories", systemImage: "folder")
                            .foregroundStyle(Color.spBlue)
                    }
                } header: {
                    Text("Organization")
                } footer: {
                    Text("Edit Mode enables drag-to-reorder and swipe-to-delete on the main stream list.")
                }

                // MARK: About
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("ShoutPLEX")
                                .font(.headline)
                                .foregroundStyle(Color.spPink)
                        }
                        Spacer()
                    }

                    Text("A forever-free, simple multi-stream player for your enjoyment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Link(destination: URL(string: "https://github.com/acceptableEngineering/ShoutPlex-app")!) {
                        Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.footnote)
                            .foregroundStyle(Color.spBlue)
                            .frame(maxWidth: .infinity)
                    }

                    Link(destination: URL(string: "mailto:mark@landmark717.com")!) {
                        Label("mark@landmark717.com", systemImage: "envelope")
                            .font(.footnote)
                            .foregroundStyle(Color.spBlue)
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveCredentials()
                        dismiss()
                    }
                    .bold()
                    .tint(Color.spPink)
                }
            }
        }
    }
}
