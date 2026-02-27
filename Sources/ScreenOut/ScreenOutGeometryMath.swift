import CoreGraphics

package enum ScreenOutGeometryMath {
    package static func sourceFrameInOverlayCoordinates(sourceFrame: CGRect, in bounds: CGRect) -> CGRect {
        guard sourceFrame.width > 0,
              sourceFrame.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return .zero
        }

        let centerX = sourceFrame.midX - bounds.midX
        let centerY = sourceFrame.midY - bounds.midY

        return CGRect(
            x: centerX - sourceFrame.width / 2,
            y: centerY - sourceFrame.height / 2,
            width: sourceFrame.width,
            height: sourceFrame.height
        )
    }

    package static func targetFrame(for sourceFrame: CGRect, in bounds: CGRect) -> CGRect {
        let safeBoundsWidth = max(bounds.width, 1)
        let safeBoundsHeight = max(bounds.height, 1)

        guard sourceFrame.width > 0, sourceFrame.height > 0 else {
            return CGRect(
                x: -safeBoundsWidth / 2,
                y: -safeBoundsHeight / 2,
                width: safeBoundsWidth,
                height: safeBoundsHeight
            )
        }

        // Keep the full image visible in preview (aspectFit).
        let widthScale = safeBoundsWidth / sourceFrame.width
        let heightScale = safeBoundsHeight / sourceFrame.height
        let scale = min(widthScale, heightScale)

        let targetWidth = sourceFrame.width * scale
        let targetHeight = sourceFrame.height * scale

        return CGRect(
            x: -targetWidth / 2,
            y: -targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
    }

    package static func interpolatedFrame(from sourceFrame: CGRect, to targetFrame: CGRect, progress: Double) -> CGRect {
        let p = min(max(progress, 0), 1)

        return CGRect(
            x: sourceFrame.origin.x + (targetFrame.origin.x - sourceFrame.origin.x) * p,
            y: sourceFrame.origin.y + (targetFrame.origin.y - sourceFrame.origin.y) * p,
            width: sourceFrame.width + (targetFrame.width - sourceFrame.width) * p,
            height: sourceFrame.height + (targetFrame.height - sourceFrame.height) * p
        )
    }
}
