//
//  OverlayManager.swift
//  Siri-on-Steroids
//
//  Created by Karthikeyan on 08/10/2026.
//

import AppKit
import SwiftUI

@MainActor
final class OverlayManager {

    private var panel: NSPanel?

    private var hostingView: NSHostingView<AssistantOverlay>?

    private var isAssistantVisible = false
    private var isAssistantActive = false

    private var assistantState: AssistantState = .idle
    private var assistantText = ""
    private var currentTranscription = ""

    private var audioLevel: Float = 0
    private var selectedImage: NSImage?

    private var isCaptureInProgress = false
    private var shouldSendRequest = false
    private var isProcessingRequest = false
    private var requestGeneration = 0

    private var didCompleteCursorSelection = false

    // MARK: Timing

    private let idleTimeout: UInt64 = 5_000_000_000
    private let requestDelay: UInt64 = 5_000_000_000

    private let quickTriggerThreshold: TimeInterval = 1.0

    private var assistantSessionStart: Date?

    private var idleHideTask: Task<Void, Never>?
    private var requestDelayTask: Task<Void, Never>?

    private var isAutomaticListening = false
    private var clickMonitor: Any?

    // MARK: Managers

    private let cursorSelectionManager = CursorSelectionManager()
    private let cursorSelectionPanel = CursorSelectionPanel()
    private let screenCaptureManager = ScreenCaptureManager()
    private let speechManager = SpeechManager()
    private let speechOutputManager = SpeechOutputManager()
    private let apiClient = APIClient()

    // MARK: Init

    init() {

        cursorSelectionManager.onSelectionComplete = {
            [weak self] points in

            guard let self else { return }

            print("ASSISTANT - cursor circle completed")

            self.didCompleteCursorSelection = true
            self.isAssistantActive = false
            self.assistantSessionStart = nil
            self.shouldSendRequest = true

            self.cancelIdleHide()
            self.cancelRequestDelay()

            // Stop voice recognition after the gesture.
            self.speechManager.stop()

            // Capture the region enclosed by the circle.
            self.analyzeSelection(points: points)
        }

        cursorSelectionManager.onSelectionStarted = {
            [weak self] in

            guard let self else { return }

            self.cancelIdleHide()
            self.cancelRequestDelay()

            print("SELECTION STARTED")
        }

        cursorSelectionManager.onSelectionEnded = {
            print("SELECTION ENDED")
        }

        cursorSelectionManager.onSelectionCancelled = {
            [weak self] in

            guard let self else { return }

            print("ASSISTANT - cursor gesture cancelled")

            // An invalid circle should not dismiss the assistant.
            // The normal voice interaction can continue.
            self.cursorSelectionPanel.hide()
        }

        speechManager.onTranscriptionUpdate = {
            [weak self] text in

            guard let self else { return }

            self.cancelIdleHide()

            self.currentTranscription = text
            self.assistantText = text
            self.assistantState = .listening

            self.updatePanel()

            print("CURRENT TRANSCRIPTION:", text)
        }

        speechManager.onTranscriptionComplete = {
            [weak self] text in

            guard let self else { return }

            self.cancelIdleHide()

            self.currentTranscription = text
            self.assistantText = text

            self.updatePanel()

            print("FINAL SPEECH RESULT:", text)

            if self.isAutomaticListening {
                self.scheduleAutomaticRequest()
            }
        }

        speechManager.onAudioLevelUpdate = {
            [weak self] level in

            guard let self else { return }

            self.audioLevel = level
            self.updatePanel()
        }

        createPanel()
        startClickMonitor()
    }

    // MARK: Initial Listening

