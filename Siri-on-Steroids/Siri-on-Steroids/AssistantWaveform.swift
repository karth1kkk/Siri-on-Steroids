//
//  AssistantWaveform.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import SwiftUI

struct AssistantWaveform: View {

    let audioLevel: Float
    let isActive: Bool

    private let barCount = 7

    var body: some View {

        HStack(
            alignment: .center,
            spacing: 2.5
        ) {

            ForEach(
                0..<barCount,
                id: \.self
            ) { index in

                RoundedRectangle(
                    cornerRadius: 1.5,
                    style: .continuous
                )
                .fill(.white)
                .frame(
                    width: 2.5,
                    height: barHeight(
                        index: index
                    )
                )
            }
        }
        .frame(
            width: 28,
            height: 22
        )
        .clipped()
        .animation(
            .easeOut(duration: 0.08),
            value: audioLevel
        )
    }

    private func barHeight(
        index: Int
    ) -> CGFloat {

        guard isActive else {
            return 4
        }

        let center =
            CGFloat(barCount - 1) / 2

        let distance =
            abs(
                CGFloat(index) - center
            )

        let multiplier =
            1 -
            (
                distance / center
            ) * 0.45

        let minimum: CGFloat = 4
        let maximum: CGFloat = 17

        let height =
            minimum +
            (
                maximum - minimum
            ) *
            CGFloat(audioLevel) *
            multiplier

        return min(
            max(height, minimum),
            maximum
        )
    }
}
