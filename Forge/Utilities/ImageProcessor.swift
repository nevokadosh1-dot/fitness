import UIKit

/// Downscales and re-encodes imported images so hundreds of photos stay fast
/// and compact, while preserving the original aspect ratio.
enum ImageProcessor {

    /// Returns JPEG data resized so the longest side is at most `maxDimension`.
    static func compressedImageData(from data: Data, maxDimension: CGFloat, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    /// Small square-ish thumbnail for grids.
    static func thumbnailData(from data: Data, maxDimension: CGFloat = 320) -> Data? {
        compressedImageData(from: data, maxDimension: maxDimension, quality: 0.7)
    }

    static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
