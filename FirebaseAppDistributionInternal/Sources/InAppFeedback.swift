import Foundation
import UIKit

@objc(FIRFADInAppFeedback) open class InAppFeedback: NSObject {
  @objc(feedbackViewController) public static func feedbackViewController() -> UIViewController {
    let frameworkBundle = Bundle(for: self)

    let resourceBundleURL = frameworkBundle.url(
      forResource: "AppDistributionInternalResources",
      withExtension: "bundle"
    )
    let resourceBundle = Bundle(url: resourceBundleURL)

    let storyboard = UIStoryboard(
      name: "FIRAppDistributionInternalStoryboard",
      bundle: resourceBundle
    )
    let vc = storyboard.instantiateViewController(withIdentifier: "fir-ad-iaf")
    return vc
  }
}
