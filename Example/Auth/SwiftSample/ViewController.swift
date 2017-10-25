/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit

import FirebaseCommunity.FirebaseAuth
import GoogleSignIn

final class ViewController: UIViewController, UITextFieldDelegate, AuthUIDelegate {
  /// The profile image for the currently signed-in user.
  @IBOutlet weak var profileImage: UIImageView!

  /// The display name for the currently signed-in user.
  @IBOutlet weak var displayNameLabel: UILabel!

  /// The email for the currently signed-in user.
  @IBOutlet weak var emailLabel: UILabel!

  /// The ID for the currently signed-in user.
  @IBOutlet weak var userIDLabel: UILabel!

  /// The list of providers for the currently signed-in user.
  @IBOutlet weak var providerListLabel: UILabel!

  /// The picker for the list of action types.
  @IBOutlet weak var actionTypePicker: UIPickerView!

  /// The picker for the list of actions.
  @IBOutlet weak var actionPicker: UIPickerView!

  /// The picker for the list of credential types.
  @IBOutlet weak var credentialTypePicker: UIPickerView!

  /// The label for the "email" text field.
  @IBOutlet weak var emailInputLabel: UILabel!

  /// The "email" text field.
  @IBOutlet weak var emailField: UITextField!

  /// The label for the "password" text field.
  @IBOutlet weak var passwordInputLabel: UILabel!

  /// The "password" text field.
  @IBOutlet weak var passwordField: UITextField!

  /// The "phone" text field.
  @IBOutlet weak var phoneField: UITextField!

  /// The scroll view holding all content.
  @IBOutlet weak var scrollView: UIScrollView!

  // The active keyboard input field.
  var activeField: UITextField?

  /// The currently selected action type.
  fileprivate var actionType = ActionType(rawValue: 0)! {
    didSet {
      if actionType != oldValue {
        actionPicker.reloadAllComponents()
        actionPicker.selectRow(actionType == .auth ? authAction.rawValue : userAction.rawValue,
                               inComponent: 0, animated: false)
      }
    }
  }

  /// The currently selected auth action.
  fileprivate var authAction = AuthAction(rawValue: 0)!

  /// The currently selected user action.
  fileprivate var userAction = UserAction(rawValue: 0)!

  /// The currently selected credential.
  fileprivate var credentialType = CredentialType(rawValue: 0)!

  /// The current Firebase user.
  fileprivate var user: User? = nil {
    didSet {
      if user?.uid != oldValue?.uid {
        actionTypePicker.reloadAllComponents()
        actionType = ActionType(rawValue: actionTypePicker.selectedRow(inComponent: 0))!
      }
    }
  }

  func registerForKeyboardNotifications() {
    NotificationCenter.default.addObserver(self,
                                           selector:
                                           #selector(keyboardWillBeShown(notification:)),
                                           name: NSNotification.Name.UIKeyboardWillShow,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(keyboardWillBeHidden(notification:)),
                                           name: NSNotification.Name.UIKeyboardWillHide,
                                           object: nil)
  }

  func deregisterFromKeyboardNotifications() {
    NotificationCenter.default.removeObserver(self,
                                              name: NSNotification.Name.UIKeyboardWillShow,
                                              object: nil)
    NotificationCenter.default.removeObserver(self,
                                              name: NSNotification.Name.UIKeyboardWillHide,
                                              object: nil)
  }

