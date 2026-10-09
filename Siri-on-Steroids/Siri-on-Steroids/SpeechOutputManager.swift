//
//  SpeechOutputManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//


import AVFoundation
import Foundation

final class SpeechOutputManager: NSObject, AVAudioPlayerDelegate {

    private let speechQueue = DispatchQueue(
        label: "com.siri-on-steroids.speech",
        qos: .userInitiated
    )

    private let baseURL = URL(
        string: "http://127.0.0.1:17493"
    )!

    private let profileID =
        "c45bdce5-683e-4c7e-9f54-4aad8b2bc1a1"

    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    private var speechGeneration = 0

    private let session = URLSession.shared

    private struct SpeakResponse: Decodable {
        let id: String
        let status: String
    }

    private struct GenerationStatus: Decodable {
        let id: String
        let status: String
        let error: String?
    }

    override init() {
        super.init()
    }

    // MARK: - Speak

    func speak(
        _ text: String,
        completion: (() -> Void)? = nil
    ) {
        let cleanedText = cleanTextForSpeech(text)

        guard !cleanedText.isEmpty else {
            DispatchQueue.main.async {
                completion?()
            }
            return
        }

        speechQueue.async { [weak self] in
            guard let self else { return }

            self.speechGeneration += 1
            let generation = self.speechGeneration

            self.audioPlayer?.stop()
            self.audioPlayer = nil
            self.completionHandler = completion

            self.requestSpeech(
                cleanedText,
                generation: generation
            )
        }
    }

    // MARK: - Request Voicebox Speech

