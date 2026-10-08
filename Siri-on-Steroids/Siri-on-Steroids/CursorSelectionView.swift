//
//  CursorSelectionView.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import SwiftUI

struct CursorSelectionView: View {

    @ObservedObject var selectionManager:
        CursorSelectionManager

    let screenFrame: CGRect

    let selectionRect: CGRect?

    var body: some View {

        Canvas { context, size in

            let points =
                selectionManager.points

            // Draw cursor trail
            if points.count > 1 {

                for index in 1..<points.count {

                    let previous =
                        points[index - 1]

                    let current =
                        points[index]

                    let previousPoint =
                        convertToLocal(
                            previous,
                            size: size
                        )

                    let currentPoint =
                        convertToLocal(
                            current,
                            size: size
                        )

                    var path = Path()

                    path.move(
                        to: previousPoint
                    )

                    path.addLine(
                        to: currentPoint
                    )

                    let opacity: Double

                    if selectionManager.isSelecting {

                        // Very subtle while drawing
                        opacity = 0.25

                    } else {

                        // Slightly stronger once completed
                        opacity = 0.45
                    }

                    context.stroke(
                        path,
                        with: .color(
                            .white.opacity(opacity)
                        ),
                        style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }

            // Draw selected region
            if let selectionRect {

                let rect = convertRectToLocal(
                    selectionRect,
                    size: size
                )

                // Soft translucent fill
                context.fill(
                    Path(
                        roundedRect: rect,
                        cornerRadius: 12
                    ),
                    with: .color(
                        .white.opacity(0.04)
                    )
                )

                // Subtle selection border
                context.stroke(
                    Path(
                        roundedRect: rect,
                        cornerRadius: 12
                    ),
                    with: .color(
                        .white.opacity(0.45)
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: [6, 5]
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func convertToLocal(
        _ point: CGPoint,
        size: CGSize
    ) -> CGPoint {

        CGPoint(
            x: point.x - screenFrame.minX,
            y: screenFrame.maxY - point.y
        )
    }

    private func convertRectToLocal(
        _ rect: CGRect,
        size: CGSize
    ) -> CGRect {

        CGRect(
            x: rect.minX - screenFrame.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}
