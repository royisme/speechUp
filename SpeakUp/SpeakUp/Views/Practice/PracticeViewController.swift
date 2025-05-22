import UIKit
import AVFoundation // For AVAudioSession for permission check

class PracticeViewController: UIViewController {

    var practiceText: PracticeText? {
        didSet {
            if let text = practiceText {
                viewModel = PracticeViewModel(practiceText: text)
                // Setup AudioService delegate to point to this new ViewModel instance.
                // This is important if PracticeViewController can be reused with different practiceTexts.
                (viewModel?.audioService as? AudioService)?.practiceViewModel = viewModel
            }
            configureViewForPracticeText()
        }
    }
    
    private var viewModel: PracticeViewModel?

    // UI Elements
    private let practiceTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 8.0
        return textView
    }()

    private let recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Record", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Play Last Recording", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false // Initially disabled
        return button
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        label.text = "00:00.0"
        label.textColor = .darkGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        setupViewModelClosures()
        checkAudioPermissions()
        
        // If practiceText was set before viewDidLoad (e.g. by prepareForSegue or direct property set)
        if viewModel == nil, let text = practiceText {
             viewModel = PracticeViewModel(practiceText: text)
             (viewModel?.audioService as? AudioService)?.practiceViewModel = viewModel
        }
        configureViewForPracticeText()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop any ongoing recording or playback when the view disappears
        if viewModel?.isRecording ?? false {
            Task {
                await viewModel?.toggleRecording() // Stop recording
            }
        }
        viewModel?.stopPlayback() // Stop playback
    }

    private func setupUI() {
        view.addSubview(practiceTextView)
        view.addSubview(recordButton)
        view.addSubview(durationLabel)
        view.addSubview(playButton)

        recordButton.addTarget(self, action: #selector(recordButtonPressed), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playButtonPressed), for: .touchUpInside)

        NSLayoutConstraint.activate([
            practiceTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            practiceTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            practiceTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            practiceTextView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),

            durationLabel.topAnchor.constraint(equalTo: practiceTextView.bottomAnchor, constant: 20),
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            durationLabel.heightAnchor.constraint(equalToConstant: 30),

            recordButton.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 20),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 200),
            recordButton.heightAnchor.constraint(equalToConstant: 50),

            playButton.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 20),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 200),
            playButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func configureViewForPracticeText() {
        guard let viewModel = viewModel, isViewLoaded else { return }
        navigationItem.title = viewModel.currentPracticeText.title ?? "Practice"
        practiceTextView.text = viewModel.currentPracticeText.content
        updateUIForViewModelState()
    }

    private func setupViewModelClosures() {
        viewModel?.onRecordingStateChanged = { [weak self] isRecording in
            self?.updateRecordButtonState(isRecording: isRecording)
        }
        
        viewModel?.onLastRecordingURLChanged = { [weak self] url in
            self?.updatePlayButtonState(hasRecording: url != nil)
        }
        
        viewModel?.onRecordingDurationChanged = { [weak self] duration in
            self?.updateDurationLabel(duration: duration)
        }

        viewModel?.onError = { [weak self] error in
            // Simple alert for errors
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    private func updateUIForViewModelState() {
        guard let viewModel = viewModel, isViewLoaded else { return }
        updateRecordButtonState(isRecording: viewModel.isRecording)
        updatePlayButtonState(hasRecording: viewModel.lastRecordingURL != nil)
        updateDurationLabel(duration: viewModel.currentRecordingDuration)
    }

    private func updateRecordButtonState(isRecording: Bool) {
        if isRecording {
            recordButton.setTitle("Stop Recording", for: .normal)
            recordButton.backgroundColor = .systemOrange // Or another color for "Stop"
        } else {
            recordButton.setTitle("Record", for: .normal)
            recordButton.backgroundColor = .systemRed
        }
    }

    private func updatePlayButtonState(hasRecording: Bool) {
        playButton.isEnabled = hasRecording
        playButton.alpha = hasRecording ? 1.0 : 0.5
    }
    
    private func updateDurationLabel(duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(minutes * 60) - Double(seconds)) * 10)
        durationLabel.text = String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    @objc private func recordButtonPressed() {
        guard let viewModel = viewModel else { return }
        // If we are about to start recording, first check permissions
        if !viewModel.isRecording {
            checkAudioPermissions { [weak self] granted in
                guard granted else {
                    self?.showPermissionsAlert()
                    return
                }
                // Permissions granted, proceed with recording
                Task { // Swift concurrency Task
                    await self?.viewModel?.toggleRecording()
                }
            }
        } else {
            // If already recording, just toggle (stop)
            Task {
                await viewModel.toggleRecording()
            }
        }
    }

    @objc private func playButtonPressed() {
        guard let viewModel = viewModel else { return }
        Task { // Swift concurrency Task
            await viewModel.playLastRecording()
        }
    }
    
    // MARK: - Audio Permissions
    private func checkAudioPermissions(completion: ((Bool) -> Void)? = nil) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            print("Audio permission granted.")
            completion?(true)
        case .denied:
            print("Audio permission denied.")
            completion?(false)
        case .undetermined:
            print("Audio permission undetermined. Requesting...")
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        print("Audio permission granted after request.")
                    } else {
                        print("Audio permission denied after request.")
                    }
                    completion?(granted)
                }
            }
        @unknown default:
            print("Unknown audio permission state.")
            completion?(false)
        }
    }
    
    private func showPermissionsAlert() {
        let alert = UIAlertController(
            title: "Microphone Access Denied",
            message: "SpeakUp needs access to your microphone to record audio. Please enable access in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    deinit {
        print("PracticeViewController deinitialized.")
    }
}

// Helper to make UIFont.monospacedDigitSystemFont available if needed for older iOS versions
// (though systemFont of size will generally use a good monospaced font for digits if available)
// For simplicity, the above uses systemFont which is fine for this MVP.
