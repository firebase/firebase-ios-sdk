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
  @IBOutlet weak var scrollView: UIScrollView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    
    feedbackTextView.isScrollEnabled = false
    setScrollViewConstraints()
    setAdditionalFormTextConstraints()
    setFeedbackInputConstraints()
    setScreenshotImageConstrains()

    let additionalFormText = additionalFormText
    if additionalFormText != nil {
      additionalFormTextLabel.text = additionalFormText
    }
    // TODO: Consider default text.

    let image = image
    if image != nil {
      screenshotUIImageView.image = image
      self.image = nil
    }
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
  
  // MARK: - UI Constraints
  
  func setScrollViewConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    let bottomConstraint = NSLayoutConstraint(item: scrollView!, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1, constant: 0)
    let leftConstraint = NSLayoutConstraint(item: scrollView!, attribute: .left, relatedBy: .equal, toItem: navigationBar, attribute: .left, multiplier: 1, constant: 0)
    let rightConstraint = NSLayoutConstraint(item: scrollView!, attribute: .right, relatedBy: .equal, toItem: navigationBar, attribute: .right, multiplier: 1, constant: 0)
    self.view.addConstraints([bottomConstraint, leftConstraint, rightConstraint])
  }
  
  func setAdditionalFormTextConstraints() {
    additionalFormTextLabel.translatesAutoresizingMaskIntoConstraints = false
    additionalFormTextLabel.numberOfLines = 0
    
    let topConstraint = NSLayoutConstraint(item: additionalFormTextLabel!, attribute: .top, relatedBy: .equal, toItem: scrollView, attribute: .top, multiplier: 1, constant: 0)
    let bottomConstraint = NSLayoutConstraint(item: additionalFormTextLabel!, attribute: .bottom, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .top, multiplier: 1, constant: 80)
    let leftConstraint = NSLayoutConstraint(item: additionalFormTextLabel!, attribute: .left, relatedBy: .equal, toItem: scrollView, attribute: .left, multiplier: 1, constant: 0)
    let rightConstraint = NSLayoutConstraint(item: additionalFormTextLabel!, attribute: .right, relatedBy: .equal, toItem: scrollView, attribute: .right, multiplier: 1, constant: 0)
    scrollView.addConstraints([topConstraint, bottomConstraint, leftConstraint, rightConstraint])
    let widthConstraint = NSLayoutConstraint(item: additionalFormTextLabel!, attribute: .width, relatedBy: .equal, toItem: navigationBar, attribute: .width, multiplier: 1, constant: 0)
    self.view.addConstraints([topConstraint, bottomConstraint, leftConstraint, rightConstraint, widthConstraint])
    
    
    additionalFormTextLabel.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    // TODO: Better color
    additionalFormTextLabel.backgroundColor = .lightGray
  }
  
  func setFeedbackInputConstraints() {
    feedbackTextView.translatesAutoresizingMaskIntoConstraints = false
    let topConstraint = NSLayoutConstraint(item: feedbackTextView!, attribute: .top, relatedBy: .equal, toItem: additionalFormTextLabel, attribute: .bottom, multiplier: 1, constant: 0)
    let bottomConstraint = NSLayoutConstraint(item: feedbackTextView!, attribute: .bottom, relatedBy: .greaterThanOrEqual, toItem: additionalFormTextLabel, attribute: .top, multiplier: 1, constant: 160)
    let leftConstraint = NSLayoutConstraint(item: feedbackTextView!, attribute: .left, relatedBy: .equal, toItem: scrollView, attribute: .left, multiplier: 1, constant: 0)
    let rightConstraint = NSLayoutConstraint(item: feedbackTextView!, attribute: .right, relatedBy: .equal, toItem: scrollView, attribute: .right, multiplier: 1, constant: 0)
    let widthConstraint = NSLayoutConstraint(item: feedbackTextView!, attribute: .width, relatedBy: .equal, toItem: navigationBar, attribute: .width, multiplier: 1, constant: 0)
    self.view.addConstraints([topConstraint, bottomConstraint, leftConstraint, rightConstraint, widthConstraint])
    
    feedbackTextView.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
  }
  
  func setScreenshotImageConstrains() {
    screenshotUIImageView.translatesAutoresizingMaskIntoConstraints = false
    let topConstraint = NSLayoutConstraint(item: screenshotUIImageView!, attribute: .top, relatedBy: .equal, toItem: feedbackTextView, attribute: .bottom, multiplier: 1, constant: 0)
    let bottomConstraint = NSLayoutConstraint(item: screenshotUIImageView!, attribute: .bottom, relatedBy: .greaterThanOrEqual, toItem: feedbackTextView, attribute: .top, multiplier: 1, constant: 40)
    let leftConstraint = NSLayoutConstraint(item: screenshotUIImageView!, attribute: .left, relatedBy: .equal, toItem: scrollView, attribute: .left, multiplier: 1, constant: 0)
    let rightConstraint = NSLayoutConstraint(item: screenshotUIImageView!, attribute: .right, relatedBy: .equal, toItem: scrollView, attribute: .right, multiplier: 1, constant: 0)
    let widthConstraint = NSLayoutConstraint(item: screenshotUIImageView!, attribute: .width, relatedBy: .equal, toItem: feedbackTextView, attribute: .width, multiplier: 1, constant: 0)
    scrollView.addConstraints([topConstraint, bottomConstraint, leftConstraint, rightConstraint, widthConstraint])
  }
  
}
