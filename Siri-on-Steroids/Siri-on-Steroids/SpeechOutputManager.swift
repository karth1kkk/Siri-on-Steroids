//
//  SpeechOutputManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AVFoundation

final class SpeechOutputManager: NSObject {

    // Keep all speech-engine operations on their own queue.
    private let speechQueue =
        DispatchQueue(
            label: "com.siri-on-steroids.speech",
            qos: .utility
        )

    private let synthesizer =
        AVSpeechSynthesizer()

    private var completionHandler:
        (() -> Void)?

    private var speechGeneration =
        0

    override init() {

        super.init()

        synthesizer.delegate =
            self
    }

    // MARK: Speak

    func speak(
        _ text: String,
        completion:
            (() -> Void)? = nil
    ) {

        let cleanedText =
            cleanTextForSpeech(
                text
            )

        guard !cleanedText.isEmpty else {

            DispatchQueue.main.async {
                completion?()
            }

            return
        }

        speechQueue.async { [weak self] in

            guard let self else {
                return
            }

            self.speechGeneration += 1

            let generation =
                self.speechGeneration

            // If another utterance is already
            // speaking, cancel it first.
            if self.synthesizer.isSpeaking {

                self.completionHandler =
                    nil

                self.synthesizer.stopSpeaking(
                    at: .immediate
                )
            }

            self.completionHandler =
                completion

            let utterance =
                AVSpeechUtterance(
                    string:
                        cleanedText
                )

            // Natural conversational speed.
            utterance.rate =
                0.48

            utterance.pitchMultiplier =
                1.0

            utterance.volume =
                1.0

            // Prefer Alex.
            if let alex =
                AVSpeechSynthesisVoice(
                    identifier:
                        "com.apple.speech.voice.Alex"
                ) {

                utterance.voice =
                    alex

            } else {

                utterance.voice =
                    AVSpeechSynthesisVoice(
                        language:
                            "en-US"
                    )
            }

            print(
                "TTS:",
                cleanedText
            )

            print(
                "TTS VOICE:",
                utterance.voice?.name
                    ?? "Unknown"
            )

            self.synthesizer.speak(
                utterance
            )

            // Keep the generation referenced so
            // the operation has a stable identity.
            _ = generation
        }
    }

    // MARK: Stop

    func stop() {

        speechQueue.async { [weak self] in

            guard let self else {
                return
            }

            self.speechGeneration += 1

            self.completionHandler =
                nil

            if self.synthesizer.isSpeaking {

                self.synthesizer.stopSpeaking(
                    at: .immediate
                )
            }
        }
    }

    // MARK: Clean Text

    private func cleanTextForSpeech(
        _ text: String
    ) -> String {

        var result = ""

        for scalar in text.unicodeScalars {

            let value =
                scalar.value

            // Emoji / pictographic Unicode ranges.
            let isEmoji =
                (
                    value >= 0x1F300 &&
                    value <= 0x1FAFF
                )
                ||
                (
                    value >= 0x2600 &&
                    value <= 0x27BF
                )
                ||
                (
                    value >= 0x2300 &&
                    value <= 0x23FF
                )
                ||
                (
                    value >= 0x2B50 &&
                    value <= 0x2B55
                )

            if !isEmoji {

                result.append(
                    Character(
                        scalar
                    )
                )
            }
        }

        // Remove zero-width joiner.
        result =
            result.replacingOccurrences(
                of:
                    "\u{200D}",
                with:
                    ""
            )

        // Remove variation selectors.
        result =
            result.replacingOccurrences(
                of:
                    "\u{FE0F}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE00}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE01}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE02}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE03}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE04}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE05}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE06}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE07}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE08}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE09}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE0A}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE0B}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE0C}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE0D}",
                with:
                    ""
            )

        result =
            result.replacingOccurrences(
                of:
                    "\u{FE0E}",
                with:
                    ""
            )

        // Collapse repeated whitespace.
        result =
            result.replacingOccurrences(
                of:
                    "\\s+",
                with:
                    " ",
                options:
                    .regularExpression
            )

        return result.trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechOutputManager:
    AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer:
            AVSpeechSynthesizer,
        didFinish utterance:
            AVSpeechUtterance
    ) {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            let completion =
                self.completionHandler

            self.completionHandler =
                nil

            completion?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer:
            AVSpeechSynthesizer,
        didCancel utterance:
            AVSpeechUtterance
    ) {

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

            // Cancellation must not cause
            // OverlayManager to automatically
            // start listening again.
            self.completionHandler =
                nil
        }
    }
}