  func keyboardWillBeShown(notification: NSNotification) {
    scrollView.isScrollEnabled = true
    let info = notification.userInfo!
    let keyboardSize = (info[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.size
    let contentInsets : UIEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize!.height, 0.0)

    scrollView.contentInset = contentInsets
    scrollView.scrollIndicatorInsets = contentInsets

    var aRect = self.view.frame
    aRect.size.height -= keyboardSize!.height
    if let activeField = activeField {
      if (!aRect.contains(activeField.frame.origin)) {
        scrollView.scrollRectToVisible(activeField.frame, animated: true)
      }
    }
  }

  func keyboardWillBeHidden(notification: NSNotification){
    let info = notification.userInfo!
    let keyboardSize = (info[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.size
    let contentInsets : UIEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, -keyboardSize!.height, 0.0)
    scrollView.contentInset = contentInsets
    scrollView.scrollIndicatorInsets = contentInsets
    self.view.endEditing(true)
    scrollView.isScrollEnabled = false
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
      activeField = textField
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
      activeField = nil
  }

  func dismissKeyboard() {
      view.endEditing(true)
  }

  func verify(phoneNumber: String, completion: @escaping (PhoneAuthCredential?, Error?) -> Void) {
    if #available(iOS 8.0, *) {
      PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate:self) {
          verificationID, error in
        guard error == nil else {
          completion(nil, error)
          return
        }
        let codeAlertController =
            UIAlertController(title: "Enter Code", message: nil, preferredStyle: .alert)
        codeAlertController.addTextField { textfield in
            textfield.placeholder = "SMS Code"
            textfield.keyboardType = UIKeyboardType.numberPad
        }
        codeAlertController.addAction(UIAlertAction(title: "OK",
                                                    style: .default,
                                                    handler: { (UIAlertAction) in
          let code = codeAlertController.textFields!.first!.text!
          let phoneCredential =
            PhoneAuthProvider.provider().credential(withVerificationID: verificationID ?? "",
                                                    verificationCode: code)
          completion(phoneCredential, nil)
        }))
        self.present(codeAlertController, animated: true, completion: nil)
      }
    }
  }
  /// The user's photo URL used by the last network request for its contents.
  fileprivate var lastPhotoURL: URL? = nil

  override func viewDidLoad() {
    GIDSignIn.sharedInstance().uiDelegate = self
    updateUserInfo(Auth.auth())
    NotificationCenter.default.addObserver(forName: .AuthStateDidChange,
                                           object: Auth.auth(), queue: nil) { notification in
      self.updateUserInfo(notification.object as? Auth)
    }
    phoneField.delegate = self
    registerForKeyboardNotifications()

    let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    scrollView.addGestureRecognizer(tap)
  }

  override func viewWillDisappear(_ animated: Bool) {
    deregisterFromKeyboardNotifications()
  }

  /// Executes the action designated by the operator on the UI.
  @IBAction func execute(_ sender: UIButton) {
    switch actionType {
    case .auth:
      switch authAction {
      case .fetchProviderForEmail:
        Auth.auth().fetchProviders(forEmail: emailField.text!) { providers, error in
          self.ifNoError(error) {
            self.showAlert(title: "Providers", message: providers?.joined(separator: ", "))
          }
        }
      case .signInAnonymously:
        Auth.auth().signInAnonymously() { user, error in
          self.ifNoError(error) {
            self.showAlert(title: "Signed In Anonymously")
          }
        }
      case .signInWithCredential:
        getCredential() { credential in
          Auth.auth().signInAndRetrieveData(with: credential) { authData, error in
            self.ifNoError(error) {
              self.showAlert(title: "Signed In With Credential",
                           message: authData?.user.textDescription)
            }
          }
        }
      case .createUser:
        Auth.auth().createUser(withEmail: emailField.text!, password: passwordField.text!) {
            user, error in
          self.ifNoError(error) {
            self.showAlert(title: "Signed In With Credential", message: user?.textDescription)
          }
        }
      case .signOut:
        try! Auth.auth().signOut()
        GIDSignIn.sharedInstance().signOut()
      }
    case .user:
      switch userAction {
      case .updateEmail:
        user!.updateEmail(to: emailField.text!) { error in
          self.ifNoError(error) {
            self.showAlert(title: "Updated Email", message: self.user?.email)
          }
        }
      case .updatePhone:
        let phoneNumber = phoneField.text
        self.verify(phoneNumber: phoneNumber!, completion: { (phoneAuthCredential, error) in
          guard error == nil else {
            self.showAlert(title: "Error", message: error!.localizedDescription)
            return
          }
          self.user!.updatePhoneNumber(phoneAuthCredential!, completion: { error in
            self.ifNoError(error) {
              self.showAlert(title: "Updated Phone Number")
              self.updateUserInfo(Auth.auth())
            }
          })
        })
      case .updatePassword:
        user!.updatePassword(to: passwordField.text!) { error in
          self.ifNoError(error) {
            self.showAlert(title: "Updated Password")
          }
        }
      case .reload:
        user!.reload() { error in
          self.ifNoError(error) {
            self.showAlert(title: "Reloaded", message: self.user?.textDescription)
          }
        }
      case .reauthenticate:
        getCredential() { credential in
          self.user!.reauthenticateAndRetrieveData(with: credential) { authData, error in
            self.ifNoError(error) {
              if (authData?.user.uid != self.user?.uid) {
                let message = "The reauthenticated user must be the same as the original user"
                self.showAlert(title: "Reauthention error",
                             message: message)
                return
              }
              self.showAlert(title: "Reauthenticated", message: self.user?.textDescription)
            }
          }
        }
      case .getToken:
        user!.getIDToken() { token, error in
          self.ifNoError(error) {
            self.showAlert(title: "Got ID Token", message: token)
          }
        }
      case .linkWithCredential:
        getCredential() { credential in
          self.user!.linkAndRetrieveData(with: credential) { authData, error in
            self.ifNoError(error) {
              self.showAlert(title: "Linked With Credential",
                           message: authData?.user.textDescription)
            }
          }
        }
      case .deleteAccount:
        user!.delete() { error in
          self.ifNoError(error) {
            self.showAlert(title: "Deleted Account")
          }
        }
      }
    }
  }

