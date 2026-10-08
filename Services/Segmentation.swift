import UIKit
import Vision
import CoreImage

/// Lifts the main subject (the plant) out of a photo, returning a transparent
/// cut-out so it can be placed cleanly into a pot. Uses Vision's foreground
/// instance mask (iOS 17+); returns nil when unavailable or on failure.
enum Segmentation {

    static func cutout(from image: UIImage) -> UIImage? {
        guard #available(iOS 17.0, *) else { return nil }
        guard let cg = image.cgImage else { return nil }

        let handler = VNImageRequestHandler(cgImage: cg,
                                            orientation: cgOrientation(image.imageOrientation))
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            return nil
        }
        do {
            let buffer = try result.generateMaskedImage(ofInstances: result.allInstances,
                                                        from: handler,
                                                        croppedToInstancesExtent: true)
            let ci = CIImage(cvPixelBuffer: buffer)
            let context = CIContext(options: nil)
            guard let out = context.createCGImage(ci, from: ci.extent) else { return nil }
            return UIImage(cgImage: out, scale: image.scale, orientation: .up)
        } catch {
            return nil
        }
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
