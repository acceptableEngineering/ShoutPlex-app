import Foundation

struct BroadcastifyCredentials: Codable {
    var username: String
    var password: String

    var isEmpty: Bool { username.isEmpty && password.isEmpty }

    // Basic-auth header value
    var basicAuthValue: String? {
        guard !username.isEmpty, !password.isEmpty else { return nil }
        let raw = "\(username):\(password)"
        guard let data = raw.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }
}
