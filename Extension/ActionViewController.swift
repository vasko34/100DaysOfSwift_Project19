import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ActionViewController: UIViewController {
    @IBOutlet var script: UITextView!
    var dictionaryForStorage = [String: [String: String]]()
    var dictionaryForHost = [String: String]()
    var pageTitle = ""
    var pageURL = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        performSelector(inBackground: #selector(loadScript), with: nil)
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveButtonTapped))
        let commandList = UIBarButtonItem(title: "Command List", style: .plain, target: self, action: #selector(listTapped))
        let scriptsList = UIBarButtonItem(title: "Scripts", style: .plain, target: self, action: #selector(showScripts))
        navigationItem.leftBarButtonItems = [commandList, scriptsList]
        navigationItem.rightBarButtonItems = [doneButton, saveButton]
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(adjustForKeyboard), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let itemProvider = inputItem.attachments?.first {
                itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String) { [weak self] (dict, error) in
                    guard let itemDictionary = dict as? NSDictionary else { return }
                    guard let javaScriptValues = itemDictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary else { return }
                    
                    self?.pageTitle = javaScriptValues["title"] as? String ?? ""
                    self?.pageURL = javaScriptValues["URL"] as? String ?? ""
                    
                    if let pageURL = self?.pageURL {
                        if let url = URL(string: pageURL) {
                            if let host = url.host() {
                                if let dictForHost = self?.dictionaryForStorage[host] {
                                    self?.dictionaryForHost = dictForHost
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self?.title = self?.pageTitle
                    }
                }
            }
        }
    }

    @IBAction func done() {
        let item = NSExtensionItem()
        let argument: NSDictionary = ["customJavaScript": script.text ?? ""]
        let webDictionary: NSDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: argument]
        let customJavaScript = NSItemProvider(item: webDictionary, typeIdentifier: kUTTypePropertyList as String)
        item.attachments = [customJavaScript]
        extensionContext?.completeRequest(returningItems: [item])
        saveScript()
    }
    
    @objc func adjustForKeyboard(notification: Notification) {
        guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardScreenEndFrame = keyboardValue.cgRectValue
        let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)
        
        if notification.name == UIResponder.keyboardWillHideNotification {
            script.contentInset = .zero
        } else {
            script.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
        }
        
        script.scrollIndicatorInsets = script.contentInset
        
        let selectedRange = script.selectedRange
        script.scrollRangeToVisible(selectedRange)
    }
    
    @objc func listTapped() {
        let ac = UIAlertController(title: "Command List:", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "alert(document.title);", style: .default) { [weak self] action in
            self?.script.text = action.title
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    @objc func showScripts() {
        let ac = UIAlertController(title: "Scipts:", message: nil, preferredStyle: .actionSheet)
        if let url = URL(string: pageURL) {
            if let host = url.host() {
                let dictKeys = dictionaryForStorage[host]?.keys
                if let keys = dictKeys {
                    let keyArray = Array(keys)
                    for key in keyArray {
                        ac.addAction(UIAlertAction(title: key, style: .default) { [weak self] action in
                            if let actionTitle = action.title {
                                self?.script.text = self?.dictionaryForStorage[host]?[actionTitle]
                            }
                        })
                    }
                    ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    present(ac, animated: true)
                }
            }
        }
    }
    
    @objc func saveButtonTapped() {
        let ac = UIAlertController(title: "Enter script name:", message: nil, preferredStyle: .alert)
        ac.addTextField()
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak ac] _ in
            if let pageURL = self?.pageURL {
                if let url = URL(string: pageURL) {
                    if let host = url.host() {
                        if let textField = ac?.textFields?[0].text {
                            if let scriptText = self?.script.text {
                                self?.dictionaryForHost[textField] = scriptText
                                self?.dictionaryForStorage[host] = self?.dictionaryForHost
                            }
                        }
                    }
                }
            }
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func saveScript() {
        let jsonEncoder = JSONEncoder()
        let defaults = UserDefaults.standard
        if let savedDict = try? jsonEncoder.encode(dictionaryForStorage) {
            defaults.setValue(savedDict, forKey: "script")
        }
    }
    
    @objc func loadScript() {
        let jsonDecoder = JSONDecoder()
        let defaults = UserDefaults.standard
        if let dictToLoad = defaults.object(forKey: "script") as? Data {
            do {
                dictionaryForStorage = try jsonDecoder.decode([String: [String: String]].self, from: dictToLoad)
            } catch {
                print("Failed to load storageDict.")
            }
        }
    }
}
