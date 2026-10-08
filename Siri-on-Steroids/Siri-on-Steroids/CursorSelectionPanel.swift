//
//  CursorSelectionPanel.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit
import SwiftUI

final class CursorSelectionPanel {

    private var panel: NSPanel?

    private var selectionManager:
        CursorSelectionManager?

    private var screenFrame:
        CGRect?

    func show(
        selectionManager: CursorSelectionManager,
        selectionRect: CGRect? = nil
    ) {

        guard let screen = NSScreen.main else {
            return
        }

        let screenFrame = screen.frame

        self.selectionManager =
            selectionManager

        self.screenFrame =
            screenFrame

        let view = CursorSelectionView(
            selectionManager: selectionManager,
            screenFrame: screenFrame,
            selectionRect: selectionRect
        )

        let hostingView = NSHostingView(
            rootView: view
        )

        let newPanel = NSPanel(
            contentRect: screenFrame,
            styleMask: [
                .borderless,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        newPanel.contentView =
            hostingView

        newPanel.backgroundColor =
            .clear

        newPanel.isOpaque =
            false

        newPanel.level =
            .floating

        newPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        newPanel.ignoresMouseEvents =
            true

        newPanel.hasShadow =
            false

        panel =
            newPanel

        newPanel.orderFrontRegardless()
    }

    func updateSelectionRect(
        _ selectionRect: CGRect
    ) {

        guard
            let selectionManager,
            let screenFrame
        else {
            return
        }

        let view = CursorSelectionView(
            selectionManager: selectionManager,
            screenFrame: screenFrame,
            selectionRect: selectionRect
        )

        let hostingView =
            NSHostingView(
                rootView: view
            )

        panel?.contentView =
            hostingView
    }

    func hide() {

        panel?.orderOut(nil)
    }
}