  /// Gets an AuthCredential potentially asynchronously.
  private func getCredential(completion: @escaping (AuthCredential) -> Void) {
    switch credentialType {
    case .google:
      GIDSignIn.sharedInstance().delegate = GoogleSignInDelegate(completion: { user, error in
        self.ifNoError(error) {
          completion(GoogleAuthProvider.credential(
              withIDToken: user!.authentication.idToken,
              accessToken: user!.authentication.accessToken))
        }
      })
      GIDSignIn.sharedInstance().signIn()
    case .password:
      completion(EmailAuthProvider.credential(withEmail: emailField.text!,
                                              password: passwordField.text!))
    case .phone:
      let phoneNumber = phoneField.text
      self.verify(phoneNumber: phoneNumber!, completion: { (phoneAuthCredential, error) in
        guard error == nil else {
          self.showAlert(title: "Error", message: error!.localizedDescription)
          return
        }
        completion(phoneAuthCredential!)
      })
    }
  }

  /// Updates user's profile image and info text.
  private func updateUserInfo(_ auth: Auth?) {
    user = auth?.currentUser
    displayNameLabel.text = user?.displayName
    emailLabel.text = user?.email
    userIDLabel.text = user?.uid
    let providers = user?.providerData.map { userInfo in userInfo.providerID }
    providerListLabel.text = providers?.joined(separator: ", ")
    if let photoURL = user?.photoURL {
      lastPhotoURL = photoURL
      let queue: DispatchQueue
      if #available(iOS 8.0, *) {
        queue = DispatchQueue.global(qos: .background)
      } else {
        queue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.background)
      }
      queue.async {
        if let imageData = try? Data(contentsOf: photoURL) {
          let image = UIImage(data: imageData)
          DispatchQueue.main.async {
            if self.lastPhotoURL == photoURL {
              self.profileImage.image = image
            }
          }
        }
      }
    } else {
      lastPhotoURL = nil
      self.profileImage.image = nil
    }
    updateControls()
  }

  // Updates the states of the UI controls.
  fileprivate func updateControls() {
    let action: Action
    switch actionType {
    case .auth:
      action = authAction
    case .user:
      action = userAction
    }
    let isCredentialEnabled = action.requiresCredential
    credentialTypePicker.isUserInteractionEnabled = isCredentialEnabled
    credentialTypePicker.alpha = isCredentialEnabled ? 1.0 : 0.6
    let isEmailEnabled = isCredentialEnabled && credentialType.requiresEmail || action.requiresEmail
    emailInputLabel.alpha = isEmailEnabled ? 1.0 : 0.6
    emailField.isEnabled = isEmailEnabled
    let isPasswordEnabled = isCredentialEnabled && credentialType.requiresPassword ||
        action.requiresPassword
    passwordInputLabel.alpha = isPasswordEnabled ? 1.0 : 0.6
    passwordField.isEnabled = isPasswordEnabled
    phoneField.isEnabled = credentialType.requiresPhone || action.requiresPhoneNumber
  }

  fileprivate func showAlert(title: String, message: String? = "") {
    if #available(iOS 8.0, *) {
      let alertController =
          UIAlertController(title: title, message: message, preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "OK",
                                              style: .default,
                                              handler: { (UIAlertAction) in
        alertController.dismiss(animated: true, completion: nil)
      }))
      self.present(alertController, animated: true, completion: nil)
    } else {
      UIAlertView(title: title,
                  message: message ?? "(NULL)",
                  delegate: nil,
                  cancelButtonTitle: nil,
                  otherButtonTitles: "OK").show()
    }
  }

  private func ifNoError(_ error: Error?, execute: () -> Void) {
    guard error == nil else {
      showAlert(title: "Error", message: error!.localizedDescription)
      return
    }
    execute()
  }
}

