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

import FirebaseStorage
import UIKit

class StorageViewController: UIViewController {
  /// An enum describing the different states of the view controller.
  private enum UIState: Equatable {
    /// No image is being shown, waiting on user action.
    case cleared

    /// Currently downloading from Firebase.
    case downloading(StorageTask)

    /// The image has downloaded and should be displayed.
    case downloaded(UIImage)

    /// Show an error message and stop downloading.
    case failed(String)

    /// Equatable support for UIState.
    static func == (lhs: StorageViewController.UIState,
                    rhs: StorageViewController.UIState) -> Bool {
      switch (lhs, rhs) {
      case (.cleared, .cleared): return true
      case (.downloading, .downloading): return true
      case (.downloaded, .downloaded): return true
      case (.failed, .failed): return true
      default: return false
      }
    }
  }

  // MARK: - Properties

  /// The current internal state of the view controller.
  private var state: UIState = .cleared {
    didSet { changeState(from: oldValue, to: state) }
  }

  // MARK: Interface

  /// Image view to display the downloaded image.
  @IBOutlet var imageView: UIImageView!

  /// The download button.
  @IBOutlet var downloadButton: UIButton!

  /// The clear button.
  @IBOutlet var clearButton: UIButton!

  /// A visual representation of the state.
  @IBOutlet var stateLabel: UILabel!

  // MARK: - User Actions

  @IBAction func downloadButtonHit(_ sender: UIButton) {
    guard case .cleared = state else { return }

    // Start the download.
    let storage = Storage.storage()
    let ref = storage.reference(withPath: Constants.downloadPath)
    // TODO: Show progress bar here using proper API.
    let task = ref.getData(maxSize: Constants.maxSize) { [unowned self] data, error in
      guard let data = data else {
        self.state = .failed("Error downloading: \(error!.localizedDescription)")
        return
      }

      // Create a UIImage from the PNG data.
      guard let image = UIImage(data: data) else {
        self.state = .failed("Unable to initialize image with data downloaded.")
        return
      }

      self.state = .downloaded(image)
    }

    // The completion block above could be run before this line in some situations. If that's the
    // case, we don't need to do anything else and can return.
    if case .downloaded = state { return }

    // Set the state to downloading!
    state = .downloading(task)
  }

  @IBAction func clearButtonHit(_ sender: UIButton) {
    guard case .downloaded = state else { return }

    state = .cleared
  }

  // MARK: - State Management

  /// Changing from old state to new state.
  private func changeState(from oldState: UIState, to newState: UIState) {
    if oldState == newState { return }

    switch (oldState, newState) {
    // Regular state, start downloading the image.
    case (.cleared, .downloading(_)):
      // TODO: Update the UI with a spinner? Progress update?
      stateLabel.text = "State: Downloading..."

    //  Download complete, ensure the download button is still off and enable the clear button.
    case let (_, .downloaded(image)):
      imageView.image = image
      stateLabel.text = "State: Image downloaded!"

    // Clear everything and reset to the original state.
    case (_, .cleared):
      imageView.image = nil
      stateLabel.text = "State: Pending download"

    // An error occurred.
    case let (_, .failed(error)):
      stateLabel.text = "State: \(error)"

    // For now, as the default, throw a fatal error because it's an unexpected state. This will
    // allow us to catch it immediately and add the required action or fix the bug.
    default:
      fatalError("Programmer error! Tried to go from \(oldState) to \(newState)")
    }
  }

  // MARK: - Constants

  /// Internal constants for this class.
  private enum Constants {
    /// The image name to download. Can comment this out and replace it with the other below it as
    /// part of the demo. Ensure that Storage has an image uploaded to this path for this to
    /// function properly.
    static let downloadPath = "YOUR_IMAGE_NAME.jpg"

    static let maxSize: Int64 = 1024 * 1024 * 10 // ~10MB
  }
}
