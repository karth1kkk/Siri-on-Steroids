//
//  AssistantOverlay.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import SwiftUI

struct AssistantOverlay: View {

    let state: AssistantState
    let text: String
    let audioLevel: Float
    let hasImage: Bool

    let onStop: () -> Void

    @State private var appeared = false
    @State private var glowPulse = false

    private var shouldShowStopButton: Bool {

        state == .analyzing ||
        state == .responding
    }

    private var isAnalyzing: Bool {

        state == .analyzing
    }

    var body: some View {

        HStack(
            alignment: .center,
            spacing: 14
        ) {

            // MARK: Waveform

            ZStack {

                // MARK: Pulsing outer glow

                if isAnalyzing {

                    Circle()
                        .fill(
                            .white.opacity(
                                glowPulse
                                ? 0.16
                                : 0.06
                            )
                        )
                        .frame(
                            width:
                                glowPulse
                                ? 72
                                : 56,

                            height:
                                glowPulse
                                ? 72
                                : 56
                        )
                        .blur(
                            radius:
                                glowPulse
                                ? 16
                                : 9
                        )
                        .opacity(
                            glowPulse
                            ? 1.0
                            : 0.65
                        )

                    Circle()
                        .stroke(
                            .white.opacity(
                                glowPulse
                                ? 0.38
                                : 0.16
                            ),
                            lineWidth:
                                glowPulse
                                ? 2
                                : 1
                        )
                        .frame(
                            width:
                                glowPulse
                                ? 55
                                : 49,

                            height:
                                glowPulse
                                ? 55
                                : 49
                        )
                        .blur(
                            radius:
                                glowPulse
                                ? 3
                                : 1
                        )
                }

                // MARK: Main circle

                Circle()
                    .fill(
                        .black.opacity(0.88)
                    )
                    .overlay {

                        Circle()
                            .stroke(
                                .white.opacity(0.20),
                                lineWidth: 1
                            )
                    }
                    .frame(
                        width: 42,
                        height: 42
                    )
                    .shadow(
                        color:
                            isAnalyzing
                            ? .black.opacity(0.25)
                            : .clear,
                        radius:
                            isAnalyzing
                            ? 8
                            : 0
                    )

                AssistantWaveform(
                    audioLevel:
                        audioLevel,

                    isActive:
                        state == .listening ||
                        state == .responding
                )
            }
            .frame(
                width: 72,
                height: 72
            )

            // MARK: Text

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(statusText)
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )

                if !text.isEmpty {

                    Text(text)
                        .font(
                            .system(
                                size: 13
                            )
                        )
                        .foregroundStyle(
                            .primary.opacity(0.92)
                        )
                        .lineLimit(4)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .transition(
                            .opacity
                                .combined(
                                    with:
                                        .move(
                                            edge: .bottom
                                        )
                                )
                        )
                }

                if hasImage {

                    HStack(spacing: 5) {

                        Image(
                            systemName:
                                "photo"
                        )

                        Text(
                            "Screen content attached"
                        )
                    }
                    .font(
                        .system(
                            size: 11
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                if text.isEmpty &&
                    !hasImage &&
                    state == .listening {

                    Text(
                        "Speak naturally..."
                    )
                    .font(
                        .system(
                            size: 12
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            // MARK: Stop Button

            if shouldShowStopButton {

                Spacer(
                    minLength: 6
                )

                Button {

                    onStop()

                } label: {

                    Image(
                        systemName:
                            "stop.fill"
                    )
                    .font(
                        .system(
                            size: 10,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .frame(
                        width: 30,
                        height: 30
                    )
                    .background {

                        Circle()
                            .fill(
                                .primary.opacity(
                                    0.10
                                )
                            )
                            .background {

                                Circle()
                                    .fill(
                                        .ultraThinMaterial
                                    )
                            }
                            .clipShape(
                                Circle()
                            )
                    }
                    .overlay {

                        Circle()
                            .stroke(
                                .white.opacity(
                                    0.15
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .help("Stop")
                .transition(
                    .scale
                        .combined(
                            with: .opacity
                        )
                )
            }
        }

        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            10
        )

        .frame(
            minWidth: 300,
            maxWidth: 650,
            alignment: .leading
        )

        // MARK: Glass

        .background {

            if #available(macOS 26.0, *) {

                RoundedRectangle(
                    cornerRadius: 35,
                    style: .continuous
                )
                .fill(.clear)
                .glassEffect(
                    .regular,
                    in:
                        .rect(
                            cornerRadius: 35
                        )
                )

            } else {

                RoundedRectangle(
                    cornerRadius: 35,
                    style: .continuous
                )
                .fill(
                    .ultraThinMaterial
                )
            }
        }

        // Outer glass border

        .overlay {

            RoundedRectangle(
                cornerRadius: 35,
                style: .continuous
            )
            .stroke(
                .white.opacity(0.18),
                lineWidth: 1
            )
        }

        // MARK: Bubble appearance

        .scaleEffect(
            appeared ? 1.0 : 0.82
        )
        .opacity(
            appeared ? 1.0 : 0
        )
        .animation(
            .spring(
                response: 0.38,
                dampingFraction: 0.72
            ),
            value: appeared
        )

        .animation(
            .spring(
                response: 0.45,
                dampingFraction: 0.82
            ),
            value: text
        )

        .animation(
            .spring(
                response: 0.45,
                dampingFraction: 0.82
            ),
            value: stateName
        )

        .onAppear {

            appeared = true

            if isAnalyzing {

                startGlowAnimation()
            }
        }

        .onChange(
            of: isAnalyzing
        ) { _, analyzing in

            if analyzing {

                startGlowAnimation()

            } else {

                glowPulse = false
            }
        }
    }

    // MARK: Glow Animation

    private func startGlowAnimation() {

        glowPulse = false

        withAnimation(
            .easeInOut(
                duration: 1.05
            )
            .repeatForever(
                autoreverses: true
            )
        ) {

            glowPulse = true
        }
    }

    // MARK: Status

    private var statusText: String {

        switch state {

        case .listening:
            return "Listening"

        case .analyzing:
            return "Analyzing"

        case .responding:
            return "Assistant"

        case .idle:
            return "Ready"
        }
    }

    private var stateName: String {

        switch state {

        case .listening:
            return "listening"

        case .analyzing:
            return "analyzing"

        case .responding:
            return "responding"

        case .idle:
            return "idle"
        }
    }
}
