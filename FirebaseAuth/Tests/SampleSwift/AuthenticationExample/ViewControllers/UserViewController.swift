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

import AuthenticationServices
import CryptoKit
import FirebaseAuth
import UIKit

class UserViewController: UIViewController, DataSourceProviderDelegate {
  var dataSourceProvider: DataSourceProvider<User>!

  var userImage = UIImageView(systemImageName: "person.circle.fill", tintColor: .secondaryLabel)
  var tableView: UITableView { view as! UITableView }

  private var _user: User?
  var user: User? {
    get { _user ?? AppManager.shared.auth().currentUser }
    set { _user = newValue }
  }

  /// Init allows for injecting a `User` instance during UI Testing
  /// - Parameter user: A Firebase User instance
  init(_ user: User? = nil) {
    super.init(nibName: nil, bundle: nil)
    self.user = user
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - UIViewController Life Cycle

  override func loadView() {
    view = UITableView(frame: .zero, style: .insetGrouped)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureNavigationBar()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureDataSourceProvider()
    updateUserImage()
  }

  // MARK: - DataSourceProviderDelegate

  func tableViewDidScroll(_ tableView: UITableView) {
    adjustUserImageAlpha(tableView.contentOffset.y)
  }

  func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
    let item = dataSourceProvider.item(at: indexPath)
    let actionName = item.isEditable ? item.detailTitle! : item.title!

    guard let action = UserAction(rawValue: actionName) else {
      // The row tapped has no affiliated action.
      return
    }

    switch action {
    case .signOut:
      signCurrentUserOut()

    case .link:
      linkUserToOtherAuthProviders()

    case .requestVerifyEmail:
      requestVerifyEmail()

    case .tokenRefresh:
      refreshCurrentUserIDToken()

    case .tokenRefreshAsync:
      refreshCurrentUserIDTokenAsync()

    case .delete:
      deleteCurrentUser()

    case .updateEmail:
      presentEditUserInfoController(for: actionName, to: updateUserEmail)

    case .updatePassword:
      presentEditUserInfoController(for: actionName, to: updatePassword)

    case .updateDisplayName:
      presentEditUserInfoController(for: actionName, to: updateUserDisplayName)

    case .updatePhotoURL:
      presentEditUserInfoController(for: actionName, to: updatePhotoURL)

    case .updatePhoneNumber:
      presentEditUserInfoController(
        for: actionName + " formatted like +16509871234",
        to: updatePhoneNumber
      )

    case .refreshUserInfo:
      refreshUserInfo()
    }
  }

  // MARK: - Firebase 🔥

  public func signCurrentUserOut() {
    try? AppManager.shared.auth().signOut()
    updateUI()
  }

  public func linkUserToOtherAuthProviders() {
    guard let user = user else { return }
    let accountLinkingController = AccountLinkingViewController(for: user)
    let navController = UINavigationController(rootViewController: accountLinkingController)
    navigationController?.present(navController, animated: true, completion: nil)
  }

  public func requestVerifyEmail() {
    user?.sendEmailVerification { error in
      guard error == nil else { return self.displayError(error) }
      print("Verification email sent!")
    }
  }

  public func refreshCurrentUserIDToken() {
    let forceRefresh = true
    user?.getIDTokenForcingRefresh(forceRefresh) { token, error in
      guard error == nil else { return self.displayError(error) }
      if let token = token {
        print("New token: \(token)")
      }
    }
  }

  public func refreshCurrentUserIDTokenAsync() {
    Task {
      do {
        let token = try await user!.idTokenForcingRefresh(true)
        print("New token: \(token)")
      } catch {
        self.displayError(error)
      }
    }
  }

  public func refreshUserInfo() {
    user?.reload { error in
      if let error = error {
        print(error)
      }
      self.updateUI()
    }
  }

  public func updateUserDisplayName(to newDisplayName: String) {
    let changeRequest = user?.createProfileChangeRequest()
    changeRequest?.displayName = newDisplayName
    changeRequest?.commitChanges { error in
      guard error == nil else { return self.displayError(error) }
      self.updateUI()
    }
  }

  public func updateUserEmail(to newEmail: String) {
    user?.updateEmail(to: newEmail, completion: { error in
      guard error == nil else { return self.displayError(error) }
      self.updateUI()
    })
  }

  public func updatePassword(to newPassword: String) {
    user?.updatePassword(to: newPassword, completion: {
      error in
      if let error = error {
        print("Update password failed. \(error)", error)
        return
      } else {
        print("Password updated!")
      }
      self.updateUI()
    })
  }

  public func updatePhotoURL(to newPhotoURL: String) {
    guard let newPhotoURL = URL(string: newPhotoURL) else {
      print("Could not create new photo URL!")
      return
    }
    let changeRequest = user?.createProfileChangeRequest()
    changeRequest?.photoURL = newPhotoURL
    changeRequest?.commitChanges { error in
      guard error == nil else { return self.displayError(error) }
      self.updateUI()
    }
  }

