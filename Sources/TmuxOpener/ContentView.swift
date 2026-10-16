import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @State private var search = ""
    @Environment(\.openSettings) private var openSettings

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 420), spacing: 14)]

    private var filtered: [TmuxSession] {
        let q = search.trimmed.lowercased()
        guard !q.isEmpty else { return store.sessions }
        return store.sessions.filter { $0.searchText.contains(q) }
    }

    var body: some View {
        Group {
            if store.sessions.isEmpty {
                emptyState
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filtered) { session in
                            SessionCard(session: session)
                                .draggable(session.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                                    withAnimation(.snappy) { store.move(id, to: session.id) }
                                    return true
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BackdropView())
        .navigationTitle("Tmux Opener")
        .navigationSubtitle(subtitle)
        .searchable(text: $search, placement: .toolbar, prompt: "Search sessions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.newSession()
                } label: {
                    Label("New Session", systemImage: "plus")
                }
                .help("New Session (⌘N)")
            }
        }
        .sheet(item: $store.editing) { editing in
            SessionEditor(draft: editing.session, isNew: editing.isNew)
                .environmentObject(store)
        }
        .onAppear { ScreenshotRunner.runIfRequested(store: store) { openSettings() } }
    }

    private var subtitle: String {
        String(localized: "\(store.sessions.count) sessions")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Sessions", systemImage: "rectangle.split.3x1")
        } description: {
            Text("Add a host and a tmux session to open it in iTerm with a single click.")
        } actions: {
            Button("New Session") { store.newSession() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

/// Subtle color wash behind the cards.
struct BackdropView: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.indigo.opacity(0.10), Color.clear, Color.teal.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

struct SessionIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.95), color.opacity(0.70)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            )
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.35), radius: 4, y: 2)
    }
}

struct SessionCard: View {
    @EnvironmentObject var store: SessionStore
    let session: TmuxSession

    @State private var hovering = false
    @State private var launched = false

    var body: some View {
        Button(action: launch) {
            HStack(spacing: 14) {
                SessionIcon(symbol: session.symbol, color: session.color, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(session.destination)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 6) {
                        if !session.useCustomCommand {
                            Chip(text: session.effectiveSessionName, systemImage: "rectangle.split.2x1", color: session.color)
                            if session.controlMode {
                                Chip(text: "-CC", systemImage: nil, color: .secondary)
                            }
                        }
                        if let last = session.lastConnected {
                            Text(last, format: .relative(presentation: .named))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 24)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(CardButtonStyle(hovering: hovering, accent: session.color))
        .overlay(alignment: .topTrailing) {
            if hovering && !launched {
                Button {
                    store.edit(session)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Edit")
                .padding(8)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .overlay {
            if launched {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Label("Opening in iTerm…", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(session.color)
                    )
                    .transition(.opacity)
            }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .help(session.command)
        .contextMenu {
            Button("Connect") { launch() }
            Divider()
            Button("Edit…") { store.edit(session) }
            Button("Duplicate") { store.duplicate(session) }
            Button("Copy Command") { store.copyCommand(session) }
            Divider()
            Button("Delete", role: .destructive) {
                withAnimation { store.delete(session) }
            }
        }
    }

    private func launch() {
        guard store.launch(session) else { return }
        withAnimation(.easeOut(duration: 0.2)) { launched = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.3)) { launched = false }
        }
    }
}

struct Chip: View {
    let text: String
    let systemImage: String?
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(text).lineLimit(1)
        }
        .font(.system(.caption, design: .monospaced).weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(color)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct CardButtonStyle: ButtonStyle {
    var hovering: Bool
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(hovering ? 1 : 0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hovering ? accent.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(hovering ? 0.12 : 0.05), radius: hovering ? 10 : 3, y: hovering ? 4 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : (hovering ? 1.01 : 1))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
