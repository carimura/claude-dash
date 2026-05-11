import SwiftUI

@main
struct ClaudeDashApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var names = ProjectNames()

    var body: some Scene {
        Window("Claude Sessions", id: "main") {
            SessionListView()
                .environmentObject(store)
                .environmentObject(names)
                .frame(minWidth: 720, minHeight: 480)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(names)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "rectangle.stack")
                if !store.active.isEmpty {
                    Text("\(store.active.count)").font(.caption.weight(.semibold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var active: Set<String> = []
    @Published var isRefreshing = false
    @Published var lastRefresh: Date?

    var latestPerDir: [Session] {
        var seen = Set<String>()
        var result: [Session] = []
        for s in sessions {
            let key = s.cwd.isEmpty ? s.projectDir : s.cwd
            if seen.insert(key).inserted { result.append(s) }
        }
        return result
    }

    private static let sevenDays: TimeInterval = 7 * 24 * 3600

    var recent: [Session] {
        let cutoff = Date().addingTimeInterval(-Self.sevenDays)
        return latestPerDir.filter { $0.lastActivity > cutoff }
    }

    var older: [Session] {
        let cutoff = Date().addingTimeInterval(-Self.sevenDays)
        return latestPerDir.filter { $0.lastActivity <= cutoff }
    }

    private var timer: Timer?

    init() { start() }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        isRefreshing = true
        Task.detached {
            let s = SessionScanner.scan()
            let a = ActiveDetector.activeIds()
            await MainActor.run { [weak self] in
                self?.sessions = s
                self?.active = a
                self?.lastRefresh = Date()
                self?.isRefreshing = false
            }
        }
    }
}
