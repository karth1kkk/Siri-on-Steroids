
import SwiftUI
import AppKit

@main
struct Siri_on_SteroidsApp: App {

    private let appController = AppController()

    @State private var isAssistantVisible = false

    var body: some Scene {

        MenuBarExtra(
            "Siri-on-Steroids",
            systemImage: "waveform"
        ) {

            Button(isAssistantVisible ? "Hide Assistant" : "Show Assistant") {

                if isAssistantVisible {
                    appController.overlayManager.hide()
                } else {
                    appController.overlayManager.show()
                }

                isAssistantVisible.toggle()
            }

            Button("Settings") {
                print("Settings selected")
            }

            Divider()

            Button("Quit") {
                appController.quit()
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
