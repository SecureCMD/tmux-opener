import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [TmuxSession] = [] {
        didSet { if !isLoading { save() } }
    }
    @Published var editing: EditingSession?

    private var isLoading = false

    /// `-configDirectory <path>` on the command line overrides the location.
    static var configDirectory: URL {
        if let custom = UserDefaults.standard.string(forKey: "configDirectory"), !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TmuxOpener", isDirectory: true)
    }

    static var fileURL: URL { configDirectory.appendingPathComponent("sessions.json") }

    init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        isLoading = true
        defer { isLoading = false }

        guard let data = try? Data(contentsOf: Self.fileURL) else {
            sessions = Self.examples
            isLoading = false
            save()
            return
        }
        sessions = (try? Self.decoder.decode([TmuxSession].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.configDirectory, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(sessions)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("TmuxOpener: failed to save sessions: \(error)")
        }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static var examples: [TmuxSession] {
        var server = TmuxSession()
        server.name = "Home Server"
        server.user = NSUserName()
        server.host = "homeserver.local"
        server.sessionName = "main"
        server.tmuxPath = "tmux"
        server.symbol = "server.rack"
        server.colorName = "indigo"

        var local = TmuxSession()
        local.name = "This Mac"
        local.sessionName = "local"
        local.symbol = "laptopcomputer"
        local.colorName = "teal"
        return [server, local]
    }

    // MARK: - Editing

    func newSession() {
        let defaults = UserDefaults.standard
        var s = TmuxSession()
        s.user = defaults.string(forKey: DefaultsKey.defaultUser) ?? ""
        if let path = defaults.string(forKey: DefaultsKey.defaultTmuxPath), !path.trimmed.isEmpty {
            s.tmuxPath = path
        }
        if defaults.object(forKey: DefaultsKey.defaultControlMode) != nil {
            s.controlMode = defaults.bool(forKey: DefaultsKey.defaultControlMode)
        }
        s.colorName = Palette.all.randomElement()?.name ?? "blue"
        editing = EditingSession(session: s, isNew: true)
    }

    func edit(_ session: TmuxSession) {
        editing = EditingSession(session: session, isNew: false)
    }

    func upsert(_ session: TmuxSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
    }

    func duplicate(_ session: TmuxSession) {
        var copy = session
        copy.id = UUID()
        copy.name = String(localized: "\(session.displayName) copy")
        copy.lastConnected = nil
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.insert(copy, at: i + 1)
        } else {
            sessions.append(copy)
        }
    }

    func delete(_ session: TmuxSession) {
        sessions.removeAll { $0.id == session.id }
    }

    /// Moves session `id` to the position currently held by `target`.
    func move(_ id: UUID, to target: UUID) {
        guard id != target,
              let from = sessions.firstIndex(where: { $0.id == id }),
              let to = sessions.firstIndex(where: { $0.id == target }) else { return }
        let item = sessions.remove(at: from)
        sessions.insert(item, at: to)
    }

    // MARK: - Launching

    @discardableResult
    func launch(_ session: TmuxSession) -> Bool {
        let defaults = UserDefaults.standard
        let mode = OpenMode(rawValue: defaults.string(forKey: DefaultsKey.openMode) ?? "") ?? .window
        let profile = defaults.string(forKey: DefaultsKey.itermProfile) ?? ""
        do {
            try ITermLauncher.run(command: session.command, mode: mode, profile: profile)
            if let i = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[i].lastConnected = Date()
            }
            return true
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: "Couldn’t open “\(session.displayName)”")
            alert.informativeText = error.localizedDescription
            if case LaunchError.notAuthorized = error {
                alert.addButton(withTitle: String(localized: "Open System Settings"))
                alert.addButton(withTitle: String(localized: "Cancel"))
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                alert.runModal()
            }
            return false
        }
    }

    func copyCommand(_ session: TmuxSession) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.command, forType: .string)
    }

    // MARK: - Import / export

    func exportSessions() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "tmux-sessions.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Self.encoder.encode(sessions).write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func importSessions() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try Self.decoder.decode([TmuxSession].self, from: Data(contentsOf: url))
            let existing = Set(sessions.map(\.id))
            sessions += imported.map { s in
                var s = s
                if existing.contains(s.id) { s.id = UUID() }
                return s
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func revealConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.fileURL])
    }
}
