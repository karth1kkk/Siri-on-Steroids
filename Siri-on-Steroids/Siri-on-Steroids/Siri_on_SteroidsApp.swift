//
//  Siri_on_SteroidsApp.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import SwiftUI
import AppKit

@main
struct Siri_on_SteroidsApp: App {

    private let appController =
        AppController()

    var body: some Scene {

        MenuBarExtra(
            "Siri-on-Steroids",
            systemImage: "waveform"
        ) {

            Button("Show Assistant") {

                appController
                    .overlayManager
                    .show()
            }

            Button("Hide Assistant") {

                appController
                    .overlayManager
                    .hide()
            }

            Divider()

            Button("Agent Mode") {

                print(
                    "Agent mode selected"
                )
            }

            Button("Settings") {

                print(
                    "Settings selected"
                )
            }

            Divider()

            Button("Quit") {

                appController.quit()
            }
        }
        .menuBarExtraStyle(
            .menu
        )
    }
}
