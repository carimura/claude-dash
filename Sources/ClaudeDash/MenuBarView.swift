import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var names: ProjectNames
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 8, height: 8).opacity(store.active.isEmpty ? 0.2 : 1)
                Text("\(store.active.count) active").font(.callout.weight(.medium))
                Spacer()
                Text("\(store.sessions.count) total").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()

            if store.sessions.isEmpty {
                Text("No sessions yet").font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visible) { s in
                        rowButton(s)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Label("Open Dashboard", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14).padding(.vertical, 6)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14).padding(.bottom, 12).padding(.top, 2)
        }
        .frame(width: 360)
    }

    private var visible: [Session] {
        let latest = store.latestPerDir
        let active = latest.filter { store.active.contains($0.id) }
        let inactive = latest.filter { !store.active.contains($0.id) }.prefix(8)
        return active + Array(inactive)
    }

    private func rowButton(_ s: Session) -> some View {
        let isActive = store.active.contains(s.id)
        return Button {
            if !isActive { Resumer.resume(s) }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(isActive ? Color.green : .secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(names.name(for: projectPath(s)))
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1).truncationMode(.tail)
                        Text(shortPath(s.cwd))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Text(oneLine(s.title))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer()
                if isActive {
                    Text("●").foregroundStyle(.green).font(.caption2)
                } else {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14).padding(.vertical, 5)
        }
        .buttonStyle(.borderless)
        .help(isActive ? "Already running" : "Resume in Ghostty")
    }

    private func oneLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private func shortPath(_ p: String) -> String {
        let home = NSHomeDirectory()
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    private func projectPath(_ s: Session) -> String {
        s.cwd.isEmpty ? s.projectDir : s.cwd
    }
}
