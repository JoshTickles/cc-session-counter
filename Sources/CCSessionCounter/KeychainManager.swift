import Foundation
import Security

struct ClaudeCredentials: Decodable {
    struct OAuthData: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Double?
        let subscriptionType: String?
        let rateLimitTier: String?
    }
    let claudeAiOauth: OAuthData

    var isExpired: Bool {
        guard let expiresAt = claudeAiOauth.expiresAt else { return false }
        // expiresAt is milliseconds since epoch
        return Date(timeIntervalSince1970: expiresAt / 1000) < Date()
    }
}

enum KeychainError: LocalizedError {
    case notFound
    case accessDenied
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Claude Code credentials not found. Please run Claude Code at least once."
        case .accessDenied:
            return "Keychain access denied. Please approve the access prompt."
        case .decodingFailed(let e):
            return "Failed to decode credentials: \(e.localizedDescription)"
        }
    }
}

enum KeychainManager {
    static func readClaudeCredentials() throws -> ClaudeCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.notFound }
            do {
                return try JSONDecoder().decode(ClaudeCredentials.self, from: data)
            } catch {
                throw KeychainError.decodingFailed(error)
            }
        case errSecItemNotFound:
            throw KeychainError.notFound
        case errSecUserCanceled, errSecInteractionNotAllowed:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.notFound
        }
    }
}
