import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = .white // Basic setup
        
        let label = UILabel()
        label.text = "SpeakUp MVP"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Test Core Data initialization
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        print("Main view controller loaded. Core Data context obtained: \(context)")
    }
}
