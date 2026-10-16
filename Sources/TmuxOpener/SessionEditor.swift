import SwiftUI

struct SessionEditor: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State var draft: TmuxSession
    let isNew: Bool

    @State private var confirmDelete = false
    @State private var copied = false

    private var portBinding: Binding<String> {
        Binding(
            get: { draft.port.map(String.init) ?? "" },
            set: { draft.port = Int($0.filter(\.isNumber)) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                Section("Appearance") {
                    TextField("Name", text: $draft.name, prompt: Text("Home Server"))
                    LabeledContent("Color") { colorPicker }
                    LabeledContent("Icon") { symbolPicker }
                }

                Section {
                    Toggle("Use a custom command", isOn: $draft.useCustomCommand.animation())
                } footer: {
                    Text("Type the full command that will run in iTerm yourself.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if draft.useCustomCommand {
                    Section("Command") {
                        TextEditor(text: $draft.customCommand)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 70)
                            .scrollContentBackground(.hidden)
                    }
                } else {
                    Section {
                        TextField("User", text: $draft.user, prompt: Text("user"))
                        TextField("Host", text: $draft.host, prompt: Text("server.local — empty for this Mac"))
                        TextField("Port", text: portBinding, prompt: Text("22"))
                        TextField("SSH options", text: $draft.sshOptions, prompt: Text("-i ~/.ssh/id_ed25519 -A"))
                    } header: {
                        Text("SSH Connection")
                    } footer: {
                        Text("Leave the host empty to run tmux on this Mac.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Section("tmux") {
                        TextField("Session", text: $draft.sessionName, prompt: Text(verbatim: draft.name.isEmpty ? "main" : draft.name))
                        TextField("tmux path", text: $draft.tmuxPath, prompt: Text("/opt/homebrew/bin/tmux"))
                        Toggle("iTerm integration (-CC)", isOn: $draft.controlMode)
                    }
                }

                Section("Preview") {
                    HStack(alignment: .top) {
                        Text(draft.command.isEmpty ? "—" : draft.command)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            store.copyCommand(draft)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy Command")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            footer
        }
        .frame(width: 540, height: 680)
        .confirmationDialog("Delete “\(draft.displayName)”?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                store.delete(draft)
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            SessionIcon(symbol: draft.symbol, color: draft.color, size: 52)
                .animation(.spring(response: 0.3), value: draft.colorName)
            VStack(alignment: .leading, spacing: 2) {
                (isNew ? Text("New Session") : Text("Edit Session"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                (draft.displayName.isEmpty ? Text("Untitled") : Text(verbatim: draft.displayName))
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    private var footer: some View {
        HStack {
            if !isNew {
                Button("Delete…", role: .destructive) { confirmDelete = true }
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isNew ? LocalizedStringKey("Add") : LocalizedStringKey("Save")) {
                store.upsert(draft)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!draft.isValid)
        }
        .padding(16)
    }

    private var colorPicker: some View {
        HStack(spacing: 6) {
            ForEach(Palette.all, id: \.name) { item in
                Circle()
                    .fill(item.color.gradient)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .strokeBorder(.primary.opacity(draft.colorName == item.name ? 0.8 : 0), lineWidth: 2)
                            .padding(-3)
                    )
                    .contentShape(Circle())
                    .onTapGesture { draft.colorName = item.name }
                    .help(item.name)
            }
        }
        .padding(.vertical, 3)
    }

    private var symbolPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 8), spacing: 4) {
            ForEach(Palette.symbols, id: \.self) { symbol in
                let selected = draft.symbol == symbol
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.75))
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selected ? draft.color : Color.primary.opacity(0.05))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { draft.symbol = symbol }
            }
        }
        .padding(.vertical, 3)
    }
}
