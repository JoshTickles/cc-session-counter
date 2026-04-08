import Foundation

private struct SessionFile: Decodable {
    let pid: Int?
    let sessionId: String?
    let cwd: String?
    let startedAt: Int?
    let kind: String?
}

class LocalSessionWatcher {
    var onUpdate: (([SessionInfo]) -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private let sessionsDir: URL

    init() {
        sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions")
    }

    func startWatching() {
        loadSessions()

        let fd = open(sessionsDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in self?.loadSessions() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func loadSessions() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else { return }

        let decoder = JSONDecoder()
        var sessions: [SessionInfo] = []

        for file in files where file.pathExtension == "json" {
            guard
                let data = try? Data(contentsOf: file),
                let sf = try? decoder.decode(SessionFile.self, from: data),
                let pid = sf.pid,
                let sessionId = sf.sessionId,
                let cwd = sf.cwd,
                let startedAtMs = sf.startedAt
            else { continue }

            let info = SessionInfo(
                id: file.deletingPathExtension().lastPathComponent,
                sessionId: sessionId,
                cwd: cwd,
                startedAt: Date(timeIntervalSince1970: Double(startedAtMs) / 1000.0),
                pid: pid
            )
            if info.isRunning {
                sessions.append(info)
            }
        }

        sessions.sort { $0.startedAt > $1.startedAt }
        onUpdate?(sessions)
    }

    deinit {
        source?.cancel()
    }
}