extension ViewController : GIDSignInUIDelegate {
  func sign(_ signIn: GIDSignIn!, present viewController: UIViewController!) {
    present(viewController, animated: true, completion: nil)
  }

  func sign(_ signIn: GIDSignIn!, dismiss viewController: UIViewController!) {
    dismiss(animated: true, completion: nil)
  }
}

extension ViewController : UIPickerViewDataSource {
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }

  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    switch pickerView {
    case actionTypePicker:
      if Auth.auth().currentUser != nil {
        return ActionType.countWithUser
      } else {
        return ActionType.countWithoutUser
      }
    case actionPicker:
      switch actionType {
        case .auth:
          return AuthAction.count
        case .user:
          return UserAction.count
      }
    case credentialTypePicker:
      return CredentialType.count
    default:
      return 0
    }
  }
}

extension ViewController : UIPickerViewDelegate {
  func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int)
      -> String? {
    switch pickerView {
    case actionTypePicker:
      return ActionType(rawValue: row)!.text
    case actionPicker:
      switch actionType {
      case .auth:
        return AuthAction(rawValue: row)!.text
      case .user:
        return UserAction(rawValue: row)!.text
      }
    case credentialTypePicker:
      return CredentialType(rawValue: row)!.text
    default:
      return nil
    }
  }

  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    switch pickerView {
    case actionTypePicker:
      actionType = ActionType(rawValue: row)!
    case actionPicker:
      switch actionType {
      case .auth:
        authAction = AuthAction(rawValue: row)!
      case .user:
        userAction = UserAction(rawValue: row)!
      }
    case credentialTypePicker:
      credentialType = CredentialType(rawValue: row)!
    default:
      break
    }
    updateControls()
  }
}

/// An adapter class to pass GoogleSignIn delegate method to a block.
fileprivate final class GoogleSignInDelegate: NSObject, GIDSignInDelegate {

  private let completion: (GIDGoogleUser?, Error?) -> Void
  private var retainedSelf: GoogleSignInDelegate?

  init(completion: @escaping (GIDGoogleUser?, Error?) -> Void) {
    self.completion = completion
    super.init()
    retainedSelf = self
  }

  func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser?, withError error: Error?) {
    completion(user, error)
    retainedSelf = nil
  }
}

