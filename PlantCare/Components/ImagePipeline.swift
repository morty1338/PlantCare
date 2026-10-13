import SwiftUI
import ImageIO
import UIKit

/// Decoded, downsampled images shared across the app, so grids and drags never decode
/// JPEGs on the main thread (the same idea as SoundMarks' `ImagePipeline`).
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 150
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    /// A stable key for a blob of image data: changes when the photo is replaced,
    /// without hashing megabytes (count + the first and last bytes).
    static func key(_ prefix: String, data: Data) -> String {
        var hasher = Hasher()
        hasher.combine(data.count)
        hasher.combine(data.prefix(32))
        hasher.combine(data.suffix(32))
        return "\(prefix)-\(hasher.finalize())"
    }

    /// Decode straight to a thumbnail of at most `maxPixel` on its long side.
    /// ImageIO never materialises the full-size bitmap, so this is fast and light.
    nonisolated static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel)
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// An image from stored data: an already prepared thumbnail is shown instantly from the
/// cache; otherwise it is decoded off the main thread and fades in.
struct CachedImage: View {
    let data: Data?
    let key: String
    /// Long side of the decoded thumbnail in pixels (≈ view size × screen scale).
    var maxPixel: CGFloat = 400
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        let shown = image ?? ImageCache.shared.image(for: key)
        ZStack {
            if let shown {
                Image(uiImage: shown)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Theme.mint)
            }
        }
        .task(id: key) {
            guard let data else { image = nil; return }
            if let ready = ImageCache.shared.image(for: key) {
                image = ready
                return
            }
            let maxPixel = maxPixel
            let decoded = await Task.detached(priority: .userInitiated) {
                ImageCache.downsample(data, maxPixel: maxPixel)
            }.value
            guard !Task.isCancelled, let decoded else { return }
            ImageCache.shared.insert(decoded, for: key)
            image = decoded
        }
    }
}

/// One-off image preparation done before storing or displaying a photo.
enum ImagePrep {
    /// Redraw at most `maxPixel` on the long side (orientation applied, alpha kept).
    /// Safe to call off the main thread.
    nonisolated static func downscale(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxPixel, longest > 0 else { return image }
        let scale = maxPixel / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Downscale and encode for storage, off the main thread. PNG keeps a cut-out's
    /// transparency; everything else is a compact JPEG.
    static func storageData(for image: UIImage, maxPixel: CGFloat, png: Bool = false) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            let small = downscale(image, maxPixel: maxPixel)
            return png ? small.pngData() : small.jpegData(compressionQuality: 0.78)
        }.value
    }
}
