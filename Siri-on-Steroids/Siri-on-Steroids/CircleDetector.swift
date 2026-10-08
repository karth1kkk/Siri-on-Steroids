//
//  CircleDetector.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import Foundation
import CoreGraphics

struct CircleDetector {

    static func isCircle(
        points: [CGPoint]
    ) -> Bool {

        guard points.count >= 20 else {
            return false
        }

        // Bounding box
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0

        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0

        let width = maxX - minX
        let height = maxY - minY

        guard width > 20, height > 20 else {
            return false
        }

        // A circle shouldn't be extremely wide or tall.
        let aspectRatio = width / height

        guard aspectRatio > 0.6,
              aspectRatio < 1.4 else {
            return false
        }

        // Center of bounding box
        let center = CGPoint(
            x: (minX + maxX) / 2,
            y: (minY + maxY) / 2
        )

        // Calculate distance of every point from center
        let distances = points.map { point in

            hypot(
                point.x - center.x,
                point.y - center.y
            )
        }

        let averageRadius =
            distances.reduce(0, +) /
            CGFloat(distances.count)

        guard averageRadius > 10 else {
            return false
        }

        // Check how consistently points stay
        // around the circle's radius.
        let variance =
            distances.reduce(0) { result, distance in

                result +
                abs(distance - averageRadius)
            } / CGFloat(distances.count)

        let normalizedVariance =
            variance / averageRadius

        guard normalizedVariance < 0.35 else {
            return false
        }

        // Check that the path ends reasonably close
        // to where it started.
        guard let first = points.first,
              let last = points.last else {
            return false
        }

        let closureDistance = hypot(
            last.x - first.x,
            last.y - first.y
        )

        guard closureDistance <
                averageRadius * 0.5 else {
            return false
        }

        return true
    }
}
