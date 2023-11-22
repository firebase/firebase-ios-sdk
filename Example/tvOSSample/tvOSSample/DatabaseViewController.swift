// Copyright 2017 Google
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

import FirebaseDatabase
import UIKit

/// A class to demonstrate the Firebase Realtime Database API. This will show a number read
/// from the Database and increase or decrease it based on the buttons pressed.
class DatabaseViewController: UIViewController {
  private enum Counter: Int {
    case increment = 1
    case decrement = -1

    var intValue: Int {
      return rawValue
    }
  }

  // MARK: - Interface

  /// Label to display the current value.
  @IBOutlet var currentValue: UILabel!

  // MARK: - User Actions

  /// The increment button was hit.
  @IBAction func incrementButtonHit(_ sender: UIButton) { changeServerValue(with: .increment) }

  /// the decrement button was hit.
  @IBAction func decrementButton(_ sender: UIButton) { changeServerValue(with: .decrement) }

  // MARK: - Internal Helpers

  /// Update the number on the server by a particular value. Note: the number passed in should only
  /// be one above or below the current number.
  private func changeServerValue(with type: Counter) {
    let ref = Database.database().reference(withPath: Constants.databasePath)
    // Update the current value of the number.
    ref.runTransactionBlock { currentData -> TransactionResult in
      guard let value = currentData.value as? Int else {
        return TransactionResult.abort()
      }

      currentData.value = value + type.intValue
      return TransactionResult.success(withValue: currentData)
    }
  }

  // MARK: - View Controller Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    // Observe the current value, and update the UI every time it changes.
    let ref = Database.database().reference(withPath: Constants.databasePath)

    ref.observe(.value) { [weak self] snapshot in
      guard let value = snapshot.value as? Int else {
        print("Error grabbing value from Snapshot!")
        return
      }

      self?.currentValue.text = "\(value)"
    }
  }

  // MARK: - Constants

  private enum Constants {
    static let databasePath = "magicSyncingCounter"
  }
}
