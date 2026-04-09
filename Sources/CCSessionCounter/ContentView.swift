import SwiftUI
import AppKit
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            usageRows
            Divider()
            statusRow
            Divider()
            footer
        }
        .frame(width: 280)
    }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .center) {
            Text("Claude Code")
                .font(.headline)
            Spacer()
            tierBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    var tierBadge: some View {
        let tier = appState.usageData.tierDisplayName
        if !tier.isEmpty {
            Text(tier)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(4)
        }
    }

    // MARK: - Usage rows

    var usageRows: some View {
        VStack(spacing: 0) {
            UsageRow(
                label: "5-hour",
                utilization: appState.usageData.fiveHourUtilization,
                resetsAt: appState.usageData.fiveHourResetsAt,
                isBinding: appState.usageData.bindingWindow == "five_hour"
            )
            UsageRow(
                label: "7-day",
                utilization: appState.usageData.sevenDayUtilization,
                resetsAt: appState.usageData.sevenDayResetsAt,
                isBinding: appState.usageData.bindingWindow == "seven_day"
            )
        }
    }

    // MARK: - Status

    var statusRow: some View {
        HStack(spacing: 6) {
            let ok = appState.usageData.status == "allowed"
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(ok ? .green : .red)
                .font(.caption)
            Text(ok ? "Usage allowed" : "Rate limited")
                .font(.caption)
            Spacer()
            if appState.usageData.overageStatus == "rejected" {
                Text("No overage")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    var footer: some View {
        HStack(spacing: 8) {
            if appState.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else {
                Button {
                    Task { await appState.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Refresh now")
            }

            if let err = appState.error {
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else if let updated = appState.usageData.lastUpdated {
                let ago = Int(-updated.timeIntervalSinceNow)
                Text(ago < 10 ? "Just updated" : "Updated \(ago < 60 ? "\(ago)s" : "\(ago/60)m") ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(HoverButtonStyle())
            .font(.caption)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(HoverButtonStyle())
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - UsageRow

struct UsageRow: View {
    let label: String
    let utilization: Double
    let resetsAt: Date?
    let isBinding: Bool
    var monochrome: Bool = false

    var color: Color {
        if monochrome { return .secondary }
        if utilization >= 0.8 { return .red }
        if utilization >= 0.5 { return .orange }
        return .green
    }

    var resetText: String {
        guard let date = resetsAt else { return "" }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "resetting soon…" }
        let total = Int(interval)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "resets in \(days)d \(hours)h" }
        if hours > 0 { return "resets in \(hours)h \(minutes)m" }
        return "resets in \(minutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 5) {
                if isBinding {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                } else {
                    Spacer().frame(width: 5)
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isBinding ? .semibold : .regular)
                Spacer()
                Text("\(Int((utilization * 100).rounded()))%")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(monochrome ? AnyShapeStyle(color) : AnyShapeStyle(color.gradient))
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, utilization))), height: 5)
                }
            }
            .frame(height: 5)

            if !resetText.isEmpty {
                Text(resetText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @AppStorage("useMonochrome") private var useMonochrome: Bool = true
    @AppStorage("pollInterval") private var pollInterval: Double = 300
    @State private var launchAtLogin: Bool = false

    private let intervalOptions: [(label: String, seconds: Double)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            Toggle("Open at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }

            Toggle("Monochrome icon", isOn: $useMonochrome)
                .toggleStyle(.switch)

            Picker("Refresh every", selection: $pollInterval) {
                ForEach(intervalOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            .pickerStyle(.menu)

            Divider()

            HStack {
                Text("Created by Josh Angel")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Link(destination: URL(string: "https://github.com/joshtickles")!) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .help("github.com/joshtickles")
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - HoverButtonStyle

struct HoverButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(hovering ? Color.secondary.opacity(0.2) : Color.clear)
            )
            .onHover { hovering = $0 }
    }
}
