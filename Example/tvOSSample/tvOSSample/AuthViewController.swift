//
//  AuthViewController.swift
//  tvOSSample
//
//  Created by Ryan Wilson on 11/15/17.
//  Copyright © 2017 Firebase. All rights reserved.
//

import UIKit
import FirebaseCommunity

class AuthViewController: UIViewController {

  // MARK: - User Interface

  /// A stackview containing all of the buttons to providers (Email, OAuth, etc).
  @IBOutlet weak var providers: UIStackView!

  /// A stackview containing a signed in label and sign out button.
  @IBOutlet weak var signedIn: UIStackView!

  /// A label to display the status for the signed in user.
  @IBOutlet weak var signInStatus: UILabel!

  // MARK: - User Actions

  @IBAction func signOutButtonHit(_ sender: UIButton) {
    // Sign out via Auth and update the UI.
    try? Auth.auth().signOut()

    setUserSignedIn(nil)
  }

  // MARK: - View Controller Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    // Update the UI based on the current user (if there is one).
    setUserSignedIn(Auth.auth().currentUser)
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let destination = segue.destination
    if let emailVC = destination as? EmailLoginViewController {
      emailVC.delegate = self
    }
  }

  // MARK: - Internal Helpers

  private func setUserSignedIn(_ user: User?) {
    if let user = user {
      providers.isHidden = true
      signedIn.isHidden = false

      signInStatus.text = "User is signed in via \(user.providerID) and the UID \(user.uid)"
    } else {
      // User is signed out, hide the signed in state and show the providers.
      providers.isHidden = false
      signedIn.isHidden = true
    }
  }
}

// MARK: - EmailLoginDelegate conformance.

extension AuthViewController: EmailLoginDelegate {
  func emailLogin(_ controller: EmailLoginViewController, signedInAs user: User) {
    setUserSignedIn(user)
    dismiss(animated: true)
  }

  func emailLogin(_ controller: EmailLoginViewController, failedWithError error: Error) {
    print("Fail..... \(error)")
    DispatchQueue.main.async {
      controller.presentError(with: "There was an issue logging in. Please try again.")
    }
  }
}
