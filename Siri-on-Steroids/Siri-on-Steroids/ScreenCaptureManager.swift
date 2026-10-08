//
//  ScreenCaptureManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit
import ScreenCaptureKit

final class ScreenCaptureManager {

    func capture(
        region: CGRect,
        completion: @escaping (NSImage?) -> Void
    ) {

        Task {

            do {

                let content =
                    try await SCShareableContent
                        .excludingDesktopWindows(
                            false,
                            onScreenWindowsOnly: true
                        )

                guard let display =
                        findDisplay(
                            containing: region,
                            from: content.displays
                        )
                else {

                    print(
                        "Could not find display for region"
                    )

                    completion(nil)
                    return
                }

                let displayFrame =
                    CGRect(
                        x: CGFloat(display.frame.origin.x),
                        y: CGFloat(display.frame.origin.y),
                        width: CGFloat(display.width),
                        height: CGFloat(display.height)
                    )

                let localRegion =
                    CGRect(
                        x: region.minX -
                            displayFrame.minX,

                        y: region.minY -
                            displayFrame.minY,

                        width: region.width,

                        height: region.height
                    )

                let scaleFactor =
                    CGFloat(
                        display.width
                    ) /
                    displayFrame.width

                let configuration =
                    SCStreamConfiguration()

                configuration.width =
                    Int(
                        localRegion.width *
                        scaleFactor
                    )

                configuration.height =
                    Int(
                        localRegion.height *
                        scaleFactor
                    )

                configuration.sourceRect =
                    localRegion

                configuration.scalesToFit =
                    false

                configuration.showsCursor =
                    false

                let filter =
                    SCContentFilter(
                        display: display,
                        excludingWindows: []
                    )

                let image =
                    try await SCScreenshotManager
                        .captureImage(
                            contentFilter: filter,
                            configuration: configuration
                        )

                let nsImage =
                    NSImage(
                        cgImage: image,
                        size: NSSize(
                            width: image.width,
                            height: image.height
                        )
                    )

                DispatchQueue.main.async {
                    completion(nsImage)
                }

            } catch {

                print(
                    "Screen capture failed:",
                    error
                )

                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    private func findDisplay(
        containing region: CGRect,
        from displays: [SCDisplay]
    ) -> SCDisplay? {

        for display in displays {

            let displayFrame =
                CGRect(
                    x: CGFloat(
                        display.frame.origin.x
                    ),

                    y: CGFloat(
                        display.frame.origin.y
                    ),

                    width: CGFloat(
                        display.width
                    ),

                    height: CGFloat(
                        display.height
                    )
                )

            if displayFrame.intersects(region) {
                return display
            }
        }

        return nil
    }
}
