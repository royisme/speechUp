import Foundation
import Combine // For @Published if we decide to use it for bindings

class PracticeViewModel: ObservableObject {
    private let audioService: AudioService
    private let recordingRepository: RecordingRepository
    private let textRepository: TextRepository
    
    let currentPracticeText: PracticeText // Passed during initialization

    // @Published can be used if SwiftUI is adopted later or for Combine-based UI updates
    // For UIKit, we'll use manual updates or closures/delegates from VC.
    var isRecording: Bool = false {
        didSet {
            // This is a good place for a closure/delegate call to update UI if not using Combine's @Published
            onRecordingStateChanged?(isRecording)
        }
    }
    var lastRecordingURL: URL? {
        didSet {
            onLastRecordingURLChanged?(lastRecordingURL)
        }
    }
    var recordingStartTime: Date?
    var currentRecordingDuration: TimeInterval = 0 {
        didSet {
            onRecordingDurationChanged?(currentRecordingDuration)
        }
    }
    private var durationTimer: Timer?

    // Closures for UI updates in ViewController
    var onRecordingStateChanged: ((Bool) -> Void)?
    var onLastRecordingURLChanged: ((URL?) -> Void)?
    var onRecordingDurationChanged: ((TimeInterval) -> Void)?
    var onError: ((Error) -> Void)? // To communicate errors to the View

    init(practiceText: PracticeText, 
         audioService: AudioService = AudioService(), 
         recordingRepository: RecordingRepository = RecordingRepository(),
         textRepository: TextRepository = TextRepository()) {
        self.currentPracticeText = practiceText
        self.audioService = audioService
        self.recordingRepository = recordingRepository
        self.textRepository = textRepository
        
        // Fetch the most recent recording for this text, if any, to enable playback initially.
        // For MVP, we could simplify and only allow playback of newly created recordings.
        // However, this makes it a bit more user-friendly.
        let existingRecordings = recordingRepository.fetchRecordings(forTextID: practiceText.id, sortByCreatedAt: false)
        if let mostRecentRecording = existingRecordings.first {
            self.lastRecordingURL = mostRecentRecording.fileURL
        }
    }

    @MainActor
    func toggleRecording() async {
        if isRecording {
            // Stop recording
            audioService.stopRecording() // This will trigger delegate, which then saves.
                                        // The actual saving logic is now in the delegate method.
            // isRecording will be set to false in the delegate method audioRecorderDidFinishRecording
        } else {
            // Start recording
            do {
                isRecording = true // Set state immediately
                recordingStartTime = Date()
                startDurationTimer()
                let url = try await audioService.startRecording()
                // This URL is where the recording *will be* once finished.
                // The actual saving and setting of lastRecordingURL happens in the delegate callback.
                print("Recording started, will be saved to: \(url.path)")
            } catch {
                print("Error starting recording: \(error)")
                onError?(error)
                isRecording = false // Reset state on error
                stopDurationTimer()
            }
        }
    }
    
    // This method should be called by AudioService delegate `audioRecorderDidFinishRecording`
    @MainActor
    func recordingFinished(url: URL, successfully: Bool) {
        stopDurationTimer()
        currentRecordingDuration = 0 // Reset duration display
        isRecording = false // Update state *after* async operation and delegate call

        guard successfully else {
            print("Recording finished unsuccessfully.")
            // Optionally, provide error feedback to the user via onError closure
            onError?(NSError(domain: "PracticeViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording failed."]))
            return
        }
        
        guard let startTime = recordingStartTime else {
            print("Error: recordingStartTime was nil. Cannot calculate duration.")
            onError?(NSError(domain: "PracticeViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Recording start time was missing."]))
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        self.lastRecordingURL = url // Store the URL of the new recording
        
        print("Recording finished. URL: \(url.path), Duration: \(duration)")
        
        // Save recording metadata to Core Data
        _ = recordingRepository.saveRecording(fileURL: url, duration: duration, textID: currentPracticeText.id)
        
        // No need to call textRepository.updatePracticeTextStats here as
        // recordingRepository.saveRecording already calls it.
    }

    @MainActor
    func playLastRecording() async {
        guard let urlToPlay = lastRecordingURL else {
            print("No recording URL found to play.")
            onError?(NSError(domain: "PracticeViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "No recording available to play."]))
            return
        }
        
        // Ensure not currently recording before attempting playback
        if isRecording {
            print("Cannot play recording while another recording is in progress.")
            onError?(NSError(domain: "PracticeViewModel", code: 4, userInfo: [NSLocalizedDescriptionKey: "Please stop the current recording before playing."]))
            return
        }
        
        do {
            print("Attempting to play recording from URL: \(urlToPlay.path)")
            try await audioService.playRecording(url: urlToPlay)
            print("Playback finished.")
        } catch {
            print("Error playing last recording: \(error)")
            onError?(error)
        }
    }

    func stopPlayback() {
        audioService.stopPlaying()
    }
    
    private func startDurationTimer() {
        durationTimer?.invalidate() // Invalidate existing timer
        currentRecordingDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.currentRecordingDuration = Date().timeIntervalSince(startTime)
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // Call this when the view model is about to be deallocated
    deinit {
        stopDurationTimer()
        // If recording, ensure it's stopped to prevent resource leaks or unexpected behavior
        if isRecording {
            audioService.stopRecording()
        }
        // If playing, stop playback
        audioService.stopPlaying()
        print("PracticeViewModel deinitialized.")
    }
}
