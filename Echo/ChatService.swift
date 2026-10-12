import Foundation
import Security

enum Keychain {
    static func save(_ value: String, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

enum ChatError: LocalizedError {
    case noKey
    case bad(String)
    var errorDescription: String? {
        switch self {
        case .noKey: return "Add your API key in Settings first."
        case .bad(let m): return m
        }
    }
}

enum ChatService {
    static func send(_ history: [ChatMessage]) async throws -> String {
        guard let key = Keychain.load("apiKey"), !key.isEmpty else {
            throw ChatError.noKey
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "claude-haiku-5-5",
            "max_tokens": 1000,
            "system": "You are Echo, a private voice assistant. Keep replies short and easy to hear.",
            "messages": history.map { ["role": $0.role, "content": $0.text] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ChatError.bad("No response") }
        guard http.statusCode == 200 else {
            throw ChatError.bad("Error \(http.statusCode): " + (String(data: data, encoding: .utf8) ?? ""))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw ChatError.bad("Unexpected reply")
        }
        return text
    }
}
