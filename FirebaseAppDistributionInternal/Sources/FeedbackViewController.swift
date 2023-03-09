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
  var viewDidDisappearCallback: () -> Void = {}
  var image: UIImage?
  var additionalInfo: String?

  @IBOutlet var screenshotUIImageView: UIImageView!
  @IBOutlet var additionalInfoLabel: UILabel!
  @IBOutlet var feedbackTextView: UITextView!

  @IBOutlet var navigationBar: UINavigationBar!

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
  }

  override func viewWillAppear(_ animated: Bool) {
    screenshotUIImageView.image = image
  }

  @IBAction func tappedSend(_ sender: Any) {}

  @IBAction func tappedCancel(_ sender: Any) {
    dismiss(animated: true)
  }

  override func viewDidDisappear(_ animated: Bool) {
    viewDidDisappearCallback()
  }
}
