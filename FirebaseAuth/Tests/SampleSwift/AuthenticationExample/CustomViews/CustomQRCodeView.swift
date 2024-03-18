import UIKit

class CustomQRCodeAlertViewController: UIViewController {
  
  @IBOutlet weak var qrCodeImageView: UIImageView!
  @IBOutlet weak var textField: UITextField!
  
  var completion: ((String) -> Void)?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  @IBAction func submitButtonTapped(_ sender: UIButton) {
    guard let text = textField.text else { return }
    completion?(text)
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func cancelButtonTapped(_ sender: UIButton) {
    dismiss(animated: true, completion: nil)
  }
}
