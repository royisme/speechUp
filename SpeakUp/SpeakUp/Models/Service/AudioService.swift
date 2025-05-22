import AVFoundation
import UIKit // For UIDevice

class AudioService: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingContinuation: CheckedContinuation<URL, Error>?
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    
    // Weak reference to the ViewModel to notify about recording completion.
    // This is a simplification for MVP. A delegate pattern would be cleaner.
    weak var practiceViewModel: PracticeViewModel? 

    override init() {
        super.init()
        setupAudioSession()
    }

    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set category to playAndRecord to allow both recording and playback.
            // .defaultToSpeaker option ensures playback is through the speaker even if headphones are not connected.
            // .allowBluetoothA2DP allows for playback on Bluetooth audio devices if available.
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            print("Audio session configured and activated.")
        } catch {
            // Handle error (e.g., print error, show alert to user)
            print("Failed to set up audio session: \(error)")
        }
    }

    func startRecording() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.recordingContinuation = continuation
            
            let audioFilename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000, // Standard sample rate
                AVNumberOfChannelsKey: 1, // Mono recording
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue // High quality
            ]

            do {
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                audioRecorder?.delegate = self // Delegate to handle recording events
                audioRecorder?.isMeteringEnabled = true // Enable audio metering
                audioRecorder?.record() // Start recording
                print("Recording started at URL: \(audioFilename)")
            } catch {
                print("Could not start recording: \(error)")
                continuation.resume(throwing: error)
                self.recordingContinuation = nil
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        // The actual URL is returned via the delegate method audioRecorderDidFinishRecording
        print("Recording stopped.")
    }

    func playRecording(url: URL) async throws {
        // Ensure audio session is active and configured for playback
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session for playback: \(error)")
            throw error // Propagate the error
        }
        
        // Check if the file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found at URL: \(url.path)")
            throw NSError(domain: "AudioServiceError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Audio file not found."])
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.playbackContinuation = continuation
            do {
                // For iOS 15+, check if device is muted (silent switch)
                // This is a simplified check. For more robust handling, you might need more complex logic.
                if #available(iOS 15.0, *) {
                    if audioSession.isOtherAudioPlaying && audioSession.secondaryAudioShouldBeSilencedHint {
                         print("Other audio is playing and should be silenced. Playback might be muted.")
                    }
                    if audioSession.outputVolume == 0 {
                        print("Device is muted. Playback might not be audible.")
                        // You could potentially alert the user here or handle it as an error.
                        // For now, we'll proceed with playback.
                    }
                }


                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.play()
                print("Playback started for URL: \(url.path)")
            } catch {
                print("Could not play recording: \(error)")
                continuation.resume(throwing: error)
                self.playbackContinuation = nil
            }
        }
    }

    func stopPlaying() {
        audioPlayer?.stop()
        playbackContinuation?.resume(throwing: CancellationError()) // Indicate playback was stopped
        playbackContinuation = nil
        print("Playback stopped.")
        // It's good practice to deactivate the audio session or reset its category
        // if the app is not actively using audio, to allow other apps to use it.
        // However, for simplicity in this MVP, we might leave it active.
        // Consider deactivating or resetting category in a real app.
        // For example:
        // do {
        //     try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // } catch {
        //     print("Failed to deactivate audio session: \(error)")
        // }
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Notify the ViewModel first
        if let viewModel = practiceViewModel {
            DispatchQueue.main.async { // Ensure UI updates are on the main thread
                viewModel.recordingFinished(url: recorder.url, successfully: flag)
            }
        }

        if flag {
            recordingContinuation?.resume(returning: recorder.url)
            print("AudioRecorder finished successfully. URL: \(recorder.url)")
        } else {
            // Recording failed or was stopped before completion (e.g. by an interruption)
            recordingContinuation?.resume(throwing: NSError(domain: "AudioServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording failed or was interrupted."]))
            print("AudioRecorder finished unsuccessfully.")
        }
        recordingContinuation = nil
        audioRecorder = nil // Release the recorder instance
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        // Notify the ViewModel about the error
        if let viewModel = practiceViewModel {
            DispatchQueue.main.async {
                viewModel.recordingFinished(url: recorder.url, successfully: false) // Indicate failure
            }
        }

        if let error = error {
            recordingContinuation?.resume(throwing: error)
            print("AudioRecorder encode error: \(error.localizedDescription)")
        } else {
            recordingContinuation?.resume(throwing: NSError(domain: "AudioServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown recording encode error."]))
            print("AudioRecorder encode error (unknown).")
        }
        recordingContinuation = nil
        audioRecorder = nil
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playbackContinuation?.resume(returning: ())
            print("AudioPlayer finished playing successfully.")
        } else {
            playbackContinuation?.resume(throwing: NSError(domain: "AudioServiceError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Playback failed or was interrupted."]))
            print("AudioPlayer finished playing unsuccessfully.")
        }
        playbackContinuation = nil
        audioPlayer = nil // Release the player instance
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            playbackContinuation?.resume(throwing: error)
            print("AudioPlayer decode error: \(error.localizedDescription)")
        } else {
            playbackContinuation?.resume(throwing: NSError(domain: "AudioServiceError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown playback decode error."]))
            print("AudioPlayer decode error (unknown).")
        }
        playbackContinuation = nil
        audioPlayer = nil
    }
}
