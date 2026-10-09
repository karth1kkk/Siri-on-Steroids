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

    var onSelectionComplete: (([CGPoint]) -> Void)?
    var onSelectionStarted: (() -> Void)?
    var onSelectionEnded: (() -> Void)?
    var onSelectionCancelled: (() -> Void)?

    private var mouseMoveMonitor: Any?

    // Start tracking cursor movement when the shortcut is pressed.
    func start(at initialPosition: CGPoint? = nil) {

        guard mouseMoveMonitor == nil else {
            return
        }

        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) { [weak self] _ in

            guard let self, self.isSelecting else {
                return
            }

            let position = NSEvent.mouseLocation

            DispatchQueue.main.async {
                guard self.isSelecting else { return }
                self.points.append(position)
            }
        }

        guard let initialPosition else {
            return
        }

        points.removeAll()
        points.append(initialPosition)
        isSelecting = true

        onSelectionStarted?()

        print("Cursor gesture started:", initialPosition)
    }

    // Called when Control + Option is released.
    func finishSelection() {

        guard isSelecting else {
            return
        }

        isSelecting = false
        onSelectionEnded?()

        let completedPoints = points

        print("Cursor points collected:", completedPoints.count)

        guard completedPoints.count >= 20 else {
            cancelSelection()
            return
        }

        guard CircleDetector.isCircle(points: completedPoints) else {
            print("Cursor gesture was not a circle")
            cancelSelection()
            return
        }

        print("Circle detected!")

        onSelectionComplete?(completedPoints)
    }

    private func cancelSelection() {
        points.removeAll()
        onSelectionCancelled?()
    }

    func stop() {

        if let mouseMoveMonitor {
            NSEvent.removeMonitor(mouseMoveMonitor)
            self.mouseMoveMonitor = nil
        }

        isSelecting = false
        points.removeAll()
    }

    func clear() {
        points.removeAll()
        isSelecting = false
    }

    deinit {
        stop()
    }
}
