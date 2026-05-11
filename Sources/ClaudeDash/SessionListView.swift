import SwiftUI

struct SessionListView: View {
    @EnvironmentObject var store: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Claude Dashboard")
                .font(.title2.weight(.semibold))
            Spacer()
            Text("\(store.active.count) active · \(store.latestPerDir.count) projects")
                .foregroundStyle(.secondary)
                .font(.callout)
            if let last = store.lastRefresh {
                Text("updated \(refreshAgo(last))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .id(last)
            }
            Group {
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: { store.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(width: 22, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !store.recent.isEmpty {
                    sectionHeader("Recent", subtitle: "Last 7 days")
                    VStack(spacing: 12) {
                        ForEach(store.recent) { s in
                            RecentRow(session: s, isActive: store.active.contains(s.id))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }

                if !store.older.isEmpty {
                    sectionHeader("Older", subtitle: nil)
                    VStack(spacing: 0) {
                        ForEach(store.older) { s in
                            OlderRow(session: s, isActive: store.active.contains(s.id))
                            Divider().padding(.leading, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func refreshAgo(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 5 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }
}

struct RecentRow: View {
    let session: Session
    let isActive: Bool
    @EnvironmentObject var names: ProjectNames
    @State private var showRename = false
    @State private var draftName = ""

    private var projectPath: String { session.cwd.isEmpty ? session.projectDir : session.cwd }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isActive ? Color.green : Color.secondary.opacity(0.25))
                    .frame(width: 10, height: 10)
                Text(names.name(for: projectPath))
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("(\(displayPath))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if isActive {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.14), in: Capsule())
                } else {
                    Button("Resume") { Resumer.resume(session) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
            }

            Text(oneLineTitle)
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(2)
                .padding(.leading, 20)

            HStack(spacing: 12) {
                Label(relativeTime(session.lastActivity), systemImage: "clock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                pill(text: "\(session.messageCount)", caption: "msgs")
                if session.contextSize > 0 {
                    Text("\(formatTokens(session.contextSize)) context")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if session.totalTokens > 0 {
                    Text("\(formatTokens(session.totalTokens)) tokens")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .help("\(session.inputTokens.formatted()) in · \(session.outputTokens.formatted()) out")
                }
                Text(String(session.id.prefix(8)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.leading, 20)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.green.opacity(0.06) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isActive ? Color.green.opacity(0.35) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .contextMenu {
            Button("Rename…") {
                draftName = names.name(for: projectPath)
                showRename = true
            }
            if names.hasCustomName(for: projectPath) {
                Button("Reset to Default Name") {
                    names.setName("", for: projectPath)
                }
            }
        }
        .alert("Rename Project", isPresented: $showRename) {
            TextField("Name", text: $draftName)
            Button("Save") { names.setName(draftName, for: projectPath) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(displayPath)
        }
    }

    private func pill(text: String, caption: String) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.title3.weight(.semibold).monospacedDigit())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private var displayPath: String {
        let p = session.cwd.isEmpty ? session.projectDir : session.cwd
        let home = NSHomeDirectory()
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    private var oneLineTitle: String {
        session.title.replacingOccurrences(of: "\n", with: " ")
    }

    private func relativeTime(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 60 { return "\(Int(s))s ago" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        return "\(Int(s / 86400))d ago"
    }
}

struct OlderRow: View {
    let session: Session
    let isActive: Bool
    @EnvironmentObject var names: ProjectNames
    @State private var showRename = false
    @State private var draftName = ""

    private var projectPath: String { session.cwd.isEmpty ? session.projectDir : session.cwd }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.2))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(names.name(for: projectPath))
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("(\(displayPath))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(oneLineTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            if session.totalTokens > 0 {
                Text(formatTokens(session.totalTokens))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help("\(session.inputTokens.formatted()) in · \(session.outputTokens.formatted()) out · \(session.messageCount) msgs")
            } else {
                Text("\(session.messageCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(relativeTime(session.lastActivity))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 56, alignment: .trailing)
            if !isActive {
                Button("Resume") { Resumer.resume(session) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Rename…") {
                draftName = names.name(for: projectPath)
                showRename = true
            }
            if names.hasCustomName(for: projectPath) {
                Button("Reset to Default Name") {
                    names.setName("", for: projectPath)
                }
            }
        }
        .alert("Rename Project", isPresented: $showRename) {
            TextField("Name", text: $draftName)
            Button("Save") { names.setName(draftName, for: projectPath) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(displayPath)
        }
    }

    private var displayPath: String {
        let p = session.cwd.isEmpty ? session.projectDir : session.cwd
        let home = NSHomeDirectory()
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    private var oneLineTitle: String {
        session.title.replacingOccurrences(of: "\n", with: " ")
    }

    private func relativeTime(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        return "\(Int(s / 86400))d ago"
    }
}

func formatTokens(_ n: Int) -> String {
    if n < 1000 { return "\(n)" }
    if n < 10_000 { return String(format: "%.1fk", Double(n) / 1000) }
    if n < 1_000_000 { return "\(n / 1000)k" }
    return String(format: "%.1fM", Double(n) / 1_000_000)
}
