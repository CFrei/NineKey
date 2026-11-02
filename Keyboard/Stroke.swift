import CoreGraphics
import Foundation

/// Records the points of one touch on a key, for recognising shapes like a circle.
final class Stroke {
    private(set) var points: [CGPoint] = []

    func begin(at point: CGPoint) {
        points = [point]
    }

    func add(_ point: CGPoint) {
        guard let last = points.last, hypot(point.x - last.x, point.y - last.y) >= 2 else { return }
        points.append(point)
    }

    /// True when the stroke is round (not a line or a back-and-forth swipe in any direction)
    /// and winds nearly all the way around its own centre.
    var isCircle: Bool {
        guard points.count >= 8 else { return false }
        let count = CGFloat(points.count)
        let centerX = points.map(\.x).reduce(0, +) / count
        let centerY = points.map(\.y).reduce(0, +) / count

        // Spread along the stroke's widest and narrowest axes (eigenvalues of the covariance).
        var xx: CGFloat = 0, yy: CGFloat = 0, xy: CGFloat = 0
        for point in points {
            let dx = point.x - centerX
            let dy = point.y - centerY
            xx += dx * dx
            yy += dy * dy
            xy += dx * dy
        }
        xx /= count
        yy /= count
        xy /= count
        let half = (xx + yy) / 2
        let spread = sqrt(max(0, half * half - (xx * yy - xy * xy)))
        let major = half + spread
        let minor = half - spread
        guard minor >= 16, minor / major >= 0.12 else { return false }

        var previous = atan2(points[0].y - centerY, points[0].x - centerX)
        var winding: CGFloat = 0
        for point in points.dropFirst() {
            let angle = atan2(point.y - centerY, point.x - centerX)
            var delta = angle - previous
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            winding += delta
            previous = angle
        }
        return abs(winding) >= 1.6 * .pi
    }
}