    func startListening() {

        print("ASSISTANT - starting listening")

        didCompleteCursorSelection = false

        cancelIdleHide()
        cancelRequestDelay()

        assistantSessionStart = Date()

        isAutomaticListening = false
        isAssistantActive = true

        currentTranscription = ""
        assistantText = ""
        selectedImage = nil

        audioLevel = 0
        assistantState = .listening

        isCaptureInProgress = false
        shouldSendRequest = false
        isProcessingRequest = false

        requestGeneration += 1

        speechOutputManager.stop()

        show()
        updatePanel()

        // Start cursor tracking immediately.
        // No left mouse click is required.
        cursorSelectionManager.start(
            at: NSEvent.mouseLocation
        )

        speechManager.requestPermission {
            [weak self] granted in

            guard let self else { return }

            print("SPEECH PERMISSION:", granted)

            guard granted else {
                self.assistantText =
                    "Microphone permission is required."

                self.updatePanel()
                return
            }

            guard self.isAssistantActive else {
                print("ASSISTANT - session no longer active")
                return
            }

            self.speechManager.start()
            self.startIdleHideTimer()
        }
    }

    // MARK: Shortcut Released

    func stopListening() {

        print("ASSISTANT - stopping listening")

        // First, determine whether the cursor gesture
        // completed a valid circle.
        cursorSelectionManager.finishSelection()

        // A valid circle has already initiated screenshot
        // capture. Do not run the quick-trigger dismissal
        // or the ordinary voice-request flow.
        if didCompleteCursorSelection {
            print("ASSISTANT - processing cursor selection")
            return
        }

        let sessionDuration =
            assistantSessionStart.map {
                Date().timeIntervalSince($0)
            } ?? 0

        assistantSessionStart = nil

        let text =
            currentTranscription.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let hasImage = selectedImage != nil

        // QUICK TRIGGER
        //
        // A short shortcut press without speech or
        // a valid selection dismisses the assistant.

        if sessionDuration < quickTriggerThreshold &&
            text.isEmpty &&
            !hasImage {

            print("ASSISTANT - quick trigger with no content, hiding")

            isAssistantActive = false
            isAutomaticListening = false
            shouldSendRequest = false

            cancelIdleHide()
            cancelRequestDelay()

            speechManager.stop()
            cursorSelectionManager.stop()

            hide()
            return
        }

        // NORMAL VOICE INTERACTION

        isAssistantActive = false
        shouldSendRequest = true

        assistantState = .analyzing
        assistantText = text.isEmpty ? "Processing..." : text

        updatePanel()

        speechManager.stop {
            [weak self] in

            guard let self else { return }

            print(
                "FINAL TRANSCRIPTION:",
                self.currentTranscription
            )

            self.scheduleInitialRequest()
        }
    }

    // MARK: Initial Request Delay

    private func scheduleInitialRequest() {

        cancelRequestDelay()

        let generation = requestGeneration

        print("ASSISTANT - request scheduled in 5 seconds")

        requestDelayTask = Task { [weak self] in

            try? await Task.sleep(
                nanoseconds: 5_000_000_000
            )

            guard !Task.isCancelled else {
                print("ASSISTANT - request timer cancelled")
                return
            }

            await MainActor.run {

                guard let self else { return }

                guard generation == self.requestGeneration else {
                    print("ASSISTANT - request timer belongs to old generation")
                    return
                }

                print("ASSISTANT - 5 seconds elapsed, sending request")

                self.sendRequestWhenReady()
            }
        }
    }

    // MARK: Automatic Listening

    private func scheduleAutomaticRequest() {

        cancelRequestDelay()

        let generation = requestGeneration

        print("ASSISTANT - automatic request scheduled in 5 seconds")

        requestDelayTask = Task { [weak self] in

            try? await Task.sleep(
                nanoseconds: 5_000_000_000
            )

            guard !Task.isCancelled else {
                print("ASSISTANT - automatic request timer cancelled")
                return
            }

            await MainActor.run {

                guard let self else { return }

                guard generation == self.requestGeneration else {
                    print("ASSISTANT - automatic request belongs to old generation")
                    return
                }

                guard self.isAutomaticListening else {
                    print("ASSISTANT - automatic listening ended, request cancelled")
                    return
                }

                print("ASSISTANT - automatic 5 seconds elapsed, sending request")

                self.sendRequestWhenReady()
            }
        }
    }

