//
//  ImageEncoder.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit

struct ImageEncoder {

    static func pngData(
        from image: NSImage
    ) -> Data? {

        guard
            let tiffData =
                image.tiffRepresentation
        else {
            return nil
        }

        guard
            let bitmapImage =
                NSBitmapImageRep(
                    data: tiffData
                )
        else {
            return nil
        }

        return bitmapImage.representation(
            using: .png,
            properties: [:]
        )
    }
}
