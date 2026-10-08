//
//  SpeechManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import Foundation
import AVFoundation
import Speech

final class SpeechManager {

    private let audioEngine =
        AVAudioEngine()

    private let speechRecognizer =
        SFSpeechRecognizer(
            locale:
                Locale(
                    identifier:
                        "en-US"
                )
        )

    private var recognitionRequest:
        SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask:
        SFSpeechRecognitionTask?

    private var isTapInstalled =
        false

    private var isStopping =
        false

    // ------------------------------------------------
    // Automatic silence detection
    // ------------------------------------------------

    private var silenceTask:
        Task<Void, Never>?

    private var hasDetectedSpeech =
        false

    private var latestTranscription =
        ""

    private let silenceDuration:
        UInt64 = 5_000_000_000

    // ------------------------------------------------
    // Callbacks
    // ------------------------------------------------

    var onTranscriptionUpdate:
        ((String) -> Void)?

    var onTranscriptionComplete:
        ((String) -> Void)?

    var onAudioLevelUpdate:
        ((Float) -> Void)?

    // MARK: Permission

    func requestPermission(
        completion:
            @escaping (Bool) -> Void
    ) {

        SFSpeechRecognizer
            .requestAuthorization {
                speechStatus in

                guard
                    speechStatus ==
                        .authorized
                else {

                    DispatchQueue.main.async {
                        completion(false)
                    }

                    return
                }

                AVCaptureDevice
                    .requestAccess(
                        for: .audio
                    ) {
                        microphoneGranted in

                        DispatchQueue.main.async {
                            completion(
                                microphoneGranted
                            )
                        }
                    }
            }
    }

    // MARK: Start

    func start() {

        guard
            let speechRecognizer,
            speechRecognizer.isAvailable
        else {

            print(
                "SPEECH ERROR - recognizer unavailable"
            )

            return
        }

        guard
            !audioEngine.isRunning
        else {

            print(
                "SPEECH - audio engine already running"
            )

            return
        }

        print(
            "SPEECH TEST 1 - start() called"
        )

        isStopping =
            false

        silenceTask?.cancel()
        silenceTask =
            nil

        hasDetectedSpeech =
            false

        latestTranscription =
            ""

        recognitionTask?.cancel()
        recognitionTask =
            nil

        let request =
            SFSpeechAudioBufferRecognitionRequest()

        request.shouldReportPartialResults =
            true

        recognitionRequest =
            request

        let inputNode =
            audioEngine.inputNode

        let inputFormat =
            inputNode.outputFormat(
                forBus: 0
            )

        print(
            "SPEECH TEST 2 - input format:",
            inputFormat
        )

        guard
            inputFormat.sampleRate > 0
        else {

            print(
                "SPEECH ERROR - invalid microphone format"
            )

            return
        }

        if !isTapInstalled {

            inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: inputFormat
            ) {
                [weak self]
                buffer,
                _ in

                guard let self else {
                    return
                }

                guard
                    let request =
                        self.recognitionRequest
                else {
                    return
                }

                request.append(
                    buffer
                )

                let level =
                    self.calculateAudioLevel(
                        buffer:
                            buffer
                    )

                DispatchQueue.main.async {

                    self.onAudioLevelUpdate?(
                        level
                    )
                }

                // -----------------------------------------
                // Voice activity detection
                // -----------------------------------------

                if level > 0.08 {

                    self.hasDetectedSpeech =
                        true

                    self.restartSilenceTimer()
                }
            }

            isTapInstalled =
                true

            print(
                "SPEECH TEST 3 - microphone tap installed"
            )
        }

        recognitionTask =
            speechRecognizer.recognitionTask(
                with:
                    request
            ) {
                [weak self]
                result,
                error in

                guard let self else {
                    return
                }

                if let result {

                    let text =
                        result
                            .bestTranscription
                            .formattedString

                    guard
                        !text.isEmpty
                    else {
                        return
                    }

                    self.latestTranscription =
                        text

                    print(
                        "SPEECH TEXT:",
                        text
                    )

                    DispatchQueue.main.async {

                        self.onTranscriptionUpdate?(
                            text
                        )
                    }

                    // ------------------------------------------------
                    // Speech recognizer may decide that an utterance
                    // is final before the user actually wants the
                    // session to end.
                    //
                    // We therefore do NOT automatically call
                    // onTranscriptionComplete here.
                    //
                    // The silence timer handles automatic listening.
                    // ------------------------------------------------

                    if result.isFinal {

                        print(
                            "SPEECH - FINAL RESULT:",
                            text
                        )
                    }
                }

                if let error {

                    if self.isStopping {

                        print(
                            "SPEECH - recognition finished after stopping:",
                            error.localizedDescription
                        )

                    } else {

                        print(
                            "SPEECH RECOGNITION ERROR:",
                            error
                        )
                    }
                }
            }

