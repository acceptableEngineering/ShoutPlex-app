import SwiftUI

struct StreamRowView: View {
    @EnvironmentObject var vm: StreamsViewModel
    @ObservedObject private var player = AudioStreamPlayer.shared
    @Binding var stream: AudioStream
    @State private var showLockPopover = false

    // -30 dBFS threshold: 10^(-30/20) ≈ 0.03162
    private static let levelThreshold: Float = 0.03162

    private var isAboveThreshold: Bool {
        (player.levels[stream.id] ?? 0) > Self.levelThreshold
    }

    private var isBuffering: Bool {
        player.bufferingStreams.contains(stream.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: play button + name + Broadcastify badge
            HStack(spacing: 12) {
                Button(action: { vm.togglePlay(stream: stream) }) {
                    if isBuffering {
                        ProgressView()
                            .tint(Color.spPink)
                            .scaleEffect(1.5)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: stream.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(stream.isPlaying ? Color.spPink : Color.spBlue)
                            .animation(.easeInOut(duration: 0.15), value: stream.isPlaying)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.name.isEmpty ? "Unnamed Stream" : stream.name)
                        .font(.headline)
                        .foregroundStyle(isAboveThreshold ? Color.spPink : Color.primary)
                        .animation(.easeInOut(duration: 0.15), value: isAboveThreshold)
                        .lineLimit(1)
                    Text(stream.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if stream.isBroadcastify {
                    Button {
                        showLockPopover = true
                    } label: {
                        Image(systemName: vm.credentials.isEmpty ? "lock.slash.fill" : "lock.fill")
                            .font(.caption)
                            .foregroundStyle(vm.credentials.isEmpty ? Color.spPink : Color.spBlue)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showLockPopover, arrowEdge: .trailing) {
                        broadcastifyPopover
                    }
                }
            }

            // Role controls (pan hidden pending future UX)
            HStack {
                Spacer()
                rolePicker
            }
        }
        .padding(.vertical, 4)
        .alert("Broadcastify Credentials Required", isPresented: $vm.showMissingCredentialsAlert) {
            Button("Open Settings") { vm.showSettingsFromAlert = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add your Broadcastify username and password in Settings before playing this stream.")
        }
        .alert("Stream Error", isPresented: Binding(
            get: { vm.streamPlayError != nil },
            set: { if !$0 { vm.streamPlayError = nil } }
        )) {
            Button("OK", role: .cancel) { vm.streamPlayError = nil }
        } message: {
            Text(vm.streamPlayError ?? "")
        }
    }

    // MARK: - Broadcastify Popover

    private var broadcastifyPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: vm.credentials.isEmpty ? "lock.slash.fill" : "lock.fill")
                    .foregroundStyle(vm.credentials.isEmpty ? Color.spPink : Color.spBlue)
                    .font(.title3)
                Text("Broadcastify Auth")
                    .font(.headline)
            }

            HStack(spacing: 6) {
                Image(systemName: vm.credentials.isEmpty ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(vm.credentials.isEmpty ? Color.spPink : .green)
                Text(vm.credentials.isEmpty ? "Credentials not configured" : "Credentials configured")
                    .font(.subheadline)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("Your privacy", systemImage: "hand.raised.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.spBlue)
                Text("Your credentials are stored only on this device and sent **directly and exclusively to Broadcastify** for authentication. They are never transmitted to or stored by ShoutPLEX Multi-Stream or any third party.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 280)
    }

    // MARK: - Pan Picker

    private var panPicker: some View {
        HStack(spacing: 0) {
            ForEach(PanMode.allCases, id: \.self) { mode in
                Button {
                    vm.setPan(mode, for: stream)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                        Text(mode.rawValue)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(stream.panMode == mode ? Color.spBlue : Color(.tertiarySystemFill))
                    .foregroundStyle(stream.panMode == mode ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
    }

    // MARK: - Role Picker

    private var rolePicker: some View {
        HStack(spacing: 0) {
            ForEach(StreamRole.allCases, id: \.self) { role in
                Button {
                    vm.setRole(role, for: stream)
                } label: {
                    Text(role.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(stream.role == role ? Color.spPink : Color(.tertiarySystemFill))
                        .foregroundStyle(stream.role == role ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
    }
}
