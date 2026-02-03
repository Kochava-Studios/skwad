import Foundation
import AppKit

extension NSImage {

    // MARK: - Scaling

    /// Scales the image to fit within the target size while preserving aspect ratio.
    /// Uses modern CGContext-based drawing instead of deprecated lockFocus/unlockFocus.
    func scalePreservingAspectRatio(targetSize: NSSize) -> NSImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        let scaledSize = NSSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        return drawn(in: scaledSize)
    }

    /// Resizes the image to exactly the target size, stretching if necessary.
    func resized(to targetSize: NSSize) -> NSImage {
        drawn(in: targetSize)
    }

    // MARK: - Centering

    /// Centers the image within a canvas of the specified size with transparent background.
    func centeredInCanvas(size canvasSize: NSSize) -> NSImage {
        let x = (canvasSize.width - size.width) / 2
        let y = (canvasSize.height - size.height) / 2

        return NSImage(size: canvasSize, flipped: false) { rect in
            self.draw(
                at: NSPoint(x: x, y: y),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
    }

    // MARK: - Cropping

    /// Crops the image to a circle with the specified diameter.
    func croppedToCircle(diameter: CGFloat) -> NSImage {
        let outputSize = NSSize(width: diameter, height: diameter)

        return NSImage(size: outputSize, flipped: false) { rect in
            let circlePath = NSBezierPath(ovalIn: rect)
            circlePath.addClip()

            self.draw(
                in: rect,
                from: NSRect(origin: .zero, size: self.size),
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
    }

    /// Crops the image with the specified transform (scale and offset) to the target size.
    func cropped(to targetSize: NSSize, scale: CGFloat, offset: CGSize, circular: Bool = false) -> NSImage {
        let imageSize = size

        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let fillScale = max(widthRatio, heightRatio)

        let fillWidth = imageSize.width * fillScale
        let fillHeight = imageSize.height * fillScale

        let finalWidth = fillWidth * scale
        let finalHeight = fillHeight * scale

        let drawX = (targetSize.width - finalWidth) / 2 + offset.width
        let drawY = (targetSize.height - finalHeight) / 2 - offset.height

        return NSImage(size: targetSize, flipped: false) { rect in
            if circular {
                let circlePath = NSBezierPath(ovalIn: rect)
                circlePath.addClip()
            }

            self.draw(
                in: NSRect(x: drawX, y: drawY, width: finalWidth, height: finalHeight),
                from: NSRect(origin: .zero, size: imageSize),
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
    }

    // MARK: - Base64 Encoding

    /// Converts the image to a base64-encoded PNG data URI string.
    /// Returns nil if encoding fails.
    func toBase64PNG() -> String? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }

    /// Resizes to target size and converts to base64 PNG data URI.
    /// Returns fallback string if encoding fails.
    func toBase64PNG(resizedTo targetSize: NSSize, fallback: String = "🤖") -> String {
        resized(to: targetSize).toBase64PNG() ?? fallback
    }

    // MARK: - Private Helpers

    /// Draws the image into a new image of the specified size using modern CGContext.
    private func drawn(in targetSize: NSSize) -> NSImage {
        NSImage(size: targetSize, flipped: false) { rect in
            self.draw(
                in: rect,
                from: NSRect(origin: .zero, size: self.size),
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
    }
}
