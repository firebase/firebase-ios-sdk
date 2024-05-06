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

// For Sign in with Facebook
import FBSDKLoginKit
@testable import FirebaseAuth

// [START auth_import]
import FirebaseCore
import GameKit

// For Sign in with Google
// [START google_import]
import GoogleSignIn
import UIKit

// For Sign in with Apple
import AuthenticationServices
import CryptoKit

private let kFacebookAppID = "ENTER APP ID HERE"

class AuthViewController: UIViewController, DataSourceProviderDelegate {
  var dataSourceProvider: DataSourceProvider<AuthMenu>!
  var authStateDidChangeListeners: [AuthStateDidChangeListenerHandle] = []
  var IDTokenDidChangeListeners: [IDTokenDidChangeListenerHandle] = []

  override func loadView() {
    view = UITableView(frame: .zero, style: .insetGrouped)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureNavigationBar()
    configureDataSourceProvider()
  }

  // MARK: - DataSourceProviderDelegate

  func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
    let item = dataSourceProvider.item(at: indexPath)

    let providerName = item.isEditable ? item.detailTitle! : item.title!

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

    case .twitter, .microsoft, .gitHub, .yahoo:
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
    let prompt = UIAlertController(title: nil, message: "Enter Custom Auth Domain For Auth:",
                                   preferredStyle: .alert)
    prompt.addTextField()
    let okAction = UIAlertAction(title: "OK", style: .default) { action in
      let domain = prompt.textFields?[0].text ?? ""
      AppManager.shared.auth().customAuthDomain = domain
      print("Successfully set auth domain to: \(domain)")
    }
    prompt.addAction(okAction)
    present(prompt, animated: true)
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

      if let tokenResult = tokenResult, let claims = tokenResult.claims as? [String: Any] {
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

  func removeIDTokenListener() {
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

  func verifyClient() {
    AppManager.shared.auth().tokenManager.getTokenInternal { token, error in
      if token == nil {
        print("Verify iOS Client failed.")
        return
      }
      let request = VerifyClientRequest(
        withAppToken: token?.string,
        isSandbox: token?.type == .sandbox,
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

  func deleteApp() {
    AppManager.shared.app.delete { success in
      if success {
        print("App deleted successfully.")
      } else {
        print("Failed to delete app.")
      }
    }
  }

  // MARK: - Private Helpers

  private func configureDataSourceProvider() {
    let tableView = view as! UITableView
    dataSourceProvider = DataSourceProvider(dataSource: AuthMenu.sections, tableView: tableView)
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
                               didCompleteWithError error: Error) {
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