    // MARK: Request

    private func sendRequestWhenReady() {

        cancelRequestDelay()

        print(
            """
            ASSISTANT - sendRequestWhenReady()
            shouldSendRequest: \(shouldSendRequest)
            captureInProgress: \(isCaptureInProgress)
            transcription: \(currentTranscription)
            hasImage: \(selectedImage != nil)
            """
        )

        guard shouldSendRequest else {
            print("ASSISTANT - NOT SENDING: shouldSendRequest is false")
            return
        }

        guard !isCaptureInProgress else {
            print("ASSISTANT - screenshot still capturing")
            return
        }

        let text =
            currentTranscription.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let image = selectedImage

        guard !text.isEmpty || image != nil else {

            print("ASSISTANT - nothing to process")

            shouldSendRequest = false
            assistantState = .idle
            assistantText = ""

            updatePanel()
            startIdleHideTimer()

            return
        }

        // Lock the request state before networking.
        shouldSendRequest = false
        isProcessingRequest = true

        assistantState = .analyzing

        assistantText = text.isEmpty
            ? "Analyzing selected content..."
            : text

        updatePanel()

        let request = AssistantRequest(
            screenshot: image,
            text: text
        )

        requestGeneration += 1

        let currentGeneration = requestGeneration

        print("ASSISTANT - sending request")
        print("Request text:", text)
        print("Request contains screenshot:", image != nil)

        apiClient.send(request: request) {
            [weak self] result in

            guard let self else { return }

            guard currentGeneration == self.requestGeneration else {
                print("ASSISTANT - ignoring cancelled response")
                return
            }

            switch result {

            case .success(let response):

                print("ASSISTANT RESPONSE:", response.response)

                self.showResponse(response.response)

            case .failure(let error):

                print("ASSISTANT API ERROR:", error)

                self.showResponse(
                    "Sorry, I couldn't process that request."
                )
            }
        }
    }

    // MARK: Selection

    private func analyzeSelection(points: [CGPoint]) {

        guard !points.isEmpty else {
            shouldSendRequest = false
            return
        }

        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0

        let selectionRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        print("Selection completed")
        print("Region:", selectionRect)

        cursorSelectionPanel.updateSelectionRect(selectionRect)

        print("Selection locked")

        assistantState = .analyzing

        assistantText = currentTranscription.isEmpty
            ? "Analyzing selected content..."
            : currentTranscription

        updatePanel()

        isCaptureInProgress = true

        screenCaptureManager.capture(region: selectionRect) {
            [weak self] image in

            guard let self else { return }

            self.isCaptureInProgress = false

            guard let image else {

                print("No screenshot captured")

                self.assistantText =
                    "I couldn't capture the selected area."

                self.updatePanel()

                self.cursorSelectionPanel.hide()
                self.sendRequestWhenReady()

                return
            }

            print("Screenshot captured!")
            print("Image size:", image.size)

            self.selectedImage = image

            print("Screenshot stored for assistant request")

            self.assistantText = self.currentTranscription.isEmpty
                ? "Selected screen content attached."
                : self.currentTranscription

            self.assistantState = .analyzing

            self.updatePanel()

            self.cursorSelectionPanel.hide()
            self.sendRequestWhenReady()
        }
    }

    // MARK: Response

    private func showResponse(_ response: String) {

        cancelIdleHide()
        cancelRequestDelay()

        isProcessingRequest = false
        isAutomaticListening = false

        assistantState = .responding
        assistantText = response
        audioLevel = 0

        updatePanel()

        speechOutputManager.speak(response) {
            [weak self] in

            guard let self else { return }

            print("ASSISTANT - response finished")

            self.startListeningAfterResponse()
        }
    }