        audioEngine.prepare()

        do {

            try audioEngine.start()

            print(
                "SPEECH TEST 4 - AUDIO ENGINE STARTED"
            )

        } catch {

            print(
                "SPEECH ERROR - audio engine failed:",
                error
            )

            stopImmediately()
        }
    }

    // MARK: Stop

    func stop(
        completion:
            (() -> Void)? = nil
    ) {

        guard
            !isStopping
        else {

            completion?()

            return
        }

        isStopping =
            true

        silenceTask?.cancel()
        silenceTask =
            nil

        print(
            "SPEECH - stopping"
        )

        audioEngine.stop()

        if isTapInstalled {

            audioEngine.inputNode.removeTap(
                onBus: 0
            )

            isTapInstalled =
                false

            print(
                "SPEECH - microphone tap removed"
            )
        }

        recognitionRequest?.endAudio()

        print(
            "SPEECH - waiting for final recognition result"
        )

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.5
        ) {
            [weak self] in

            guard let self else {
                return
            }

            let finalText =
                self.latestTranscription
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !finalText.isEmpty {

                print(
                    "SPEECH - FINAL TRANSCRIPTION:",
                    finalText
                )

                self.onTranscriptionComplete?(
                    finalText
                )
            }

            self.recognitionRequest =
                nil

            self.recognitionTask?.cancel()
            self.recognitionTask =
                nil

            self.isStopping =
                false

            self.hasDetectedSpeech =
                false

            self.latestTranscription =
                ""

            self.onAudioLevelUpdate?(
                0
            )

            print(
                "SPEECH - stopped"
            )

            completion?()
        }
    }

    // MARK: Silence Detection

    private func restartSilenceTimer() {

        silenceTask?.cancel()

        silenceTask =
            Task { [weak self] in

                guard let self else {
                    return
                }

                do {

                    try await Task.sleep(
                        nanoseconds:
                            self.silenceDuration
                    )

                } catch {

                    return
                }

                guard
                    !Task.isCancelled
                else {
                    return
                }

                guard
                    self.hasDetectedSpeech
                else {
                    return
                }

                guard
                    !self.isStopping
                else {
                    return
                }

                let finalText =
                    self.latestTranscription
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )

                guard
                    !finalText.isEmpty
                else {
                    return
                }

                print(
                    "SPEECH - 5 seconds of silence detected"
                )

                print(
                    "SPEECH - automatic final result:",
                    finalText
                )

                // Stop the microphone first.
                self.stop()

            }
    }

    // MARK: Audio Level

    private func calculateAudioLevel(
        buffer:
            AVAudioPCMBuffer
    ) -> Float {

        guard
            let channelData =
                buffer.floatChannelData?[0]
        else {
            return 0
        }

        let frameLength =
            Int(
                buffer.frameLength
            )

        guard
            frameLength > 0
        else {
            return 0
        }

        var sum:
            Float = 0

        for index in
            0..<frameLength {

            let sample =
                channelData[index]

            sum +=
                sample *
                sample
        }

        let rms =
            sqrt(
                sum /
                Float(
                    frameLength
                )
            )

        let normalized =
            min(
                max(
                    rms * 8,
                    0
                ),
                1
            )

        return normalized
    }

    // MARK: Immediate Stop

    private func stopImmediately() {

        silenceTask?.cancel()
        silenceTask =
            nil

        audioEngine.stop()

        if isTapInstalled {

            audioEngine.inputNode.removeTap(
                onBus: 0
            )

            isTapInstalled =
                false
        }

        recognitionRequest?.endAudio()

        recognitionTask?.cancel()

        recognitionRequest =
            nil

        recognitionTask =
            nil

        isStopping =
            false

        hasDetectedSpeech =
            false

        latestTranscription =
            ""

        onAudioLevelUpdate?(
            0
        )
    }

    deinit {

        silenceTask?.cancel()

        audioEngine.stop()

        if isTapInstalled {

            audioEngine.inputNode.removeTap(
                onBus: 0
            )
        }

        recognitionTask?.cancel()
    }
}
