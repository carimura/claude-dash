import Foundation

struct Session: Identifiable, Hashable {
    let id: String
    let projectDir: String
    let cwd: String
    let title: String
    let lastActivity: Date
    let messageCount: Int
}

enum SessionScanner {
    static func scan() -> [Session] {
        let root = "\(NSHomeDirectory())/.claude/projects"
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var sessions: [Session] = []
        for project in projects {
            let projDir = "\(root)/\(project)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projDir, isDirectory: &isDir), isDir.boolValue,
                  let files = try? fm.contentsOfDirectory(atPath: projDir) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let path = "\(projDir)/\(file)"
                let id = String(file.dropLast(6))
                let attrs = try? fm.attributesOfItem(atPath: path)
                let mtime = (attrs?[.modificationDate] as? Date) ?? .distantPast

                guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
                let lines = content.split(separator: "\n", omittingEmptySubsequences: true)

                var cwd = ""
                var title = ""
                for line in lines {
                    if !cwd.isEmpty && !title.isEmpty { break }
                    guard let data = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }
                    if cwd.isEmpty, let c = obj["cwd"] as? String { cwd = c }
                    if title.isEmpty,
                       obj["type"] as? String == "user",
                       let msg = obj["message"] as? [String: Any],
                       let text = msg["content"] as? String,
                       !text.isEmpty {
                        title = text
                    }
                }

                sessions.append(Session(
                    id: id,
                    projectDir: project,
                    cwd: cwd,
                    title: title.isEmpty ? "(no title)" : title,
                    lastActivity: mtime,
                    messageCount: lines.count
                ))
            }
        }
        return sessions.sorted { $0.lastActivity > $1.lastActivity }
    }
}

enum ActiveDetector {
    static func activeIds() -> Set<String> {
        let psOut = runCmd("/bin/ps", ["-axo", "pid=,comm="])
        let pids = psOut.split(separator: "\n").compactMap { line -> String? in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2 else { return nil }
            var comm = String(parts.last!)
            if comm.hasPrefix("-") { comm.removeFirst() }
            guard comm == "claude" else { return nil }
            return String(parts[0])
        }

        let root = "\(NSHomeDirectory())/.claude/projects"
        let fm = FileManager.default
        var active = Set<String>()

        for pid in pids {
            let lsofOut = runCmd("/usr/sbin/lsof", ["-a", "-p", pid, "-d", "cwd", "-Fn"])
            let cwd = lsofOut.split(separator: "\n")
                .first { $0.hasPrefix("n") }
                .map { String($0.dropFirst()) }
            guard let cwd else { continue }
            let encoded = encodeCwd(cwd)
            let projDir = "\(root)/\(encoded)"
            guard let files = try? fm.contentsOfDirectory(atPath: projDir) else { continue }

            var newestId: String?
            var newestTime = Date.distantPast
            for file in files where file.hasSuffix(".jsonl") {
                let path = "\(projDir)/\(file)"
                let attrs = try? fm.attributesOfItem(atPath: path)
                let mtime = (attrs?[.modificationDate] as? Date) ?? .distantPast
                if mtime > newestTime {
                    newestTime = mtime
                    newestId = String(file.dropLast(6))
                }
            }
            if let id = newestId { active.insert(id) }
        }
        return active
    }
}

enum Resumer {
    static func resume(_ s: Session) {
        let cwd = s.cwd.isEmpty ? NSHomeDirectory() : s.cwd
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-na", "Ghostty.app", "--args",
                          "--working-directory=\(cwd)",
                          "--quit-after-last-window-closed=true",
                          "--command=claude --resume \(s.id)"]
        try? task.run()
    }
}

private func encodeCwd(_ cwd: String) -> String {
    var s = ""
    for ch in cwd {
        s.append((ch == "/" || ch == ".") ? "-" : ch)
    }
    return s
}

private func runCmd(_ path: String, _ args: [String]) -> String {
    let task = Process()
    task.launchPath = path
    task.arguments = args
    let out = Pipe()
    task.standardOutput = out
    task.standardError = FileHandle(forWritingAtPath: "/dev/null")
    do { try task.run() } catch { return "" }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}
