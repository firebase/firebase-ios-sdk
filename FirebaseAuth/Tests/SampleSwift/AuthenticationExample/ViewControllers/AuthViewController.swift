@testable import FirebaseAuth

// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// [START auth_import]
import FirebaseCore

// For Sign in with Facebook
import FBSDKLoginKit

// For Sign in with Game Center
import GameKit

// For Sign in with Google
// [START google_import]
import GoogleSignIn
import UIKit

// For Sign in with Apple
import AuthenticationServices
import CryptoKit

private let kFacebookAppID = "ENTER APP ID HERE"
private let kContinueUrl = "Enter URL"

class AuthViewController: UIViewController, DataSourceProviderDelegate {
  var dataSourceProvider: DataSourceProvider<AuthMenuData>!
  var authStateDidChangeListeners: [AuthStateDidChangeListenerHandle] = []
  var IDTokenDidChangeListeners: [IDTokenDidChangeListenerHandle] = []
  var actionCodeContinueURL: URL?
  var actionCodeRequestType: ActionCodeRequestType = .inApp

  let spinner = UIActivityIndicatorView(style: .medium)
  var tableView: UITableView { view as! UITableView }

  override func loadView() {
    view = UITableView(frame: .zero, style: .insetGrouped)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureNavigationBar()
    configureDataSourceProvider()
  }

  private func showSpinner() {
    spinner.center = view.center
    spinner.startAnimating()
    view.addSubview(spinner)
  }

  private func hideSpinner() {
    spinner.stopAnimating()
    spinner.removeFromSuperview()
  }

  private func actionCodeSettings() -> ActionCodeSettings {
    let settings = ActionCodeSettings()
    settings.url = actionCodeContinueURL
    settings.handleCodeInApp = (actionCodeRequestType == .inApp)
    return settings
  }

  // MARK: - DataSourceProviderDelegate

  func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
    let item = dataSourceProvider.item(at: indexPath)

    guard let providerName = item.title else {
      fatalError("Invalid item name")
    }

    guard let provider = AuthMenu(rawValue: providerName) else {
      // The row tapped has no affiliated action.
      return
    }

