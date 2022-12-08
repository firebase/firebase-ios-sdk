import Foundation
import UIKit

class InAppFeedback {
  static let shared = InAppFeedback()
  
  func feedbackViewController() -> UIViewController {
    let resourceBundle = Bundle(identifier: "main")
    let storyboard = UIStoryboard(name: "FIRAppDistributionInternalStoryboard", bundle: resourceBundle)
    let vc = storyboard.instantiateViewController(withIdentifier: "fir-ad-iaf")
    return vc
  }
}
