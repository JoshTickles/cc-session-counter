import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var usageData = UsageData()
    @Published var isLoading = false
    @Published var error: String?
    @Published var activeSessions: [SessionInfo] = []
    @AppStorage("useMonochrome") var useMonochrome: Bool = true
    @AppStorage("pollInterval") var pollInterval: Double = 300

    private var timer: Timer?
    private let fetcher = UsageFetcher()
    private var sessionWatcher: LocalSessionWatcher?
    private var defaultsObserver: NSObjectProtocol?

    init() {
        let watcher = LocalSessionWatcher()
        watcher.onUpdate = { [weak self] sessions in
            Task { @MainActor [weak self] in
                self?.activeSessions = sessions
            }
        }
        watcher.startWatching()
        sessionWatcher = watcher

        Task { await refresh() }
        startPolling()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleNextPoll()
            }
        }
    }

    func refresh() async {
        isLoading = true
        error = nil
        do {
            usageData = try await fetcher.fetchUsage(rereadIfExpired: true)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func startPolling() {
        // 5 min default; when over 80%, poll every minute to catch the reset
        scheduleNextPoll()
    }

    private func scheduleNextPoll() {
        timer?.invalidate()
        let interval: TimeInterval = usageData.bindingUtilization >= 0.8 ? 60 : pollInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
                self?.scheduleNextPoll()
            }
        }
    }

    deinit {
        timer?.invalidate()
        if let obs = defaultsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
