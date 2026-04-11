import Foundation

enum FetchError: LocalizedError {
    case invalidResponse
    case authFailed(Int)
    case tokenExpired
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .authFailed(let code):
            return "Auth failed (\(code)) — open Claude Code to refresh login"
        case .tokenExpired:
            return "Token expired — open Claude Code to refresh"
        case .networkError(let e):
            return e.localizedDescription
        }
    }
}

class UsageFetcher {
    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages?beta=true")!
    private var cachedCredentials: ClaudeCredentials?

    func fetchUsage(rereadIfExpired: Bool = false) async throws -> UsageData {
        // Re-read keychain only when:
        //   • no credentials cached yet (first launch), or
        //   • explicit user refresh AND the cached token is already expired
        //     (gives Claude Code a chance to have silently refreshed it).
        // Never re-read on background polls just because the token is expired —
        // the keychain has the same expired token, so it only spams the access prompt.
        if cachedCredentials == nil || (rereadIfExpired && cachedCredentials!.isExpired) {
            cachedCredentials = try KeychainManager.readClaudeCredentials()
        }
        let credentials = cachedCredentials!

        if credentials.isExpired {
            throw FetchError.tokenExpired
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(credentials.claudeAiOauth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("claude-code-20250219,oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("cc-session-counter/1.0", forHTTPHeaderField: "User-Agent")

        // Minimal probe — cheapest model, 1 token, reads headers only
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "."]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            // Token was rejected — try picking up a freshly-written token from keychain
            // (Claude Code may have silently refreshed it). One-shot: if still bad,
            // wait for the next explicit user refresh rather than spamming the prompt.
            if let fresh = try? KeychainManager.readClaudeCredentials(),
               fresh.claudeAiOauth.accessToken != credentials.claudeAiOauth.accessToken {
                cachedCredentials = fresh
            }
            throw FetchError.authFailed(http.statusCode)
        }

        var data = parseHeaders(from: http)
        data.subscriptionType = credentials.claudeAiOauth.subscriptionType ?? ""
        data.rateLimitTier = credentials.claudeAiOauth.rateLimitTier ?? ""
        return data
    }

    private func parseHeaders(from response: HTTPURLResponse) -> UsageData {
        func h(_ key: String) -> String? { response.value(forHTTPHeaderField: key) }

        var data = UsageData()
        data.fiveHourUtilization  = Double(h("anthropic-ratelimit-unified-5h-utilization") ?? "") ?? 0
        data.sevenDayUtilization  = Double(h("anthropic-ratelimit-unified-7d-utilization") ?? "") ?? 0
        data.status               = h("anthropic-ratelimit-unified-status") ?? "unknown"
        data.bindingWindow        = h("anthropic-ratelimit-unified-representative-claim") ?? "five_hour"
        data.overageStatus        = h("anthropic-ratelimit-unified-overage-status") ?? "unknown"
        data.overageDisabledReason = h("anthropic-ratelimit-unified-overage-disabled-reason") ?? ""

        if let raw = h("anthropic-ratelimit-unified-5h-reset"), let ts = Double(raw) {
            data.fiveHourResetsAt = Date(timeIntervalSince1970: ts)
        }
        if let raw = h("anthropic-ratelimit-unified-7d-reset"), let ts = Double(raw) {
            data.sevenDayResetsAt = Date(timeIntervalSince1970: ts)
        }
        data.lastUpdated = Date()
        return data
    }
}
