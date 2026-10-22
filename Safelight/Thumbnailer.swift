import UIKit
import ImageIO

/// Small, fast previews of camera frames, decoded off the main thread.
enum Thumbnailer {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 400
        return cache
    }()

    static func image(for url: URL, maxPixel: Int = 300) async -> UIImage? {
        let key = "\(url.path)#\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value

        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}
