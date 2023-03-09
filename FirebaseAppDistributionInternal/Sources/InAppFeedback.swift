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

import Foundation
import UIKit
import Photos

@objc(FIRFADInAppFeedback) open class InAppFeedback: NSObject {
  @objc(feedbackViewControllerWithImage:onDismiss:) public static func feedbackViewController(image: UIImage, onDismiss: @escaping () -> Void) -> UIViewController {
    let frameworkBundle = Bundle(for: self)

    let resourceBundleURL = frameworkBundle.url(
      forResource: "AppDistributionInternalResources",
      withExtension: "bundle"
    )
    let resourceBundle = Bundle(url: resourceBundleURL!)

    let storyboard = UIStoryboard(
      name: "AppDistributionInternalStoryboard",
      bundle: resourceBundle
    )
    let vc: FeedbackViewController = storyboard.instantiateViewController(withIdentifier: "fir-ad-iaf") as! FeedbackViewController
    
    vc.viewDidDisappearCallback = onDismiss
    vc.image = image
    
    return vc
  }
  
  public static func enableFeedbackOnScreenshot(onScreenshot: @escaping () -> Void) {
    // TODO: Implement it.
  }
  
  public static func captureProgrammaticScreenshot() -> UIImage? {
    let layer = UIApplication.shared.keyWindow?.layer
    
    if let layer {
      let renderer = UIGraphicsImageRenderer(size: layer.bounds.size)
      let image = renderer.image { ctx in
        layer.render(in: ctx.cgContext)
      }
      
      return image
    }
    
    return nil
  }
}
