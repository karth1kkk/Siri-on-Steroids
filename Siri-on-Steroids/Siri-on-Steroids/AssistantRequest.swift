//
//  AssistantRequest.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit

struct AssistantRequest {

    let screenshot: NSImage?

    let text: String

    var screenshotData: Data? {

        guard let screenshot else {
            return nil
        }

        return ImageEncoder.pngData(
            from: screenshot
        )
    }
}
