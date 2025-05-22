import UIKit

class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var viewModel: HomeViewModel! // Will be set by SceneDelegate or AppDelegate

    // UI Elements
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PracticeTextCell")
        return tableView
    }()

    // Convenience init for programmatic setup (e.g., in SceneDelegate)
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        // This would be used if initializing from a Storyboard, which we are not for this MVP.
        // If this were ever needed, the viewModel would have to be injected differently.
        fatalError("init(coder:) has not been implemented. Use init(viewModel:) instead.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "SpeakUp - Practice Texts" // Navigation bar title
        setupUI()
        setupViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.fetchPracticeTexts() // Fetch texts every time the view appears
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupViewModel() {
        viewModel.onDataReload = { [weak self] in
            self?.tableView.reloadData()
        }
        
        viewModel.onError = { [weak self] error in
            // Simple alert for errors
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.practiceTexts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PracticeTextCell", for: indexPath)
        guard let practiceText = viewModel.getPracticeText(at: indexPath.row) else {
            // Return a default or empty cell if data is not available
            cell.textLabel?.text = "Error loading text"
            return cell
        }
        cell.textLabel?.text = practiceText.title
        cell.accessoryType = .disclosureIndicator // Indicate tappable cell
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let selectedText = viewModel.getPracticeText(at: indexPath.row) else {
            print("Error: Could not retrieve selected practice text.")
            // Optionally show an error to the user
            let errorAlert = UIAlertController(title: "Error", message: "Could not load the selected practice text.", preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            present(errorAlert, animated: true)
            return
        }
        
        // Create PracticeViewController and its ViewModel
        // The HomeViewModel holds instances of services needed by PracticeViewModel
        let practiceViewModel = PracticeViewModel(
            practiceText: selectedText,
            audioService: viewModel.audioService, // Pass the existing AudioService instance
            recordingRepository: viewModel.recordingRepository, // Pass the existing RecordingRepository instance
            textRepository: TextRepository() // PracticeViewModel can instantiate its own TextRepo if needed, or it can be passed
        )
        
        let practiceVC = PracticeViewController()
        practiceVC.practiceText = selectedText // Set the text, which will also set up its own ViewModel.
                                              // Or, directly set the viewModel:
                                              // practiceVC.viewModel = practiceViewModel (if PracticeVC's viewModel is public)
                                              // For current setup, setting practiceText is the trigger.

        // Ensure the AudioService's practiceViewModel delegate is correctly set to the new PracticeViewModel
        // This is crucial because AudioService has a weak var practiceViewModel.
        // When PracticeViewController sets its own viewModel, it also sets it on the AudioService.
        // (viewModel.audioService as? AudioService)?.practiceViewModel = practiceViewModel 
        // ^This line is handled inside PracticeViewController when practiceText is set.

        navigationController?.pushViewController(practiceVC, animated: true)
    }
}