    switch provider {
    case .settings:
      performSettings()

    case .google:
      performGoogleSignInFlow()

    case .apple:
      performAppleSignInFlow()

    case .facebook:
      performFacebookSignInFlow()

    case .twitter, .microsoft, .gitHub, .yahoo, .linkedIn:
      performOAuthLoginFlow(for: provider)

    case .gameCenter:
      performGameCenterLoginFlow()

    case .emailPassword:
      performDemoEmailPasswordLoginFlow()

    case .passwordless:
      performPasswordlessLoginFlow()

    case .phoneNumber:
      performPhoneNumberLoginFlow()

    case .anonymous:
      performAnonymousLoginFlow()

    case .custom:
      performCustomAuthLoginFlow()

    case .initRecaptcha:
      performInitRecaptcha()

    case .customAuthDomain:
      performCustomAuthDomainFlow()

    case .getToken:
      getUserTokenResult(force: false)

    case .getTokenForceRefresh:
      getUserTokenResult(force: true)

    case .addAuthStateChangeListener:
      addAuthStateListener()

    case .removeLastAuthStateChangeListener:
      removeAuthStateListener()

    case .addIdTokenChangeListener:
      addIDTokenListener()

    case .removeLastIdTokenChangeListener:
      removeIDTokenListener()

    case .verifyClient:
      verifyClient()

    case .deleteApp:
      deleteApp()

    case .actionType:
      toggleActionCodeRequestType(at: indexPath)

    case .continueURL:
      changeActionCodeContinueURL(at: indexPath)

    case .requestVerifyEmail:
      requestVerifyEmail()

    case .requestPasswordReset:
      requestPasswordReset()

    case .resetPassword:
      resetPassword()

    case .checkActionCode:
      checkActionCode()

    case .applyActionCode:
      applyActionCode()

    case .verifyPasswordResetCode:
      verifyPasswordResetCode()

    case .phoneEnroll:
      phoneEnroll()

    case .totpEnroll:
      totpEnroll()

    case .multifactorUnenroll:
      mfaUnenroll()
    }
  }

  // MARK: - Firebase 🔥

  private func performSettings() {
    let settingsController = SettingsViewController()
    navigationController?.pushViewController(settingsController, animated: true)
  }

  private func performGoogleSignInFlow() {
    // [START headless_google_auth]
    guard let clientID = FirebaseApp.app()?.options.clientID else { return }

    // Create Google Sign In configuration object.
    // [START_EXCLUDE silent]
    // TODO: Move configuration to Info.plist
    // [END_EXCLUDE]
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    // Start the sign in flow!
    GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] result, error in
      guard error == nil else {
        // [START_EXCLUDE]
        return displayError(error)
        // [END_EXCLUDE]
      }

      guard let user = result?.user,
            let idToken = user.idToken?.tokenString
      else {
        // [START_EXCLUDE]
        let error = NSError(
          domain: "GIDSignInError",
          code: -1,
          userInfo: [
            NSLocalizedDescriptionKey: "Unexpected sign in result: required authentication data is missing.",
          ]
        )
        return displayError(error)
        // [END_EXCLUDE]
      }

      let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                     accessToken: user.accessToken.tokenString)

      // [START_EXCLUDE]
      signIn(with: credential)
      // [END_EXCLUDE]
    }
    // [END headless_google_auth]
  }

  func signIn(with credential: AuthCredential) {
    // [START signin_google_credential]
    AppManager.shared.auth().signIn(with: credential) { result, error in
      // [START_EXCLUDE silent]
      guard error == nil else { return self.displayError(error) }
      // [END_EXCLUDE]

      // At this point, our user is signed in
      // [START_EXCLUDE silent]
      // so we advance to the User View Controller
      self.transitionToUserViewController()
      // [END_EXCLUDE]
    }
    // [END signin_google_credential]
  }

  // For Sign in with Apple
  var currentNonce: String?

  private func performAppleSignInFlow() {
    do {
      let nonce = try CryptoUtils.randomNonceString()
      currentNonce = nonce
      let appleIDProvider = ASAuthorizationAppleIDProvider()
      let request = appleIDProvider.createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = CryptoUtils.sha256(nonce)

      let authorizationController = ASAuthorizationController(authorizationRequests: [request])
      authorizationController.delegate = self
      authorizationController.presentationContextProvider = self
      authorizationController.performRequests()
    } catch {
      // In the unlikely case that nonce generation fails, show error view.
      displayError(error)
    }
  }

  private func performFacebookSignInFlow() {
    // The following config can also be stored in the project's .plist
    Settings.shared.appID = kFacebookAppID
    Settings.shared.displayName = "AuthenticationExample"

    // Create a Facebook `LoginManager` instance
    let loginManager = LoginManager()
    loginManager.logIn(permissions: ["email"], from: self) { result, error in
      guard error == nil else { return self.displayError(error) }
      guard let accessToken = AccessToken.current else { return }
      let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
      self.signin(with: credential)
    }
  }

  // Maintain a strong reference to an OAuthProvider for login
  private var oauthProvider: OAuthProvider!

  private func performOAuthLoginFlow(for provider: AuthMenu) {
    oauthProvider = OAuthProvider(providerID: provider.id)
    oauthProvider.getCredentialWith(nil) { credential, error in
      guard error == nil else { return self.displayError(error) }
      guard let credential = credential else { return }
      self.signin(with: credential)
    }
  }

  private func performGameCenterLoginFlow() {
    // Step 1: System Game Center Login
    GKLocalPlayer.local.authenticateHandler = { viewController, error in
      if let error = error {
        // Handle Game Center login error
        print("Error logging into Game Center: \(error.localizedDescription)")
      } else if let authViewController = viewController {
        // Present Game Center login UI if needed
        self.present(authViewController, animated: true)
      } else {
        // Game Center login successful, proceed to Firebase
        self.linkGameCenterToFirebase()
      }
    }
  }

  // Step 2: Link to Firebase
  private func linkGameCenterToFirebase() {
    GameCenterAuthProvider.getCredential { credential, error in
      if let error = error {
        // Handle Firebase credential retrieval error
        print("Error getting Game Center credential: \(error.localizedDescription)")
      } else if let credential = credential {
        Auth.auth().signIn(with: credential) { authResult, error in
          if let error = error {
            // Handle Firebase sign-in error
            print("Error signing into Firebase with Game Center: \(error.localizedDescription)")
          } else {
            // Firebase sign-in successful
            print("Successfully linked Game Center to Firebase")
          }
        }
      }
    }
  }

  private func performDemoEmailPasswordLoginFlow() {
    let loginController = LoginController()
    loginController.delegate = self
    navigationController?.pushViewController(loginController, animated: true)
  }

  private func performPasswordlessLoginFlow() {
    let passwordlessViewController = PasswordlessViewController()
    passwordlessViewController.delegate = self
    let navPasswordlessAuthController =
      UINavigationController(rootViewController: passwordlessViewController)
    navigationController?.present(navPasswordlessAuthController, animated: true)
  }

  private func performPhoneNumberLoginFlow() {
    let phoneAuthViewController = PhoneAuthViewController()
    phoneAuthViewController.delegate = self
    let navPhoneAuthController = UINavigationController(rootViewController: phoneAuthViewController)
    navigationController?.present(navPhoneAuthController, animated: true)
  }

  private func performAnonymousLoginFlow() {
    AppManager.shared.auth().signInAnonymously { result, error in
      guard error == nil else { return self.displayError(error) }
      self.transitionToUserViewController()
    }
  }

  private func performCustomAuthLoginFlow() {
    let customAuthController = CustomAuthViewController()
    customAuthController.delegate = self
    let navCustomAuthController = UINavigationController(rootViewController: customAuthController)
    navigationController?.present(navCustomAuthController, animated: true)
  }

  private func signin(with credential: AuthCredential) {
    AppManager.shared.auth().signIn(with: credential) { result, error in
      guard error == nil else { return self.displayError(error) }
      self.transitionToUserViewController()
    }
  }

  private func performInitRecaptcha() {
    Task {
      do {
        try await AppManager.shared.auth().initializeRecaptchaConfig()
        print("Initializing Recaptcha config succeeded.")
      } catch {
        print("Initializing Recaptcha config failed: \(error).")
      }
    }
  }

  private func performCustomAuthDomainFlow() {
    showTextInputPrompt(with: "Enter Custom Auth Domain For Auth: ", completion: { newDomain in
      AppManager.shared.auth().customAuthDomain = newDomain
    })
  }

  private func getUserTokenResult(force: Bool) {
    guard let currentUser = Auth.auth().currentUser else {
      print("Error: No user logged in")
      return
    }

    currentUser.getIDTokenResult(forcingRefresh: force, completion: { tokenResult, error in
      if error != nil {
        print("Error: Error refreshing token")
        return // Handle error case, returning early
      }

      if let tokenResult = tokenResult {
        let claims = tokenResult.claims
        var message = "Token refresh succeeded\n\n"
        for (key, value) in claims {
          message += "\(key): \(value)\n"
        }
        self.displayInfo(title: "Info", message: message, style: .alert)
      } else {
        print("Error: Unable to access claims.")
      }
    })
  }

  private func addAuthStateListener() {
    weak var weakSelf = self
    let index = authStateDidChangeListeners.count
    print("Auth State Did Change Listener #\(index) was added.")
    let handle = Auth.auth().addStateDidChangeListener { [weak weakSelf] auth, user in
      guard weakSelf != nil else { return }
      print("Auth State Did Change Listener #\(index) was invoked on user '\(user?.uid ?? "nil")'")
    }
    authStateDidChangeListeners.append(handle)
  }

  private func removeAuthStateListener() {
    guard !authStateDidChangeListeners.isEmpty else {
      print("No remaining Auth State Did Change Listeners.")
      return
    }
    let index = authStateDidChangeListeners.count - 1
    let handle = authStateDidChangeListeners.last!
    Auth.auth().removeStateDidChangeListener(handle)
    authStateDidChangeListeners.removeLast()
    print("Auth State Did Change Listener #\(index) was removed.")
  }

  private func addIDTokenListener() {
    weak var weakSelf = self
    let index = IDTokenDidChangeListeners.count
    print("ID Token Did Change Listener #\(index) was added.")
    let handle = Auth.auth().addIDTokenDidChangeListener { [weak weakSelf] auth, user in
      guard weakSelf != nil else { return }
      print("ID Token Did Change Listener #\(index) was invoked on user '\(user?.uid ?? "")'.")
    }
    IDTokenDidChangeListeners.append(handle)
  }

  private func removeIDTokenListener() {
    guard !IDTokenDidChangeListeners.isEmpty else {
      print("No remaining ID Token Did Change Listeners.")
      return
    }
    let index = IDTokenDidChangeListeners.count - 1
    let handle = IDTokenDidChangeListeners.last!
    Auth.auth().removeIDTokenDidChangeListener(handle)
    IDTokenDidChangeListeners.removeLast()
    print("ID Token Did Change Listener #\(index) was removed.")
  }

  private func verifyClient() {
    AppManager.shared.auth().tokenManager.getTokenInternal { result in
      guard case let .success(token) = result else {
        print("Verify iOS Client failed.")
        return
      }
      let request = VerifyClientRequest(
        withAppToken: token.string,
        isSandbox: token.type == .sandbox,
        requestConfiguration: AppManager.shared.auth().requestConfiguration
      )

      Task {
        do {
          let verifyResponse = try await AuthBackend.call(with: request)

          guard let receipt = verifyResponse.receipt,
                let timeoutDate = verifyResponse.suggestedTimeOutDate else {
            print("Internal Auth Error: invalid VerifyClientResponse.")
            return
          }

          let timeout = timeoutDate.timeIntervalSinceNow
          do {
            let credential = await AppManager.shared.auth().appCredentialManager
              .didStartVerification(
                withReceipt: receipt,
                timeout: timeout
              )

            guard credential.secret != nil else {
              print("Failed to receive remote notification to verify App ID.")
              return
            }

            let testPhoneNumber = "+16509964692"
            let request = SendVerificationCodeRequest(
              phoneNumber: testPhoneNumber,
              codeIdentity: CodeIdentity.credential(credential),
              requestConfiguration: AppManager.shared.auth().requestConfiguration
            )

            do {
              _ = try await AuthBackend.call(with: request)
              print("Verify iOS client succeeded")
            } catch {
              print("Verify iOS Client failed: \(error.localizedDescription)")
            }
          }
        } catch {
          print("Verify iOS Client failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func deleteApp() {
    AppManager.shared.app.delete { success in
      if success {
        print("App deleted successfully.")
      } else {
        print("Failed to delete app.")
      }
    }
  }

  private func toggleActionCodeRequestType(at indexPath: IndexPath) {
    switch actionCodeRequestType {
    case .inApp:
      actionCodeRequestType = .continue
    case .continue:
      actionCodeRequestType = .email
    case .email:
      actionCodeRequestType = .inApp
    }
    dataSourceProvider.updateItem(
      at: indexPath,
      item: Item(title: AuthMenu.actionType.name, detailTitle: actionCodeRequestType.name)
    )
    tableView.reloadData()
  }

  private func changeActionCodeContinueURL(at indexPath: IndexPath) {
    showTextInputPrompt(with: "Continue URL:", completion: { newContinueURL in
      self.actionCodeContinueURL = URL(string: newContinueURL)
      print("Successfully set Continue URL  to: \(newContinueURL)")
      self.dataSourceProvider.updateItem(
        at: indexPath,
        item: Item(
          title: AuthMenu.continueURL.name,
          detailTitle: self.actionCodeContinueURL?.absoluteString,
          isEditable: true
        )
      )
      self.tableView.reloadData()
    })
  }

  private func requestVerifyEmail() {
    showSpinner()
    let completionHandler: ((any Error)?) -> Void = { [weak self] error in
      guard let self = self else { return }
      self.hideSpinner()

      if let error = error {
        let errorMessage = "Error sending verification email: \(error.localizedDescription)"
        showAlert(for: errorMessage)
        print(errorMessage)
      } else {
        let successMessage = "Verification email sent successfully!"
        showAlert(for: successMessage)
        print(successMessage)
      }
    }
    if actionCodeRequestType == .email {
      AppManager.shared.auth().currentUser?.sendEmailVerification(completion: completionHandler)
    } else {
      if actionCodeContinueURL == nil {
        print("Error: Action code continue URL is nil.")
        return
      }
      AppManager.shared.auth().currentUser?.sendEmailVerification(
        with: actionCodeSettings(),
        completion: completionHandler
      )
    }
  }

  func requestPasswordReset() {
    showTextInputPrompt(with: "Email:", completion: { email in
      print("Sending password reset link to: \(email)")
      self.showSpinner()
      let completionHandler: ((any Error)?) -> Void = { [weak self] error in
        guard let self = self else { return }
        self.hideSpinner()
        if let error = error {
          print("Request password reset failed: \(error)")
          showAlert(for: error.localizedDescription)
          return
        }
        print("Request password reset succeeded.")
        showAlert(for: "Sent!")
      }
      if self.actionCodeRequestType == .email {
        AppManager.shared.auth().sendPasswordReset(withEmail: email, completion: completionHandler)
      } else {
        guard self.actionCodeContinueURL != nil else {
          print("Error: Action code continue URL is nil.")
          return
        }
        AppManager.shared.auth().sendPasswordReset(
          withEmail: email,
          actionCodeSettings: self.actionCodeSettings(),
          completion: completionHandler
        )
      }
    })
  }

  private func resetPassword() {
    showSpinner()
    let completionHandler: ((any Error)?) -> Void = { [weak self] error in
      guard let self = self else { return }
      self.hideSpinner()
      if let error = error {
        print("Password reset failed \(error)")
        showAlert(for: error.localizedDescription)
        return
      }
      print("Password reset succeeded")
      showAlert(for: "Password reset succeeded!")
    }
    showTextInputPrompt(with: "OOB Code:") {
      code in
      self.showTextInputPrompt(with: "New Password") {
        password in
        AppManager.shared.auth().confirmPasswordReset(
          withCode: code,
          newPassword: password,
          completion: completionHandler
        )
      }
    }
  }

  private func nameForActionCodeOperation(_ operation: ActionCodeOperation) -> String {
    switch operation {
    case .verifyEmail:
      return "Verify Email"
    case .recoverEmail:
      return "Recover Email"
    case .passwordReset:
      return "Password Reset"
    case .emailLink:
      return "Email Sign-In Link"
    case .verifyAndChangeEmail:
      return "Verify Before Change Email"
    case .revertSecondFactorAddition:
      return "Revert Second Factor Addition"
    case .unknown:
      return "Unknown action"
    }
  }

  private func checkActionCode() {
    showSpinner()
    let completionHandler: (ActionCodeInfo?, (any Error)?) -> Void = { [weak self] info, error in
      guard let self = self else { return }
      self.hideSpinner()
      if let error = error {
        print("Check action code failed: \(error)")
        showAlert(for: error.localizedDescription)
        return
      }
      guard let info = info else { return }
      print("Check action code succeeded")
      let email = info.email
      let previousEmail = info.previousEmail
      let operation = self.nameForActionCodeOperation(info.operation)
      showAlert(for: operation, message: previousEmail ?? email)
    }
    showTextInputPrompt(with: "OOB Code:") {
      oobCode in
      AppManager.shared.auth().checkActionCode(oobCode, completion: completionHandler)
    }
  }

  private func applyActionCode() {
    showSpinner()
    let completionHandler: ((any Error)?) -> Void = { [weak self] error in
      guard let self = self else { return }
      self.hideSpinner()
      if let error = error {
        print("Apply action code failed \(error)")
        showAlert(for: error.localizedDescription)
        return
      }
      print("Apply action code succeeded")
      showAlert(for: "Action code was properly applied")
    }
    showTextInputPrompt(with: "OOB Code: ") {
      oobCode in
      AppManager.shared.auth().applyActionCode(oobCode, completion: completionHandler)
    }
  }

  private func verifyPasswordResetCode() {
    showSpinner()
    let completionHandler: (String?, (any Error)?) -> Void = { [weak self] email, error in
      guard let self = self else { return }
      self.hideSpinner()
      if let error = error {
        print("Verify password reset code failed \(error)")
        showAlert(for: error.localizedDescription)
        return
      }
      print("Verify password resest code succeeded.")
      showAlert(for: "Code verified for email: \(email ?? "missing email")")
    }
    showTextInputPrompt(with: "OOB Code: ") {
      oobCode in
      AppManager.shared.auth().verifyPasswordResetCode(oobCode, completion: completionHandler)
    }
  }

  private func phoneEnroll() {
    guard let user = AppManager.shared.auth().currentUser else {
      showAlert(for: "No user logged in!")
      print("Error: User must be logged in first.")
      return
    }

    showTextInputPrompt(with: "Phone Number:") { phoneNumber in
      user.multiFactor.getSessionWithCompletion { session, error in
        guard let session = session else { return }
        guard error == nil else {
          self.showAlert(for: "Enrollment failed")
          print("Multi factor start enroll failed. Error: \(error!)")
          return
        }

        PhoneAuthProvider.provider()
          .verifyPhoneNumber(phoneNumber, multiFactorSession: session) { verificationID, error in
            guard error == nil else {
              self.showAlert(for: "Enrollment failed")
              print("Multi factor start enroll failed. Error: \(error!)")
              return
            }

            self.showTextInputPrompt(with: "Verification Code: ") { verificationCode in
              let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID!,
                verificationCode: verificationCode
              )
              let assertion = PhoneMultiFactorGenerator.assertion(with: credential)

              self.showTextInputPrompt(with: "Display Name:") { displayName in
                user.multiFactor.enroll(with: assertion, displayName: displayName) { error in
                  if let error = error {
                    self.showAlert(for: "Enrollment failed")
                    print("Multi factor finalize enroll failed. Error: \(error)")
                  } else {
                    self.showAlert(for: "Successfully enrolled: \(displayName)")
                    print("Multi factor finalize enroll succeeded.")
                  }
                }
              }
            }
          }
      }
    }
  }

  private func totpEnroll() {
    guard let user = AppManager.shared.auth().currentUser else {
      print("Error: User must be logged in first.")
      return
    }

    user.multiFactor.getSessionWithCompletion { session, error in
      guard let session = session, error == nil else {
        if let error = error {
          self.showAlert(for: "Enrollment failed")
          print("Multi factor start enroll failed. Error: \(error.localizedDescription)")
        } else {
          self.showAlert(for: "Enrollment failed")
          print("Multi factor start enroll failed with unknown error.")
        }
        return
      }

      TOTPMultiFactorGenerator.generateSecret(with: session) { secret, error in
        guard let secret = secret, error == nil else {
          if let error = error {
            self.showAlert(for: "Enrollment failed")
            print("Error generating TOTP secret. Error: \(error.localizedDescription)")
          } else {
            self.showAlert(for: "Enrollment failed")
            print("Error generating TOTP secret.")
          }
          return
        }

        guard let accountName = user.email, let issuer = Auth.auth().app?.name else {
          self.showAlert(for: "Enrollment failed")
          print("Multi factor finalize enroll failed. Could not get account details.")
          return
        }

        DispatchQueue.main.async {
          let url = secret.generateQRCodeURL(withAccountName: accountName, issuer: issuer)

          guard !url.isEmpty else {
            self.showAlert(for: "Enrollment failed")
            print("Multi factor finalize enroll failed. Could not generate URL.")
            return
          }

          secret.openInOTPApp(withQRCodeURL: url)

          self
            .showQRCodePromptWithTextInput(with: "Scan this QR code and enter OTP:",
                                           url: url) { oneTimePassword in
              guard !oneTimePassword.isEmpty else {
                self.showAlert(for: "Display name must not be empty")
                print("OTP not entered.")
                return
              }

              let assertion = TOTPMultiFactorGenerator.assertionForEnrollment(
                with: secret,
                oneTimePassword: oneTimePassword
              )

              self.showTextInputPrompt(with: "Display Name") { displayName in
                guard !displayName.isEmpty else {
                  self.showAlert(for: "Display name must not be empty")
                  print("Display name not entered.")
                  return
                }

                user.multiFactor.enroll(with: assertion, displayName: displayName) { error in
                  if let error = error {
                    self.showAlert(for: "Enrollment failed")
                    print(
                      "Multi factor finalize enroll failed. Error: \(error.localizedDescription)"
                    )
                  } else {
                    self.showAlert(for: "Successfully enrolled: \(displayName)")
                    print("Multi factor finalize enroll succeeded.")
                  }
                }
              }
            }
        }
      }
    }
  }

  func mfaUnenroll() {
    var displayNames: [String] = []

    guard let currentUser = Auth.auth().currentUser else {
      print("Error: No current user")
      return
    }

    for factorInfo in currentUser.multiFactor.enrolledFactors {
      if let displayName = factorInfo.displayName {
        displayNames.append(displayName)
      }
    }

    let alertController = UIAlertController(
      title: "Select Multi Factor to Unenroll",
      message: nil,
      preferredStyle: .actionSheet
    )

    for displayName in displayNames {
      let action = UIAlertAction(title: displayName, style: .default) { _ in
        self.unenrollFactor(with: displayName)
      }
      alertController.addAction(action)
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    alertController.addAction(cancelAction)

    present(alertController, animated: true, completion: nil)
  }

  private func unenrollFactor(with displayName: String) {
    guard let currentUser = Auth.auth().currentUser else {
      showAlert(for: "User must be logged in")
      print("Error: No current user")
      return
    }

    var factorInfoToUnenroll: MultiFactorInfo?

    for factorInfo in currentUser.multiFactor.enrolledFactors {
      if factorInfo.displayName == displayName {
        factorInfoToUnenroll = factorInfo
        break
      }
    }

    if let factorInfo = factorInfoToUnenroll {
      currentUser.multiFactor.unenroll(withFactorUID: factorInfo.uid) { error in
        if let error = error {
          self.showAlert(for: "Failed to unenroll factor: \(displayName)")
          print("Multi factor unenroll failed. Error: \(error.localizedDescription)")
        } else {
          self.showAlert(for: "Successfully unenrolled: \(displayName)")
          print("Multi factor unenroll succeeded.")
        }
      }
    }
  }

  // MARK: - Private Helpers

  private func showTextInputPrompt(with message: String, completion: ((String) -> Void)? = nil) {
    let editController = UIAlertController(
      title: message,
      message: nil,
      preferredStyle: .alert
    )
    editController.addTextField()

    let saveHandler: (UIAlertAction) -> Void = { _ in
      let text = editController.textFields?.first?.text ?? ""
      if let completion {
        completion(text)
      }
    }

    let cancelHandler: (UIAlertAction) -> Void = { _ in
      if let completion {
        completion("")
      }
    }

    editController.addAction(UIAlertAction(title: "Save", style: .default, handler: saveHandler))
    editController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: cancelHandler))

    // Assuming `self` is a view controller
    present(editController, animated: true, completion: nil)
  }

  private func showQRCodePromptWithTextInput(with message: String, url: String,
                                             completion: ((String) -> Void)? = nil) {
    // Create a UIAlertController
    let alertController = UIAlertController(
      title: "QR Code Prompt",
      message: message,
      preferredStyle: .alert
    )

    // Add a text field for input
    alertController.addTextField { textField in
      textField.placeholder = "Enter text"
    }

    // Create a UIImage from the URL
    guard let image = generateQRCode(from: url) else {
      print("Failed to generate QR code")
      return
    }

    // Create an image view to display the QR code
    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false

    // Add the image view to the alert controller
    alertController.view.addSubview(imageView)

    // Add constraints to position the image view
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: alertController.view.topAnchor, constant: 20),
      imageView.centerXAnchor.constraint(equalTo: alertController.view.centerXAnchor),
      imageView.widthAnchor.constraint(equalToConstant: 200),
      imageView.heightAnchor.constraint(equalToConstant: 200),
    ])

    // Add actions
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    let submitAction = UIAlertAction(title: "Submit", style: .default) { _ in
      if let completion,
         let text = alertController.textFields?.first?.text {
        completion(text)
      }
    }

    alertController.addAction(cancelAction)
    alertController.addAction(submitAction)

    // Present the alert controller
    UIApplication.shared.windows.first?.rootViewController?.present(
      alertController,
      animated: true,
      completion: nil
    )
  }

  // Function to generate QR code from a string
  private func generateQRCode(from string: String) -> UIImage? {
    let data = string.data(using: String.Encoding.ascii)

    if let filter = CIFilter(name: "CIQRCodeGenerator") {
      filter.setValue(data, forKey: "inputMessage")
      let transform = CGAffineTransform(scaleX: 10, y: 10)

      if let output = filter.outputImage?.transformed(by: transform) {
        return UIImage(ciImage: output)
      }
    }

    return nil
  }

  func showAlert(for title: String, message: String? = nil) {
    let alertController = UIAlertController(
      title: message,
      message: nil,
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default))
  }

  private func configureDataSourceProvider() {
    dataSourceProvider = DataSourceProvider(
      dataSource: AuthMenuData.sections,
      tableView: tableView
    )
    dataSourceProvider.delegate = self
  }

  private func configureNavigationBar() {
    navigationItem.title = "Firebase Auth"
    guard let navigationBar = navigationController?.navigationBar else { return }
    navigationBar.prefersLargeTitles = true
    navigationBar.titleTextAttributes = [.foregroundColor: UIColor.systemOrange]
    navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.systemOrange]
  }

  private func transitionToUserViewController() {
    // UserViewController is at index 1 in the tabBarController.viewControllers array
    tabBarController?.transitionToViewController(atIndex: 1)
  }
}

