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
                    Text("Credentials are stored only on this device and sent **directly and exclusively to Broadcastify** for authentication. They are never transmitted to or stored by ShoutPLEX Multi-Stream or any third party.")
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

                // MARK: Sidechain Ducking
                Section {
                    HStack {
                        Label("Duck Level", systemImage: "waveform.path.ecg")
                            .foregroundStyle(Color.spBlue)
                        Spacer()
                        Text("\(Int(vm.duckLevelDB.rounded())) dBFS")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $vm.duckLevelDB, in: -40 ... -1, step: 1)
                        .tint(Color.spPink)
                } header: {
                    Label("Sidechain Ducking", systemImage: "waveform.path.ecg")
                } footer: {
                    Text("How far Secondary streams duck when a Primary stream is active. Lower = more ducking. Default: −12 dBFS.")
                }

                // MARK: About
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("ShoutPLEX Multi-Stream")
                                .font(.headline)
                                .foregroundStyle(Color.spPink)
                        }
                        Spacer()
                    }

                    Text("A forever-free, ad-free, multi-stream audio player for your enjoyment\n\nPresented by Landmark 717, a not-for-profit documentary series covering Angeles National Forest\n\nThis app was created to help SoCal fire followers monitor all of the action when wildfires break out and things move quickly, but is open to anyone for use!")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Disclaimer")
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("You're using this app at your own risk. Pay attention to your surroundings, don't rely on these feeds for life safety, remember streams are delayed, and always follow your organization's best practices. If you have a physical scanner, use that instead if you can. Streams use data, and you are responsible for monitoring your data use with your carrier and/or ISPs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Finally, don't hesitate to get in touch for any reason:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Link(destination: URL(string: "https://landmark717.com")!) {
                        HStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "globe")
                            Text("Landmark717.com")
                            Spacer()
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.spBlue)
                    }

                    Link(destination: URL(string: "https://github.com/acceptableEngineering/ShoutPlex-app")!) {
                        HStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("Source code on GitHub")
                            Spacer()
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.spBlue)
                    }

                    Link(destination: URL(string: "mailto:mark@landmark717.com")!) {
                        HStack(spacing: 4) {
                            Spacer()
                            Image(systemName: "envelope")
                            Text("mark@landmark717.com")
                            Spacer()
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.spBlue)
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