    private func requestSpeech(
        _ text: String,
        generation: Int
    ) {
        guard generation == speechGeneration else { return }

        let url = baseURL.appendingPathComponent("speak")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "text": text,
            "profile": profileID,
            "engine": "kokoro",
            "personality": false,
            "language": "en"
        ]

        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: body
            )
        } catch {
            finishWithError(
                "Could not encode Voicebox request: \(error)",
                generation: generation
            )
            return
        }

        print("Voicebox request:", text)

        session.dataTask(with: request) {
            [weak self] data, response, error in

            guard let self else { return }

            self.speechQueue.async {
                guard generation == self.speechGeneration else {
                    return
                }

                if let error {
                    self.finishWithError(
                        "Voicebox request failed: \(error)",
                        generation: generation
                    )
                    return
                }

                guard
                    let httpResponse = response as? HTTPURLResponse,
                    let data
                else {
                    self.finishWithError(
                        "Voicebox returned no response.",
                        generation: generation
                    )
                    return
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let responseText = String(
                        data: data,
                        encoding: .utf8
                    ) ?? ""

                    self.finishWithError(
                        "Voicebox HTTP \(httpResponse.statusCode): \(responseText)",
                        generation: generation
                    )
                    return
                }

                do {
                    let result = try JSONDecoder().decode(
                        SpeakResponse.self,
                        from: data
                    )

                    print("Voicebox generation:", result.id)

                    self.pollGeneration(
                        id: result.id,
                        attemptsRemaining: 120,
                        generation: generation
                    )
                } catch {
                    self.finishWithError(
                        "Could not read Voicebox response: \(error)",
                        generation: generation
                    )
                }
            }
        }.resume()
    }

    // MARK: - Wait for Audio Generation

    private func pollGeneration(
        id: String,
        attemptsRemaining: Int,
        generation: Int
    ) {
        guard generation == speechGeneration else { return }

        guard attemptsRemaining > 0 else {
            finishWithError(
                "Voicebox audio generation timed out.",
                generation: generation
            )
            return
        }

        let url = baseURL
            .appendingPathComponent("generate")
            .appendingPathComponent(id)
            .appendingPathComponent("status")

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        session.dataTask(with: request) {
            [weak self] data, response, error in

            guard let self else { return }

            self.speechQueue.async {
                guard generation == self.speechGeneration else {
                    return
                }

                if let error {
                    self.finishWithError(
                        "Could not check Voicebox status: \(error)",
                        generation: generation
                    )
                    return
                }

                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode),
                    let data,
                    let responseText = String(
                        data: data,
                        encoding: .utf8
                    )
                else {
                    self.finishWithError(
                        "Invalid Voicebox status response.",
                        generation: generation
                    )
                    return
                }

                // Voicebox may return Server-Sent Events:
                // data: {"id":"...","status":"completed",...}
                let jsonLine = responseText
                    .components(separatedBy: "\n")
                    .first {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).hasPrefix("data:")
                    }

                guard let jsonLine else {
                    self.retryPolling(
                        id: id,
                        attemptsRemaining: attemptsRemaining,
                        generation: generation
                    )
                    return
                }

                let json = String(
                    jsonLine.drop(
                        while: { $0 != "{" }
                    )
                )

                guard let statusData = json.data(using: .utf8) else {
                    self.finishWithError(
                        "Could not decode Voicebox status.",
                        generation: generation
                    )
                    return
                }

                do {
                    let status = try JSONDecoder().decode(
                        GenerationStatus.self,
                        from: statusData
                    )

                    switch status.status.lowercased() {
                    case "completed":
                        self.downloadAudio(
                            id: id,
                            generation: generation
                        )

                    case "failed", "error":
                        self.finishWithError(
                            status.error ?? "Voicebox generation failed.",
                            generation: generation
                        )

                    default:
                        self.retryPolling(
                            id: id,
                            attemptsRemaining: attemptsRemaining,
                            generation: generation
                        )
                    }
                } catch {
                    self.finishWithError(
                        "Could not decode generation status: \(error)",
                        generation: generation
                    )
                }
            }
        }.resume()
    }

    private func retryPolling(
        id: String,
        attemptsRemaining: Int,
        generation: Int
    ) {
        speechQueue.asyncAfter(deadline: .now() + 0.5) {
            [weak self] in

            guard let self else { return }

            self.pollGeneration(
                id: id,
                attemptsRemaining: attemptsRemaining - 1,
                generation: generation
            )
        }
    }

    // MARK: - Download and Play Audio

    private func downloadAudio(
        id: String,
        generation: Int
    ) {
        guard generation == speechGeneration else { return }

        let url = baseURL
            .appendingPathComponent("audio")
            .appendingPathComponent(id)

        session.dataTask(with: url) {
            [weak self] data, response, error in

            guard let self else { return }

            self.speechQueue.async {
                guard generation == self.speechGeneration else {
                    return
                }

                if let error {
                    self.finishWithError(
                        "Could not download Voicebox audio: \(error)",
                        generation: generation
                    )
                    return
                }

                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode),
                    let data,
                    !data.isEmpty
                else {
                    self.finishWithError(
                        "Voicebox returned no playable audio.",
                        generation: generation
                    )
                    return
                }

                do {
                    let player = try AVAudioPlayer(data: data)
                    player.delegate = self

                    guard player.prepareToPlay(), player.play() else {
                        self.finishWithError(
                            "macOS could not play the Voicebox audio.",
                            generation: generation
                        )
                        return
                    }

                    self.audioPlayer = player
                    print("Playing Bella's voice.")
                } catch {
                    self.finishWithError(
                        "Could not initialize audio playback: \(error)",
                        generation: generation
                    )
                }
            }
        }.resume()
    }

    // MARK: - Stop

    func stop() {
        speechQueue.async { [weak self] in
            guard let self else { return }

            self.speechGeneration += 1
            self.completionHandler = nil

            self.audioPlayer?.stop()
            self.audioPlayer = nil

            print("Voicebox playback stopped.")
        }
    }

    // MARK: - Playback Completion

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        speechQueue.async { [weak self] in
            guard let self else { return }

            self.audioPlayer = nil

            let completion = self.completionHandler
            self.completionHandler = nil

            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    // MARK: - Error Handling

    private func finishWithError(
        _ message: String,
        generation: Int
    ) {
        guard generation == speechGeneration else { return }

        print("Speech error:", message)

        // Avoid automatically restarting the listening loop on error.
        completionHandler = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Clean Text

    private func cleanTextForSpeech(_ text: String) -> String {
        var result = ""

        for scalar in text.unicodeScalars {
            let value = scalar.value

            let isEmoji =
                (value >= 0x1F300 && value <= 0x1FAFF)
                || (value >= 0x2600 && value <= 0x27BF)
                || (value >= 0x2300 && value <= 0x23FF)
                || (value >= 0x2B50 && value <= 0x2B55)

            if !isEmoji {
                result.append(Character(scalar))
            }
        }

        result = result.replacingOccurrences(
            of: "\u{200D}",
            with: ""
        )

        result = result.replacingOccurrences(
            of: "\u{FE00}-[\u{FE0F}]",
            with: "",
            options: .regularExpression
        )

        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return result.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}
