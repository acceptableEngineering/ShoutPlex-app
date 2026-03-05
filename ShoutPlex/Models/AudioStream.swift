import Foundation

enum StreamRole: String, Codable, CaseIterable {
    case primary   = "Primary"
    case secondary = "Secondary"
}

enum PanMode: String, Codable, CaseIterable {
    case left   = "Left"
    case stereo = "Stereo"
    case right  = "Right"

    var iconName: String {
        switch self {
        case .left:   return "speaker.wave.1"
        case .stereo: return "speaker.wave.2"
        case .right:  return "speaker.wave.3"
        }
    }

    /// Pan value used by AudioStreamPlayer: -1.0 = full left, 0.0 = center, 1.0 = full right
    var panValue: Float {
        switch self {
        case .left:   return -1.0
        case .stereo: return  0.0
        case .right:  return  1.0
        }
    }
}

struct AudioStream: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var url: String
    var panMode: PanMode = .stereo
    var volume: Float = 1.0
    var role: StreamRole = .secondary
    var isPlaying: Bool = false
    var usesBroadcastifyAuth: Bool = false

    /// True when the URL hostname indicates a Broadcastify feed
    var isBroadcastify: Bool {
        guard let host = URL(string: url)?.host else { return false }
        return host.contains("broadcastify.com")
    }
}