    private func startListeningAfterResponse() {

        guard isAssistantVisible else { return }

        print("ASSISTANT - automatically returning to listening")

        cancelIdleHide()
        cancelRequestDelay()

        currentTranscription = ""
        selectedImage = nil
        assistantText = ""
        audioLevel = 0

        assistantState = .listening

        isAssistantActive = true
        isAutomaticListening = true
        isProcessingRequest = false
        shouldSendRequest = true

        updatePanel()

        speechManager.requestPermission {
            [weak self] granted in

            guard let self else { return }

            guard granted else {
                self.assistantText =
                    "Microphone permission is required."

                self.updatePanel()
                return
            }

            guard self.isAssistantActive else { return }

            self.speechManager.start()
            self.startIdleHideTimer()
        }
    }

    // MARK: Stop Button

    func stopCurrentOperation() {

        print("ASSISTANT - stop button pressed")

        cancelIdleHide()
        cancelRequestDelay()

        requestGeneration += 1

        shouldSendRequest = false
        isProcessingRequest = false
        isCaptureInProgress = false
        isAutomaticListening = false
        didCompleteCursorSelection = false

        speechManager.stop()
        speechOutputManager.stop()

        cursorSelectionManager.stop()
        cursorSelectionPanel.hide()

        currentTranscription = ""
        selectedImage = nil
        assistantText = ""
        audioLevel = 0

        assistantState = .listening
        isAssistantActive = true

        updatePanel()

        speechManager.requestPermission {
            [weak self] granted in

            guard let self else { return }
            guard granted else { return }
            guard self.isAssistantActive else { return }

            self.speechManager.start()
            self.startIdleHideTimer()
        }
    }

    // MARK: Idle Timeout

