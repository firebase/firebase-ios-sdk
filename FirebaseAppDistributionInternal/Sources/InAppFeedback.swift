import Foundation
import UIKit

@objc(FIRFADInAppFeedback) open class InAppFeedback: NSObject {
  
  @objc(feedbackViewController) static public func feedbackViewController() -> UIViewController {
    let resourceBundle = Bundle(identifier: "main")
    let storyboard = UIStoryboard(name: "FIRAppDistributionInternalStoryboard", bundle: resourceBundle)
    let vc = storyboard.instantiateViewController(withIdentifier: "fir-ad-iaf")
    return vc
  }
}