// MARK: - LoginDelegate

extension AuthViewController: LoginDelegate {
  public func loginDidOccur() {
    transitionToUserViewController()
  }
}

// MARK: - Implementing Sign in with Apple with Firebase

extension AuthViewController: ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding {
  // MARK: ASAuthorizationControllerDelegate

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
    else {
      print("Unable to retrieve AppleIDCredential")
      return
    }

    guard let nonce = currentNonce else {
      fatalError("Invalid state: A login callback was received, but no login request was sent.")
    }

    guard let appleIDToken = appleIDCredential.identityToken else {
      print("Unable to fetch identity token")
      return
    }
    guard let appleAuthCode = appleIDCredential.authorizationCode else {
      print("Unable to fetch authorization code")
      return
    }
    guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
      print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
      return
    }

    guard let _ = String(data: appleAuthCode, encoding: .utf8) else {
      print("Unable to serialize auth code string from data: \(appleAuthCode.debugDescription)")
      return
    }

    // use this call to create the authentication credential and set the user's full name
    let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                   rawNonce: nonce,
                                                   fullName: appleIDCredential.fullName)

    AppManager.shared.auth().signIn(with: credential) { result, error in
      // Error. If error.code == .MissingOrInvalidNonce, make sure
      // you're sending the SHA256-hashed nonce as a hex string with
      // your request to Apple.
      guard error == nil else { return self.displayError(error) }

      // At this point, our user is signed in
      // so we advance to the User View Controller
      self.transitionToUserViewController()
    }
  }

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithError error: any Error) {
    // Ensure that you have:
    //  - enabled `Sign in with Apple` on the Firebase console
    //  - added the `Sign in with Apple` capability for this project
    print("Sign in with Apple failed: \(error)")
  }

  // MARK: ASAuthorizationControllerPresentationContextProviding

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return view.window!
  }
}
