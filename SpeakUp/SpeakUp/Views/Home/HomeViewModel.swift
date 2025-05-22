import Foundation
import Combine // For @Published or ObservableObject

class HomeViewModel: ObservableObject {
    private let textRepository: TextRepository
    // Keep references to services needed by PracticeViewModel to pass them along
    let audioService: AudioService
    let recordingRepository: RecordingRepository

    // @Published can be used for SwiftUI, or a simple array for UIKit with manual updates
    @Published var practiceTexts: [PracticeText] = []
    
    var onError: ((Error) -> Void)?
    var onDataReload: (() -> Void)? // To tell the ViewController to reload its table view

    init(textRepository: TextRepository = TextRepository(),
         audioService: AudioService = AudioService(),
         recordingRepository: RecordingRepository = RecordingRepository()) {
        self.textRepository = textRepository
        self.audioService = audioService
        self.recordingRepository = recordingRepository
    }

    func fetchPracticeTexts() {
        let texts = textRepository.fetchAllTexts(sortByCreatedAt: true) // Sort by creation date, or make it configurable
        // Update on the main thread if this can be called from a background thread
        DispatchQueue.main.async {
            self.practiceTexts = texts
            self.onDataReload?() // Notify ViewController to reload data
            if texts.isEmpty {
                print("No practice texts found. The list will be empty.")
                // Optionally, could use onError to inform user if this is unexpected
            }
        }
    }
    
    func getPracticeText(at index: Int) -> PracticeText? {
        guard index >= 0 && index < practiceTexts.count else {
            return nil
        }
        return practiceTexts[index]
    }
}
