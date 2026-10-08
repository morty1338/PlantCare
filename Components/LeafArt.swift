import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The user's hand-drawn leaf, lightened toward white so that — drawn with a
/// multiply blend — the white paper maps to the background and the inked veins
/// become a soft watermark. Processed once, off the main thread, to avoid any
/// hitch on the first frame.
enum LeafArt {
    private static var cached: Image?

    /// Load (and cache) the watermark asynchronously.
    static func load() async -> Image? {
        if let cached { return cached }
        let image = await Task.detached(priority: .utility) { make() }.value
        cached = image
        return image
    }

    private static func make() -> Image? {
        guard let ui = UIImage(named: "DrawnLeaf"), let cg = ui.cgImage else { return nil }
        let input = CIImage(cgImage: cg)

        // out = 0.4·in + 0.6  → white stays 1 (invisible under multiply),
        // darkest ink lifts to ~0.6 (a gentle, readable watermark).
        let m = CIFilter.colorMatrix()
        m.inputImage = input
        m.rVector = CIVector(x: 0.4, y: 0, z: 0, w: 0)
        m.gVector = CIVector(x: 0, y: 0.4, z: 0, w: 0)
        m.bVector = CIVector(x: 0, y: 0, z: 0.4, w: 0)
        m.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        m.biasVector = CIVector(x: 0.6, y: 0.6, z: 0.6, w: 0)

        guard let out = m.outputImage,
              let cgOut = CIContext().createCGImage(out, from: input.extent) else { return nil }
        return Image(uiImage: UIImage(cgImage: cgOut))
    }
}
