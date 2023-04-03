// Copyright 2023 Google LLC
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

import UIKit

class FeedbackViewController: UIViewController {
  // TODO: Consider the situations where this instance is initiated once, and used
  // multiple times.
  var viewDidDisappearCallback: () -> Void = {}
  // (TODO) Can we make feedbackName and additionalFormText non-null?
  var releaseName: String?
  var additionalFormText: String?
  var image: UIImage?

  @IBOutlet var screenshotUIImageView: UIImageView!
  @IBOutlet var additionalFormTextLabel: UILabel!
  @IBOutlet var feedbackTextView: UITextView!
  @IBOutlet var navigationBar: UINavigationBar!

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.

    let additionalFormText = additionalFormText
    if additionalFormText != nil {
      additionalFormTextLabel.text = additionalFormText
    }

    let image = image
    if image != nil {
      screenshotUIImageView.image = image
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    screenshotUIImageView.image = image
    image = nil
  }

  @IBAction func tappedSend(_ sender: Any) {
    guard let releaseName = releaseName else {
      // TODO(tundeagboola) throw error or
      return
    }

    ApiService
      .createFeedback(releaseName: releaseName,
                      feedbackText: feedbackTextView.text) { feedbackName, error in
        if error != nil {
          // TODO(tundeaboola) handle error if create feedback fails
          return
        }

        guard let feedbackName = feedbackName else {
          // TODO(tundeaboola) handle error if create feedback fails
          return
        }

        guard let image = self.screenshotUIImageView.image else {
          return self.commitFeedback(feedbackName: feedbackName)
        }

        ApiService.uploadImage(feedbackName: feedbackName, image: image) { error in
          if error != nil {
            // TODO(tundeaboola) handle error if upload image fails
            return
          }

          self.commitFeedback(feedbackName: feedbackName)
        }
      }
  }

  private func commitFeedback(feedbackName: String) {
    ApiService.commitFeedback(feedbackName: feedbackName) { error in
      if error != nil {
        // TODO(tundeaboola) handle error if commit feedback fails
      }
      self.feedbackSubmitted()
    }
  }

  @IBAction func tappedCancel(_ sender: Any) {
    dismiss(animated: true)
  }

  override func viewDidDisappear(_ animated: Bool) {
    viewDidDisappearCallback()
  }

  func feedbackSubmitted() {
    // TODO(tundeagboola) show success toast
    dismiss(animated: true)
  }
}
