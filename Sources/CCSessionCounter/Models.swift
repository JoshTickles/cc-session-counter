import Foundation
import Darwin

struct UsageData {
    var fiveHourUtilization: Double = 0
    var fiveHourResetsAt: Date?
    var sevenDayUtilization: Double = 0
    var sevenDayResetsAt: Date?
    var status: String = "unknown"
    var bindingWindow: String = "five_hour"
    var overageStatus: String = "unknown"
    var overageDisabledReason: String = ""
    var subscriptionType: String = ""
    var rateLimitTier: String = ""
    var lastUpdated: Date?

    var bindingUtilization: Double {
        bindingWindow == "five_hour" ? fiveHourUtilization : sevenDayUtilization
    }

    var bindingResetsAt: Date? {
        bindingWindow == "five_hour" ? fiveHourResetsAt : sevenDayResetsAt
    }

    var tierDisplayName: String {
        rateLimitTier
            .replacingOccurrences(of: "default_claude_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }
}

struct SessionInfo: Identifiable {
    let id: String
    let sessionId: String
    let cwd: String
    let startedAt: Date
    let pid: Int

    var projectName: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }

    var duration: String {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(0, minutes))m"
    }

    var isRunning: Bool {
        kill(pid_t(pid), 0) == 0
    }
}
