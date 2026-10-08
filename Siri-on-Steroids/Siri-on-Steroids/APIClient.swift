//
//  APIClient.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import Foundation

final class APIClient {

    private let baseURL =
        URL(string: "http://127.0.0.1:8000")!

    func send(
        request: AssistantRequest,
        completion: @escaping (
            Result<AssistantResponse, Error>
        ) -> Void
    ) {

        guard let url =
                URL(
                    string: "/assistant",
                    relativeTo: baseURL
                )
        else {
            return
        }

        var urlRequest =
            URLRequest(
                url: url
            )

        urlRequest.httpMethod = "POST"

        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        // Convert screenshot to Base64
        let imageBase64 =
            request.screenshotData?
                .base64EncodedString()

        // Build JSON payload
        let payload: [String: Any] = [

            "text": request.text,

            "image": imageBase64 as Any
        ]

        print("API - preparing payload")

        do {

            let jsonData =
                try JSONSerialization.data(
                    withJSONObject: payload
                )

            urlRequest.httpBody =
                jsonData

            print(
                "API - payload size:",
                jsonData.count,
                "bytes"
            )

        } catch {

            print(
                "API JSON ENCODING ERROR:",
                error
            )

            completion(
                .failure(error)
            )

            return
        }

        print("API - sending request")

        URLSession.shared.dataTask(
            with: urlRequest
        ) { data, response, error in

            if let error {

                print(
                    "API ERROR:",
                    error
                )

                DispatchQueue.main.async {

                    completion(
                        .failure(error)
                    )
                }

                return
            }

            guard let httpResponse =
                    response as? HTTPURLResponse
            else {

                print(
                    "API ERROR - invalid response"
                )

                return
            }

            print(
                "API STATUS:",
                httpResponse.statusCode
            )

            guard let data else {

                print(
                    "API ERROR - no response data"
                )

                return
            }

            print(
                "API RESPONSE:",
                String(
                    data: data,
                    encoding: .utf8
                ) ?? "Invalid UTF-8"
            )

            do {

                let decoded =
                    try JSONDecoder().decode(
                        AssistantResponse.self,
                        from: data
                    )

                DispatchQueue.main.async {

                    completion(
                        .success(decoded)
                    )
                }

            } catch {

                print(
                    "API DECODING ERROR:",
                    error
                )

                DispatchQueue.main.async {

                    completion(
                        .failure(error)
                    )
                }
            }

        }.resume()
    }
}
