#!/usr/bin/env swift
import Foundation

struct Session {
    let id: String
    let projectDir: String
    let cwd: String
    let title: String
    let lastActivity: Date
    let messageCount: Int
}

func findSessions() -> [Session] {
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

func runCmd(_ path: String, _ args: [String]) -> String {
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

func activeSessionIds() -> Set<String> {
    let psOut = runCmd("/bin/ps", ["-axo", "pid=,comm="])
    let pids = psOut.split(separator: "\n").compactMap { line -> String? in
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, parts.last == "claude" else { return nil }
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
        let encoded = cwd.replacingOccurrences(of: "/", with: "-")
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

func ago(_ date: Date) -> String {
    let s = Date().timeIntervalSince(date)
    if s < 60 { return "\(Int(s))s ago" }
    if s < 3600 { return "\(Int(s / 60))m ago" }
    if s < 86400 { return "\(Int(s / 3600))h ago" }
    return "\(Int(s / 86400))d ago"
}

func truncate(_ s: String, _ n: Int) -> String {
    let oneLine = s.replacingOccurrences(of: "\n", with: " ")
    return oneLine.count > n ? String(oneLine.prefix(n - 1)) + "…" : oneLine
}

func resume(_ s: Session) {
    let cwd = s.cwd.isEmpty ? NSHomeDirectory() : s.cwd
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = ["-na", "Ghostty.app", "--args",
                      "--working-directory=\(cwd)",
                      "--command=claude --resume \(s.id)"]
    do { try task.run(); task.waitUntilExit() }
    catch { print("launch failed: \(error)"); exit(1) }
}

let args = CommandLine.arguments
let cmd = args.count >= 2 ? args[1] : "list"

switch cmd {
case "list":
    let sessions = findSessions()
    let active = activeSessionIds()
    let idxW = String(sessions.count - 1).count
    for (i, s) in sessions.enumerated() {
        let idx = String(i).leftPad(idxW)
        let dot = active.contains(s.id) ? "●" : " "
        let id = String(s.id.prefix(8))
        let when = ago(s.lastActivity).leftPad(8)
        let title = truncate(s.title, 60)
        print("\(idx) \(dot) \(id)  \(when)  \(title)")
    }
case "debug":
    let psOut = runCmd("/bin/ps", ["-axo", "pid=,comm="])
    let pids = psOut.split(separator: "\n").compactMap { line -> String? in
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, parts.last == "claude" else { return nil }
        return String(parts[0])
    }
    print("claude pids: \(pids)")
    for pid in pids {
        let lsofOut = runCmd("/usr/sbin/lsof", ["-p", pid, "-d", "cwd", "-Fn"])
        print("--- lsof pid \(pid) ---\n\(lsofOut)---")
        let cwd = lsofOut.split(separator: "\n").first { $0.hasPrefix("n") }.map { String($0.dropFirst()) }
        print("cwd: \(cwd ?? "nil")")
        if let cwd {
            let encoded = cwd.replacingOccurrences(of: "/", with: "-")
            print("encoded: \(encoded)")
        }
    }
    print("active set: \(activeSessionIds())")
case "watch":
    while true {
        _ = runCmd("/usr/bin/clear", [])
        let sessions = findSessions()
        let active = activeSessionIds()
        let idxW = String(max(sessions.count - 1, 0)).count
        print("claude sessions  (active: \(active.count))  ⌃C to exit\n")
        for (i, s) in sessions.prefix(15).enumerated() {
            let idx = String(i).leftPad(idxW)
            let dot = active.contains(s.id) ? "●" : " "
            let id = String(s.id.prefix(8))
            let when = ago(s.lastActivity).leftPad(8)
            let title = truncate(s.title, 60)
            print("\(idx) \(dot) \(id)  \(when)  \(title)")
        }
        Thread.sleep(forTimeInterval: 4)
    }
case "resume":
    guard args.count >= 3, let idx = Int(args[2]) else {
        print("usage: prototype.swift resume <index>"); exit(2)
    }
    let sessions = findSessions()
    guard idx >= 0 && idx < sessions.count else {
        print("index out of range (0..\(sessions.count - 1))"); exit(2)
    }
    let s = sessions[idx]
    print("resuming \(s.id) in \(s.cwd)")
    resume(s)
default:
    print("usage: prototype.swift [list|resume <index>]")
    exit(2)
}

extension String {
    func leftPad(_ n: Int) -> String {
        count >= n ? self : String(repeating: " ", count: n - count) + self
    }
}
