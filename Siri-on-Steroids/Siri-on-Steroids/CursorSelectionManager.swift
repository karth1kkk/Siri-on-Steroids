//
//  CursorSelectionManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit
import SwiftUI
import Combine

final class CursorSelectionManager: ObservableObject {

    @Published var points: [CGPoint] = []
    @Published var isSelecting = false

    var onSelectionComplete:
        (([CGPoint]) -> Void)?

    var onSelectionStarted:
        (() -> Void)?

    var onSelectionEnded:
        (() -> Void)?

    var onSelectionCancelled:
        (() -> Void)?

    private var mouseMoveMonitor: Any?
    private var mouseUpMonitor: Any?

    // MARK: Start Selection

    func start(
        at initialPosition: CGPoint? = nil
    ) {

        // Install the monitors only once.
        if mouseMoveMonitor == nil {

            mouseMoveMonitor =
                NSEvent.addGlobalMonitorForEvents(
                    matching: [
                        .mouseMoved,
                        .leftMouseDragged
                    ]
                ) { [weak self] _ in

                    guard let self else {
                        return
                    }

                    guard self.isSelecting else {
                        return
                    }

                    let position =
                        NSEvent.mouseLocation

                    DispatchQueue.main.async {

                        guard self.isSelecting else {
                            return
                        }

                        self.points.append(
                            position
                        )
                    }
                }

            mouseUpMonitor =
                NSEvent.addGlobalMonitorForEvents(
                    matching: .leftMouseUp
                ) { [weak self] _ in

                    guard let self else {
                        return
                    }

                    DispatchQueue.main.async {

                        guard self.isSelecting else {
                            return
                        }

                        self.finishSelection()
                    }
                }
        }

        // Start a new selection.
        guard let initialPosition else {
            return
        }

        points.removeAll()

        isSelecting =
            true

        points.append(
            initialPosition
        )

        onSelectionStarted?()

        print(
            "Selection started"
        )

        print(
            "Initial position:",
            initialPosition
        )
    }

    // MARK: Finish Selection

    private func finishSelection() {

        isSelecting =
            false

        onSelectionEnded?()

        let completedPoints =
            points

        print(
            "Points collected:",
            completedPoints.count
        )

        // ---------------------------------------------
        // Simple click / very small movement
        // ---------------------------------------------

        guard
            completedPoints.count >= 20
        else {

            print(
                "Selection cancelled: not enough points"
            )

            points.removeAll()

            onSelectionCancelled?()

            return
        }

        // ---------------------------------------------
        // Dragged something, but it wasn't a circle
        // ---------------------------------------------

        guard
            CircleDetector.isCircle(
                points:
                    completedPoints
            )
        else {

            print(
                "Selection cancelled: not a circle"
            )

            points.removeAll()

            onSelectionCancelled?()

            return
        }

        // ---------------------------------------------
        // Valid circle
        // ---------------------------------------------

        print(
            "Circle detected!"
        )

        onSelectionComplete?(
            completedPoints
        )
    }

    // MARK: Stop

    func stop() {

        if let mouseMoveMonitor {

            NSEvent.removeMonitor(
                mouseMoveMonitor
            )

            self.mouseMoveMonitor =
                nil
        }

        if let mouseUpMonitor {

            NSEvent.removeMonitor(
                mouseUpMonitor
            )

            self.mouseUpMonitor =
                nil
        }

        isSelecting =
            false

        points.removeAll()
    }

    // MARK: Clear

    func clear() {

        points.removeAll()

        isSelecting =
            false
    }

    // MARK: Deinit

    deinit {

        stop()
    }
}