/// The list of all possible action types.
fileprivate enum ActionType: Int {

  case auth, user

  // Count of action types when no user is signed in.
  static var countWithoutUser: Int {
    return ActionType.auth.rawValue + 1
  }

  // Count of action types when a user is signed in.
  static var countWithUser: Int {
    return ActionType.user.rawValue + 1
  }

  /// The text description for a particular enum value.
  var text : String {
    switch self {
    case .auth:
      return "Auth"
    case .user:
      return "User"
    }
  }
}

fileprivate protocol Action {
  /// The text description for the particular action.
  var text: String { get }

  /// Whether or not the action requires a credential.
  var requiresCredential : Bool { get }

  /// Whether or not the action requires an email.
  var requiresEmail: Bool { get }

  /// Whether or not the credential requires a password.
  var requiresPassword: Bool { get }

  /// Whether or not the credential requires a phone number.
  var requiresPhoneNumber: Bool { get }
}

/// The list of all possible actions the operator can take on the Auth object.
fileprivate enum AuthAction: Int, Action {

  case fetchProviderForEmail, signInAnonymously, signInWithCredential, createUser, signOut

  /// Total number of auth actions.
  static var count: Int {
    return AuthAction.signOut.rawValue + 1
  }

  var text : String {
    switch self {
    case .fetchProviderForEmail:
      return "Fetch Provider ⬇️"
    case .signInAnonymously:
      return "Sign In Anonymously"
    case .signInWithCredential:
      return "Sign In w/ Credential ↙️"
    case .createUser:
      return "Create User ⬇️"
    case .signOut:
      return "Sign Out"
    }
  }

  var requiresCredential : Bool {
    return self == .signInWithCredential
  }

  var requiresEmail : Bool {
    return self == .fetchProviderForEmail || self == .createUser
  }

  var requiresPassword : Bool {
    return self == .createUser
  }

  var requiresPhoneNumber: Bool {
    return false
  }
}

/// The list of all possible actions the operator can take on the User object.
fileprivate enum UserAction: Int, Action {

  case updateEmail, updatePhone, updatePassword, reload, reauthenticate, getToken,
      linkWithCredential, deleteAccount

  /// Total number of user actions.
  static var count: Int {
    return UserAction.deleteAccount.rawValue + 1
  }

  var text : String {
    switch self {
    case .updateEmail:
      return "Update Email ⬇️"
    case .updatePhone:
      if #available(iOS 8.0, *) {
        return "Update Phone ⬇️"
      } else {
        return "-"
      }
    case .updatePassword:
      return "Update Password ⬇️"
    case .reload:
      return "Reload"
    case .reauthenticate:
      return "Reauthenticate ↙️"
    case .getToken:
      return "Get Token"
    case .linkWithCredential:
      return "Link With Credential ↙️"
    case .deleteAccount:
      return "Delete Account"
    }
  }

  var requiresCredential : Bool {
    return self == .reauthenticate ||  self == .linkWithCredential
  }

  var requiresEmail : Bool {
    return self == .updateEmail
  }

  var requiresPassword : Bool {
    return self == .updatePassword
  }

  var requiresPhoneNumber : Bool {
    return self == .updatePhone
  }

}

/// The list of all possible credential types the operator can use to sign in or link.
fileprivate enum CredentialType: Int {

  case google, password, phone

  /// Total number of enum values.
  static var count: Int {
    return CredentialType.phone.rawValue + 1
  }

  /// The text description for a particular enum value.
  var text : String {
    switch self {
    case .google:
      return "Google"
    case .password:
      return "Password ➡️️"
    case .phone:
      if #available(iOS 8.0, *) {
        return "Phone ➡️️"
      } else {
        return "-"
      }
    }
  }

  /// Whether or not the credential requires an email.
  var requiresEmail : Bool {
    return self == .password
  }

  /// Whether or not the credential requires a password.
  var requiresPassword : Bool {
    return self == .password
  }

  /// Whether or not the credential requires a phone number.
  var requiresPhone : Bool {
    return self == .phone
  }
}

fileprivate extension User {
  var textDescription: String {
    return self.displayName ?? self.email ?? self.uid
  }
}
