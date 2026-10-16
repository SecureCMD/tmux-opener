import Foundation
import SwiftUI

/// One entry in the list: where to connect and which tmux session to attach to.
struct TmuxSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = ""
    var user: String = ""
    var host: String = ""
    var port: Int? = nil
    var sshOptions: String = ""
    var sessionName: String = ""
    var tmuxPath: String = "/opt/homebrew/bin/tmux"
    var controlMode: Bool = true
    var useCustomCommand: Bool = false
    var customCommand: String = ""
    var colorName: String = "blue"
    var symbol: String = "terminal"
    var lastConnected: Date? = nil

    init() {}

    // Lenient decoding: missing keys fall back to their default values.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TmuxSession()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        user = try c.decodeIfPresent(String.self, forKey: .user) ?? d.user
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? d.host
        port = try c.decodeIfPresent(Int.self, forKey: .port)
        sshOptions = try c.decodeIfPresent(String.self, forKey: .sshOptions) ?? d.sshOptions
        sessionName = try c.decodeIfPresent(String.self, forKey: .sessionName) ?? d.sessionName
        tmuxPath = try c.decodeIfPresent(String.self, forKey: .tmuxPath) ?? d.tmuxPath
        controlMode = try c.decodeIfPresent(Bool.self, forKey: .controlMode) ?? d.controlMode
        useCustomCommand = try c.decodeIfPresent(Bool.self, forKey: .useCustomCommand) ?? d.useCustomCommand
        customCommand = try c.decodeIfPresent(String.self, forKey: .customCommand) ?? d.customCommand
        colorName = try c.decodeIfPresent(String.self, forKey: .colorName) ?? d.colorName
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? d.symbol
        lastConnected = try c.decodeIfPresent(Date.self, forKey: .lastConnected)
    }

    var displayName: String {
        let n = name.trimmed
        return n.isEmpty ? effectiveSessionName : n
    }

    var effectiveSessionName: String {
        let s = sessionName.trimmed
        return s.isEmpty ? name.trimmed : s
    }

    var isLocal: Bool { host.trimmed.isEmpty }

    /// Short destination label (user@host:port or "Local").
    var destination: String {
        if useCustomCommand { return String(localized: "Custom command") }
        if isLocal { return String(localized: "Local") }
        var d = user.trimmed.isEmpty ? host.trimmed : "\(user.trimmed)@\(host.trimmed)"
        if let port { d += ":\(port)" }
        return d
    }

    var color: Color { Palette.color(named: colorName) }

    /// The command typed into the new iTerm session.
    var command: String {
        if useCustomCommand { return customCommand.trimmed }

        let tmuxBin = tmuxPath.trimmed.isEmpty ? "tmux" : tmuxPath.trimmed
        var tmux = [tmuxBin]
        if controlMode { tmux.append("-CC") }
        tmux += ["new", "-A", "-s", shellQuote(effectiveSessionName)]
        let tmuxCommand = tmux.joined(separator: " ")

        if isLocal { return tmuxCommand }

        var parts = ["ssh", "-t"]
        if let port { parts += ["-p", String(port)] }
        if !sshOptions.trimmed.isEmpty { parts.append(sshOptions.trimmed) }
        parts.append(user.trimmed.isEmpty ? host.trimmed : "\(user.trimmed)@\(host.trimmed)")
        parts.append(shellQuote(tmuxCommand))
        return parts.joined(separator: " ")
    }

    var isValid: Bool {
        if useCustomCommand { return !name.trimmed.isEmpty && !customCommand.trimmed.isEmpty }
        return !effectiveSessionName.isEmpty
    }

    var searchText: String {
        [name, user, host, sessionName, customCommand].joined(separator: " ").lowercased()
    }
}

struct EditingSession: Identifiable {
    let id = UUID()
    var session: TmuxSession
    var isNew: Bool
}

enum OpenMode: String, CaseIterable, Identifiable {
    case window, tab
    var id: String { rawValue }
    var label: String { self == .window ? String(localized: "New window") : String(localized: "New tab") }
}

enum Palette {
    static let all: [(name: String, color: Color)] = [
        ("blue", .blue), ("indigo", .indigo), ("purple", .purple), ("pink", .pink),
        ("red", .red), ("orange", .orange), ("yellow", .yellow), ("green", .green),
        ("mint", .mint), ("teal", .teal), ("cyan", .cyan), ("gray", .gray),
    ]

    static func color(named name: String) -> Color {
        all.first { $0.name == name }?.color ?? .blue
    }

    static let symbols = [
        "terminal", "macmini", "desktopcomputer", "laptopcomputer", "server.rack",
        "pc", "cpu", "memorychip", "externaldrive", "cloud", "network", "globe",
        "house", "building.2", "lock.shield", "bolt", "flask", "hammer",
        "gearshape", "cube", "shippingbox", "leaf", "flame", "star",
    ]
}

enum DefaultsKey {
    static let openMode = "openMode"
    static let itermProfile = "itermProfile"
    static let defaultUser = "defaultUser"
    static let defaultTmuxPath = "defaultTmuxPath"
    static let defaultControlMode = "defaultControlMode"
    static let showMenuBarExtra = "showMenuBarExtra"
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Quotes an argument for sh only when needed.
func shellQuote(_ s: String) -> String {
    let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./:@%+=,")
    if !s.isEmpty && s.unicodeScalars.allSatisfy({ safe.contains($0) }) { return s }
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
