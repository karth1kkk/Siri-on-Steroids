//
//  Untitled.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit

@MainActor
final class AppController {

    let overlayManager:
        OverlayManager

    let shortcutManager:
        GlobalShortcutManager

    init() {

        overlayManager =
            OverlayManager()

        shortcutManager =
            GlobalShortcutManager()

        shortcutManager.onShortcutDown = {
            [weak self] in

            guard let self else {
                return
            }

            self.overlayManager.startListening()
        }

        shortcutManager.onShortcutUp = {
            [weak self] in

            guard let self else {
                return
            }

            self.overlayManager.stopListening()
        }

        shortcutManager.start()
    }

    func quit() {

        shortcutManager.stop()

        overlayManager.stop()

        NSApplication.shared.terminate(
            nil
        )
    }
}