  public func updatePhoneNumber(to newPhoneNumber: String) {
    Task {
      do {
        let phoneAuthProvider = PhoneAuthProvider.provider()
        let verificationID = try await phoneAuthProvider.verifyPhoneNumber(newPhoneNumber)
        let verificationCode = try await getVerificationCode()
        let credential = phoneAuthProvider.credential(withVerificationID: verificationID,
                                                      verificationCode: verificationCode)
        try await user?.updatePhoneNumber(credential)
        self.updateUI()
      } catch {
        self.displayError(error)
      }
    }
  }

  // MARK: - Sign in with Apple Token Revocation Flow

  /// Used for Sign in with Apple token revocation flow.
  private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

  private func deleteCurrentUser() {
    Task {
      guard let user else { return }
      do {
        let needsTokenRevocation = user.providerData
          .contains { $0.providerID == AuthProviderID.apple.rawValue }
        if needsTokenRevocation {
          let appleIDCredential = try await signInWithApple()

          guard let appleIDToken = appleIDCredential.identityToken else {
            print("Unable to fetch identify token.")
            return
          }
          guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialise token string from data: \(appleIDToken.debugDescription)")
            return
          }

          let nonce = try CryptoUtils.randomNonceString()
          let credential = OAuthProvider.credential(providerID: .apple,
                                                    idToken: idTokenString,
                                                    rawNonce: nonce)

          try await user.reauthenticate(with: credential)
          if
            let authorizationCode = appleIDCredential.authorizationCode,
            let authCodeString = String(data: authorizationCode, encoding: .utf8) {
            try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
          }
        }
        try await user.delete()
      } catch {
        displayError(error)
      }
    }
  }

  // MARK: - Private Helpers

  private func getVerificationCode() async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      self.presentEditUserInfoController(for: "Phone Auth Verification Code") { code in
        if code != "" {
          continuation.resume(returning: code)
        } else {
          // Cancelled
          continuation.resume(throwing: NSError())
        }
      }
    }
  }

  private func configureNavigationBar() {
    navigationItem.title = "User"
    guard let navigationBar = navigationController?.navigationBar else { return }
    navigationBar.prefersLargeTitles = true
    navigationBar.titleTextAttributes = [.foregroundColor: UIColor.systemOrange]
    navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.systemOrange]
    navigationBar.addProfilePic(userImage)
  }

  private func updateUserImage() {
    guard let photoURL = user?.photoURL else {
      let defaultImage = UIImage(systemName: "person.circle.fill")
      userImage.image = defaultImage?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
      return
    }
    userImage.setImage(from: photoURL)
  }

  private func configureDataSourceProvider() {
    dataSourceProvider = DataSourceProvider(
      dataSource: user?.sections,
      emptyStateView: SignedOutView(),
      tableView: tableView
    )
    dataSourceProvider.delegate = self
  }

  private func updateUI() {
    configureDataSourceProvider()
    animateUpdates(for: tableView)
    updateUserImage()
  }

  private func animateUpdates(for tableView: UITableView) {
    UIView.transition(with: tableView, duration: 0.2,
                      options: .transitionCrossDissolve,
                      animations: { tableView.reloadData() })
  }

  private func presentEditUserInfoController(for title: String,
                                             to saveHandler: @escaping (String) -> Void) {
    let editController = UIAlertController(
      title: "Update \(title)",
      message: nil,
      preferredStyle: .alert
    )
    editController.addTextField { $0.placeholder = "New \(title)" }

    let saveHandler1: (UIAlertAction) -> Void = { _ in
      let text = editController.textFields!.first!.text!
      saveHandler(text)
    }

    let cancel: (UIAlertAction) -> Void = { _ in
      saveHandler("")
    }

    editController.addAction(UIAlertAction(title: "Save", style: .default, handler: saveHandler1))
    editController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: cancel))
    present(editController, animated: true, completion: nil)
  }

  private var originalOffset: CGFloat?

  private func adjustUserImageAlpha(_ offset: CGFloat) {
    originalOffset = originalOffset ?? offset
    let verticalOffset = offset - originalOffset!
    userImage.alpha = 1 - (verticalOffset * 0.05)
  }
}

// MARK: - Implementing Sign in with Apple for the Token Revocation Flow

extension UserViewController: ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding {
  // MARK: ASAuthorizationControllerDelegate

  func signInWithApple() async throws -> ASAuthorizationAppleIDCredential {
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let appleIDProvider = ASAuthorizationAppleIDProvider()
      let request = appleIDProvider.createRequest()
      request.requestedScopes = [.fullName, .email]

      let authorizationController = ASAuthorizationController(authorizationRequests: [request])
      authorizationController.delegate = self
      authorizationController.performRequests()
    }
  }

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithAuthorization authorization: ASAuthorization) {
    if case let appleIDCredential as ASAuthorizationAppleIDCredential = authorization.credential {
      continuation?.resume(returning: appleIDCredential)
    } else {
      fatalError("Unexpected authorization credential type.")
    }
  }

  func authorizationController(controller: ASAuthorizationController,
                               didCompleteWithError error: Error) {
    continuation?.resume(throwing: error)
  }

  // MARK: ASAuthorizationControllerPresentationContextProviding

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return view.window!
  }
}