    private func startIdleHideTimer() {

        cancelIdleHide()

        idleHideTask = Task { [weak self] in

            try? await Task.sleep(
                nanoseconds: self?.idleTimeout ?? 5_000_000_000
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {

                guard let self else { return }

                guard self.assistantState == .listening else {
                    return
                }

                guard self.currentTranscription
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty else {
                    return
                }

                print("ASSISTANT - no speech for 5 seconds, hiding")

                self.isAssistantActive = false
                self.isAutomaticListening = false
                self.shouldSendRequest = false

                self.speechManager.stop()
                self.cursorSelectionManager.stop()

                self.hide()
            }
        }
    }

    private func cancelIdleHide() {
        idleHideTask?.cancel()
        idleHideTask = nil
    }

    private func cancelRequestDelay() {
        requestDelayTask?.cancel()
        requestDelayTask = nil
    }

    // MARK: Click Outside

    private func startClickMonitor() {

        guard clickMonitor == nil else { return }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] _ in

            DispatchQueue.main.async {

                guard let self else { return }
                guard self.isAssistantVisible else { return }
                guard let panel = self.panel else { return }

                let mouseLocation = NSEvent.mouseLocation

                // Ignore clicks on the assistant itself.
                if panel.frame.contains(mouseLocation) {
                    return
                }

                // Cursor selection is controlled by the
                // Control + Option shortcut, not by clicks.
                if self.cursorSelectionManager.isSelecting {
                    return
                }

                // Do not interrupt an active voice session.
                if self.assistantState == .listening {
                    return
                }

                // Ignore outside clicks during processing.
                if self.assistantState == .analyzing ||
                    self.assistantState == .responding {
                    return
                }

                print("ASSISTANT - clicked outside, hiding")

                self.isAssistantActive = false
                self.isAutomaticListening = false
                self.shouldSendRequest = false

                self.cancelIdleHide()
                self.cancelRequestDelay()

                self.speechManager.stop()
                self.speechOutputManager.stop()

                self.cursorSelectionManager.stop()
                self.hide()
            }
        }
    }

    private func stopClickMonitor() {

        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    // MARK: Panel

    func show() {

        if !isAssistantVisible {

            isAssistantVisible = true

            cursorSelectionPanel.hide()
        }

        positionAtBottomCenter()

        panel?.orderFrontRegardless()

        updatePanel()

        print("Assistant ON")
    }

    func hide() {

        cancelIdleHide()
        cancelRequestDelay()

        guard isAssistantVisible else { return }

        isAssistantVisible = false

        cursorSelectionManager.stop()
        cursorSelectionPanel.hide()

        panel?.orderOut(nil)

        print("Assistant OFF")
    }

    // MARK: Create Panel

    private func createPanel() {

        let initialView = AssistantOverlay(
            state: assistantState,
            text: assistantText,
            audioLevel: audioLevel,
            hasImage: selectedImage != nil,
            onStop: { [weak self] in
                self?.stopCurrentOperation()
            }
        )

        let hostingView = NSHostingView(rootView: initialView)

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let newPanel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 360,
                height: 80
            ),
            styleMask: [
                .borderless,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        newPanel.contentView = hostingView

        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false

        newPanel.level = .floating

        newPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        newPanel.hidesOnDeactivate = false
        newPanel.isMovableByWindowBackground = false
        newPanel.ignoresMouseEvents = false

        self.hostingView = hostingView
        self.panel = newPanel
    }

    // MARK: Update Panel

    private func updatePanel() {

        guard let panel, let hostingView else { return }

        let view = AssistantOverlay(
            state: assistantState,
            text: assistantText,
            audioLevel: audioLevel,
            hasImage: selectedImage != nil,
            onStop: { [weak self] in
                self?.stopCurrentOperation()
            }
        )

        hostingView.rootView = view
        hostingView.layoutSubtreeIfNeeded()

        var fittingSize = hostingView.fittingSize

        fittingSize.width = max(
            300,
            min(fittingSize.width, 650)
        )

        fittingSize.height = max(
            66,
            fittingSize.height
        )

        let oldFrame = panel.frame
        let oldCenterX = oldFrame.midX
        let bottomY = getAssistantBottomY()

        let newFrame = NSRect(
            x: oldCenterX - fittingSize.width / 2,
            y: bottomY,
            width: fittingSize.width,
            height: fittingSize.height
        )

        let sizeChanged =
            abs(oldFrame.width - newFrame.width) > 0.5 ||
            abs(oldFrame.height - newFrame.height) > 0.5

        if sizeChanged {

            NSAnimationContext.runAnimationGroup { context in

                context.duration = 0.30

                context.timingFunction = CAMediaTimingFunction(
                    name: .easeInEaseOut
                )

                panel.animator().setFrame(
                    newFrame,
                    display: true
                )
            }

        } else {

            // Avoid animation on every microphone level update.
            panel.setFrame(newFrame, display: true)
        }

        if isAssistantVisible {
            panel.orderFrontRegardless()
        }
    }

    private func getAssistantBottomY() -> CGFloat {

        guard let screen = NSScreen.main else {
            return 90
        }

        return screen.visibleFrame.minY + 85
    }

    private func positionAtBottomCenter() {

        guard let panel, let screen = NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        let x = screenFrame.midX - panelSize.width / 2
        let y = getAssistantBottomY()

        panel.setFrameOrigin(
            CGPoint(x: x, y: y)
        )
    }

    // MARK: Stop

    func stop() {

        cancelIdleHide()
        cancelRequestDelay()

        stopClickMonitor()

        assistantSessionStart = nil

        isAssistantActive = false
        isAutomaticListening = false

        requestGeneration += 1

        shouldSendRequest = false
        isProcessingRequest = false
        isCaptureInProgress = false
        didCompleteCursorSelection = false

        speechManager.stop()
        speechOutputManager.stop()

        cursorSelectionManager.stop()
        cursorSelectionPanel.hide()

        hide()
    }
}
