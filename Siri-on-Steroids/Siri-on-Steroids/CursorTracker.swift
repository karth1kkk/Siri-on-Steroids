//
//  CursorTracker.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit
import Combine

final class CursorTracker: ObservableObject {

    @Published var position: CGPoint = .zero

    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) { [weak self] event in

            DispatchQueue.main.async {
                self?.position = NSEvent.mouseLocation
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        stop()
    }
}
