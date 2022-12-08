import Foundation
import UIKit

@objc(FIRFADInAppFeedback) open class InAppFeedback: NSObject {
  
  @objc(feedbackViewController) static public func feedbackViewController() -> UIViewController {
    let frameworkBundle = Bundle(for: self)
    let bundleURL = frameworkBundle.resourceURL?.appendingPathComponent("-AppDistributionInternalResources")
    let resourceBundle = Bundle(url: bundleURL!)
    
    let storyboard = UIStoryboard(name: "FIRAppDistributionInternalStoryboard", bundle: resourceBundle)
    let vc = storyboard.instantiateViewController(withIdentifier: "fir-ad-iaf")
    return vc
  }
}
