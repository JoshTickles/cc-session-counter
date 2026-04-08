import SwiftUI
import AppKit

@main
struct CCSessionCounterApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(appState)
        } label: {
            Image(nsImage: MenuBarIconRenderer.makeIcon(
                utilization: appState.usageData.bindingUtilization,
                status: appState.usageData.lastUpdated != nil ? appState.usageData.status : "loading",
                monochrome: appState.useMonochrome
            ))
            .help(iconTooltip)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }

    private var iconTooltip: String {
        let pct = Int(appState.usageData.bindingUtilization * 100)
        let window = appState.usageData.bindingWindow == "five_hour" ? "5h" : "7d"
        if appState.usageData.lastUpdated == nil { return "Claude Code Usage — loading…" }
        return "Claude Code Usage: \(pct)% (\(window) window)"
    }
}
