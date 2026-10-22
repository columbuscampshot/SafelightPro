import Foundation

/// The four positions on the Camp Snap Pro filter dial.
enum DialSlot: String, CaseIterable, Identifiable {
    case std, vtg1, vtg2, bw

    var id: String { rawValue }
    var fileName: String { "\(rawValue).flt" }
    var tray: Int { (DialSlot.allCases.firstIndex(of: self) ?? 0) + 1 }
    var dialLabel: String { rawValue.uppercased() }
}

struct TrayContents: Equatable {
    let data: Data
    let fingerprint: String
}

/// One photo (a "frame") sitting on the camera.
struct CameraPhoto: Identifiable, Hashable {
    let url: URL
    let relativePath: String
    let size: Int
    let date: Date
    let isVideo: Bool

    /// Stable identity used to remember what has already been developed.
    var key: String { "\(relativePath.lowercased())|\(size)|\(Int(date.timeIntervalSince1970))" }
    var id: String { key }
}

enum CameraError: LocalizedError {
    case notConnected
    case verifyFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Plug in your camera first."
        case .verifyFailed: return "The filter didn't copy cleanly. Try again."
        }
    }
}

/// Talks to the camera's storage through a folder the user picks once.
/// iOS remembers that permission with a bookmark, so later plug-ins connect on their own.
@MainActor
final class CameraStore: ObservableObject {
    @Published private(set) var rootURL: URL?
    @Published private(set) var isConnected = false
    @Published private(set) var hasBookmark = false
    @Published private(set) var looksLikeCamera = true
    @Published private(set) var trays: [DialSlot: TrayContents] = [:]
    @Published private(set) var photos: [CameraPhoto] = []
    @Published private(set) var isScanning = false

    private let bookmarkKey = "safelight.cameraBookmark"
    private var isAccessing = false

    init() {
        hasBookmark = UserDefaults.standard.data(forKey: bookmarkKey) != nil
        refresh()
    }

    // MARK: Connection

    func connect(to url: URL) {
        release()
        let scoped = url.startAccessingSecurityScopedResource()
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            hasBookmark = true
        }
        rootURL = url
        isAccessing = scoped
        refresh()
    }

    func forget() {
        release()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        hasBookmark = false
        rootURL = nil
        markDisconnected()
    }

    /// Re-checks the camera. Cheap enough to call on a timer.
    func poll() {
        if isConnected {
            if let root = rootURL, !Self.isReachable(root) { refresh() }
        } else if hasBookmark {
            refresh()
        }
    }

    func refresh() {
        if rootURL == nil || !Self.isReachable(rootURL!) {
            release()
            rootURL = nil
            if let resolved = resolveBookmark() {
                let (url, stale) = resolved
                isAccessing = url.startAccessingSecurityScopedResource()
                rootURL = url
                if stale, let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(data, forKey: bookmarkKey)
                }
            }
        }

        guard let root = rootURL, Self.isReachable(root) else {
            markDisconnected()
            return
        }

        isConnected = true
        readTrays(in: root)
        let hasDCIM = FileManager.default.fileExists(atPath: root.appendingPathComponent("DCIM").path)
        looksLikeCamera = hasDCIM || !trays.isEmpty
        scanPhotos(in: root)
    }

    private func markDisconnected() {
        isConnected = false
        trays = [:]
        photos = []
    }

    private func release() {
        if isAccessing, let url = rootURL { url.stopAccessingSecurityScopedResource() }
        isAccessing = false
    }

    private func resolveBookmark() -> (URL, Bool)? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        return (url, stale)
    }

    nonisolated static func isReachable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    // MARK: Trays (filters on the camera)

    private func slotURL(_ slot: DialSlot, in root: URL) -> URL? {
        let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return items.first { $0.lastPathComponent.lowercased() == slot.fileName }
    }

    private func readTrays(in root: URL) {
        var result: [DialSlot: TrayContents] = [:]
        for slot in DialSlot.allCases {
            if let url = slotURL(slot, in: root), let data = try? Data(contentsOf: url) {
                result[slot] = TrayContents(data: data, fingerprint: Fingerprint.of(data))
            }
        }
        trays = result
    }

    /// Copies a shelf filter onto the camera under the dial name, then reads it back to confirm.
    func load(_ filter: ShelfFilter, into slot: DialSlot) throws {
        guard isConnected, let root = rootURL else { throw CameraError.notConnected }
        let data = try Data(contentsOf: filter.url)
        let fileManager = FileManager.default

        if let existing = slotURL(slot, in: root) {
            try fileManager.removeItem(at: existing)
        }
        let target = root.appendingPathComponent(slot.fileName)
        try data.write(to: target)

        let check = try Data(contentsOf: target)
        guard check == data else { throw CameraError.verifyFailed }
        readTrays(in: root)
    }

    /// Removes the filter file for a dial position so the camera falls back to its built in look.
    func returnToDefault(_ slot: DialSlot) throws {
        guard isConnected, let root = rootURL else { throw CameraError.notConnected }
        if let existing = slotURL(slot, in: root) {
            try FileManager.default.removeItem(at: existing)
        }
        readTrays(in: root)
    }

    // MARK: Photos

    func rescanPhotos() {
        guard isConnected, let root = rootURL else { return }
        scanPhotos(in: root)
    }

    private func scanPhotos(in root: URL) {
        isScanning = true
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                CameraStore.findPhotos(in: root)
            }.value
            self.photos = found
            self.isScanning = false
        }
    }

    nonisolated private static func findPhotos(in root: URL) -> [CameraPhoto] {
        let fileManager = FileManager()
        let dcim = ["DCIM", "dcim"]
            .map { root.appendingPathComponent($0) }
            .first { fileManager.fileExists(atPath: $0.path) } ?? root

        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey]
        guard let enumerator = fileManager.enumerator(at: dcim, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }

        let photoTypes: Set<String> = ["jpg", "jpeg", "png", "heic"]
        let videoTypes: Set<String> = ["mp4", "mov"]
        let rootPath = root.standardizedFileURL.path
        var result: [CameraPhoto] = []

        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            let isVideo = videoTypes.contains(ext)
            guard isVideo || photoTypes.contains(ext) else { continue }

            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile ?? true else { continue }

            var relative = url.standardizedFileURL.path
            if relative.hasPrefix(rootPath) { relative = String(relative.dropFirst(rootPath.count)) }

            result.append(CameraPhoto(
                url: url,
                relativePath: relative,
                size: values?.fileSize ?? 0,
                date: values?.contentModificationDate ?? values?.creationDate ?? .distantPast,
                isVideo: isVideo
            ))
        }

        return result.sorted { ($0.date, $0.relativePath) < ($1.date, $1.relativePath) }
    }

    /// Deletes frames from the camera. Only ever called after the user confirms.
    @discardableResult
    func delete(_ items: [CameraPhoto]) -> Int {
        var removed = 0
        for photo in items {
            do {
                try FileManager.default.removeItem(at: photo.url)
                removed += 1
            } catch {
                continue
            }
        }
        rescanPhotos()
        return removed
    }
}
