import Foundation
import Photos

/// Moves frames from the camera into the Photos app, in a "Camp Snap" album.
/// Remembers what it has developed so it never imports the same frame twice.
@MainActor
final class PhotoDeveloper: ObservableObject {
    @Published private(set) var developed: Set<String>
    @Published private(set) var justDeveloped: Set<String> = []
    @Published private(set) var isDeveloping = false
    @Published private(set) var done = 0
    @Published private(set) var total = 0

    let albumName = "Camp Snap"
    private let developedKey = "safelight.developed"

    init() {
        developed = Set(UserDefaults.standard.stringArray(forKey: developedKey) ?? [])
    }

    func isDeveloped(_ photo: CameraPhoto) -> Bool {
        developed.contains(photo.key)
    }

    func markDeveloped(_ photos: [CameraPhoto]) {
        photos.forEach { developed.insert($0.key) }
        persist()
    }

    func forgetHistory() {
        developed = []
        justDeveloped = []
        persist()
    }

    /// Imports each frame and returns a message for the user.
    func develop(_ photos: [CameraPhoto]) async -> String {
        guard !photos.isEmpty, !isDeveloping else { return "" }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return "Safelight needs access to Photos. Turn it on in Settings, Safelight, Photos."
        }

        isDeveloping = true
        done = 0
        total = photos.count
        defer { isDeveloping = false }

        let album = status == .authorized ? await findOrCreateAlbum() : nil
        var failures = 0

        for photo in photos {
            do {
                try await importFrame(photo, into: album)
                developed.insert(photo.key)
                justDeveloped.insert(photo.key)
                persist()
            } catch {
                failures += 1
            }
            done += 1
        }

        let succeeded = photos.count - failures
        var message = succeeded == 1
            ? "1 print developed into your \(albumName) album."
            : "\(succeeded) prints developed into your \(albumName) album."
        if album == nil && succeeded > 0 {
            message = succeeded == 1 ? "1 print developed into Photos." : "\(succeeded) prints developed into Photos."
        }
        if failures > 0 {
            message += " \(failures) didn't make it. Check the camera is still plugged in and try again."
        }
        return message
    }

    private func importFrame(_ photo: CameraPhoto, into album: PHAssetCollection?) async throws {
        // Copy to a temp file first. Photos can't always read straight from a USB drive.
        let source = photo.url
        let temp = try await Task.detached(priority: .userInitiated) { () throws -> URL in
            let fileManager = FileManager()
            let folder = fileManager.temporaryDirectory.appendingPathComponent("Developing", isDirectory: true)
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(source.pathExtension)
            try fileManager.copyItem(at: source, to: target)
            return target
        }.value
        defer { try? FileManager.default.removeItem(at: temp) }

        do {
            try await addAsset(from: temp, name: source.lastPathComponent, isVideo: photo.isVideo, album: album)
        } catch where album != nil {
            // If the album step fails, still get the photo into the library.
            try await addAsset(from: temp, name: source.lastPathComponent, isVideo: photo.isVideo, album: nil)
        }
    }

    private func addAsset(from file: URL, name: String, isVideo: Bool, album: PHAssetCollection?) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = name
            request.addResource(with: isVideo ? .video : .photo, fileURL: file, options: options)

            if let album,
               let placeholder = request.placeholderForCreatedAsset,
               let albumChange = PHAssetCollectionChangeRequest(for: album) {
                albumChange.addAssets([placeholder] as NSArray)
            }
        }
    }

    private func findOrCreateAlbum() async -> PHAssetCollection? {
        let name = albumName
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        if let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject {
            return existing
        }

        let box = IdentifierBox()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                box.value = request.placeholderForCreatedAssetCollection.localIdentifier
            }
        } catch {
            return nil
        }
        guard let identifier = box.value else { return nil }
        return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    private func persist() {
        UserDefaults.standard.set(Array(developed), forKey: developedKey)
    }
}

private final class IdentifierBox: @unchecked Sendable {
    var value: String?
}
