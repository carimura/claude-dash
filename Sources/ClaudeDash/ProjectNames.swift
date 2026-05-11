import Foundation
import SwiftUI

@MainActor
final class ProjectNames: ObservableObject {
    @Published private(set) var custom: [String: String] = [:]

    private let url: URL

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClaudeDash")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.url = support.appendingPathComponent("names.json")
        if let data = try? Data(contentsOf: url),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            self.custom = dict
        }
    }

    func name(for path: String) -> String {
        custom[path] ?? Self.defaultName(for: path)
    }

    func hasCustomName(for path: String) -> Bool {
        custom[path] != nil
    }

    func setName(_ name: String, for path: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == Self.defaultName(for: path) {
            custom.removeValue(forKey: path)
        } else {
            custom[path] = trimmed
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(custom) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func defaultName(for path: String) -> String {
        let last = (path as NSString).lastPathComponent
        let parts = last.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })
        return parts
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
