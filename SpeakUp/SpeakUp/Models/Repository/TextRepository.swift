import CoreData
import UIKit // Required for UIApplication delegate access for context

class TextRepository {
    private let viewContext: NSManagedObjectContext

    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.viewContext = persistenceController.container.viewContext
    }

    func importSampleTexts() {
        let fetchRequest: NSFetchRequest<PracticeText> = PracticeText.fetchRequest()
        
        do {
            let existingTexts = try viewContext.fetch(fetchRequest)
            guard existingTexts.isEmpty else {
                print("Sample texts already exist. Skipping import.")
                return
            }
        } catch {
            print("Error fetching existing texts: \(error)")
            // Decide if we should proceed or not, for now, we'll proceed if fetch fails
        }

        let sampleTexts = [
            ("Greeting", "Hello world. This is a sample text for practice."),
            ("Proverb", "Practice makes perfect. Repeat this line several times."),
            ("Affirmation", "I am confident in my ability to speak clearly and effectively.")
        ]

        for (index, (title, content)) in sampleTexts.enumerated() {
            let newText = PracticeText(context: viewContext)
            newText.id = UUID()
            newText.title = "\(title) (Sample \(index + 1))"
            newText.content = content
            newText.createdAt = Date()
            newText.practiceCount = 0
            newText.lastPracticedAt = nil // Initially not practiced
        }

        do {
            try viewContext.save()
            print("Successfully imported sample texts.")
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    func fetchAllTexts(sortByCreatedAt ascending: Bool = true) -> [PracticeText] {
        let fetchRequest: NSFetchRequest<PracticeText> = PracticeText.fetchRequest()
        
        let sortDescriptor = NSSortDescriptor(keyPath: \PracticeText.createdAt, ascending: ascending)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            let texts = try viewContext.fetch(fetchRequest)
            return texts
        } catch {
            print("Failed to fetch texts: \(error)")
            return []
        }
    }

    func updatePracticeTextStats(textID: UUID, lastPracticedAt: Date) {
        let fetchRequest: NSFetchRequest<PracticeText> = PracticeText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", textID as CVarArg)
        
        do {
            let texts = try viewContext.fetch(fetchRequest)
            guard let textToUpdate = texts.first else {
                print("PracticeText with ID \(textID) not found.")
                return
            }
            
            textToUpdate.lastPracticedAt = lastPracticedAt
            textToUpdate.practiceCount += 1
            
            try viewContext.save()
            print("Successfully updated practice text stats for ID: \(textID)")
        } catch {
            print("Failed to update PracticeText stats for ID \(textID): \(error)")
            // Handle the error appropriately
        }
    }
    
    func getPracticeText(byID id: UUID) -> PracticeText? {
        let fetchRequest: NSFetchRequest<PracticeText> = PracticeText.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching PracticeText with ID \(id): \(error)")
            return nil
        }
    }
}
