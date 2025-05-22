import CoreData
import Foundation // For FileManager

class RecordingRepository {
    private let viewContext: NSManagedObjectContext
    private let textRepository: TextRepository // To fetch PracticeText

    init(persistenceController: PersistenceController = PersistenceController.shared, textRepository: TextRepository = TextRepository()) {
        self.viewContext = persistenceController.container.viewContext
        self.textRepository = textRepository
    }

    func saveRecording(fileURL: URL, duration: Double, textID: UUID) -> Recording? {
        guard let practiceText = textRepository.getPracticeText(byID: textID) else {
            print("Error: Could not find PracticeText with ID \(textID) to associate with the recording.")
            return nil
        }

        let newRecording = Recording(context: viewContext)
        newRecording.id = UUID()
        newRecording.fileURL = fileURL
        newRecording.duration = duration
        newRecording.createdAt = Date()
        newRecording.practiceText = practiceText
        
        // Update practice text stats
        textRepository.updatePracticeTextStats(textID: textID, lastPracticedAt: Date())

        do {
            try viewContext.save()
            print("Successfully saved recording for text ID: \(textID) at \(fileURL.path)")
            return newRecording
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo) while saving recording.")
            // It might be good to delete the audio file if DB save fails
            // For now, we'll just report the error.
            return nil
        }
    }

    func fetchAllRecordings(sortByCreatedAt ascending: Bool = false) -> [Recording] {
        let fetchRequest: NSFetchRequest<Recording> = Recording.fetchRequest()
        
        let sortDescriptor = NSSortDescriptor(keyPath: \Recording.createdAt, ascending: ascending)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let recordings = try viewContext.fetch(fetchRequest)
            return recordings
        } catch {
            print("Failed to fetch recordings: \(error)")
            return []
        }
    }
    
    func fetchRecordings(forTextID textID: UUID, sortByCreatedAt ascending: Bool = false) -> [Recording] {
        let fetchRequest: NSFetchRequest<Recording> = Recording.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "practiceText.id == %@", textID as CVarArg)
        
        let sortDescriptor = NSSortDescriptor(keyPath: \Recording.createdAt, ascending: ascending)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let recordings = try viewContext.fetch(fetchRequest)
            return recordings
        } catch {
            print("Failed to fetch recordings for text ID \(textID): \(error)")
            return []
        }
    }

    func deleteRecording(recordingID: UUID) {
        let fetchRequest: NSFetchRequest<Recording> = Recording.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", recordingID as CVarArg)
        
        do {
            guard let recordingToDelete = try viewContext.fetch(fetchRequest).first else {
                print("Recording with ID \(recordingID) not found.")
                return
            }
            
            // Delete the audio file from disk
            if let fileURL = recordingToDelete.fileURL {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("Successfully deleted audio file: \(fileURL.path)")
                } catch {
                    print("Error deleting audio file \(fileURL.path): \(error)")
                    // Proceed with deleting the Core Data entry even if file deletion fails,
                    // as the file might not exist or there might be permission issues.
                }
            }
            
            // Delete the Recording object from Core Data
            viewContext.delete(recordingToDelete)
            
            try viewContext.save()
            print("Successfully deleted recording with ID: \(recordingID)")
            
        } catch {
            print("Failed to delete recording with ID \(recordingID): \(error)")
            // Handle the error appropriately
        }
    }
}
