//
//  GlobalShortcutManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit

final class GlobalShortcutManager {

    private var monitor: Any?

    private var combinationActive =
        false

    var onShortcutDown:
        (() -> Void)?

    var onShortcutUp:
        (() -> Void)?

    func start() {

        guard monitor == nil else {
            return
        }

        monitor =
            NSEvent.addGlobalMonitorForEvents(
                matching: .flagsChanged
            ) { [weak self] event in

                guard let self else {
                    return
                }

                let flags =
                    event.modifierFlags

                let controlPressed =
                    flags.contains(.control)

                let optionPressed =
                    flags.contains(.option)

                let bothPressed =
                    controlPressed &&
                    optionPressed

                if bothPressed &&
                    !self.combinationActive {

                    self.combinationActive =
                        true

                    DispatchQueue.main.async {
                        self.onShortcutDown?()
                    }
                }

                if !bothPressed &&
                    self.combinationActive {

                    self.combinationActive =
                        false

                    DispatchQueue.main.async {
                        self.onShortcutUp?()
                    }
                }
            }
    }

    func stop() {

        if let monitor {

            NSEvent.removeMonitor(
                monitor
            )

            self.monitor =
                nil
        }

        combinationActive =
            false
    }

    deinit {

        stop()
    }
}
