import Foundation
import CryptoKit

/// A filter file kept on the phone, ready to load into a tray.
struct ShelfFilter: Identifiable, Hashable {
    let url: URL
    let fingerprint: String

    var id: String { url.lastPathComponent }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var note: String? { FilterNotes.note(for: name) }
    var isMonochrome: Bool {
        let n = name.lowercased()
        return ["b&w", "bw", "noir", "charcoal", "mono", "sin city"].contains { n.contains($0) }
    }
}

enum Fingerprint {
    static func of(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// The chemical shelf: every .flt file lives in Documents/Filters.
/// That folder also shows up in the Files app under On My iPhone, Safelight.
@MainActor
final class FilterLibrary: ObservableObject {
    @Published private(set) var filters: [ShelfFilter] = []

    let folder: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = docs.appendingPathComponent("Filters", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        filters = urls
            .filter { $0.pathExtension.lowercased() == "flt" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return ShelfFilter(url: url, fingerprint: Fingerprint.of(data))
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func match(_ fingerprint: String?) -> ShelfFilter? {
        guard let fingerprint else { return nil }
        return filters.first { $0.fingerprint == fingerprint }
    }

    /// Copies picked .flt files onto the shelf. Returns a message for the user.
    func importFiles(_ urls: [URL]) -> String {
        var added = 0, duplicates = 0, ignored = 0
        var known = Set(filters.map(\.fingerprint))

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            guard url.pathExtension.lowercased() == "flt", let data = try? Data(contentsOf: url) else {
                ignored += 1
                continue
            }
            let fingerprint = Fingerprint.of(data)
            if known.contains(fingerprint) {
                duplicates += 1
                continue
            }
            if write(data, named: url.deletingPathExtension().lastPathComponent) {
                added += 1
                known.insert(fingerprint)
            }
        }
        reload()

        var parts = [added == 1 ? "1 filter added to the shelf" : "\(added) filters added to the shelf"]
        if duplicates > 0 { parts.append("\(duplicates) already there") }
        if ignored > 0 { parts.append("\(ignored) skipped because they aren't .flt files") }
        return parts.joined(separator: ", ") + "."
    }

    /// Saves raw filter data (for example, a backup of what's on the camera).
    @discardableResult
    func save(_ data: Data, named name: String) -> ShelfFilter? {
        let fingerprint = Fingerprint.of(data)
        if let existing = match(fingerprint) { return existing }
        guard write(data, named: name) else { return nil }
        reload()
        return match(fingerprint)
    }

    func rename(_ filter: ShelfFilter, to newName: String) throws {
        let clean = Self.clean(newName)
        guard !clean.isEmpty, clean != filter.name else { return }
        try FileManager.default.moveItem(at: filter.url, to: uniqueURL(for: clean))
        reload()
    }

    func delete(_ filter: ShelfFilter) {
        try? FileManager.default.removeItem(at: filter.url)
        reload()
    }

    private func write(_ data: Data, named name: String) -> Bool {
        let clean = Self.clean(name)
        let target = uniqueURL(for: clean.isEmpty ? "Untitled" : clean)
        return (try? data.write(to: target, options: .atomic)) != nil
    }

    private func uniqueURL(for name: String) -> URL {
        var candidate = folder.appendingPathComponent(name).appendingPathExtension("flt")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) \(counter)").appendingPathExtension("flt")
            counter += 1
        }
        return candidate
    }

    private static func clean(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
