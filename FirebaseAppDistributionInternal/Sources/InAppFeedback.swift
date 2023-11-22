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
import Photos
import UIKit

@objc(FIRFADInAppFeedback) open class InAppFeedback: NSObject {
  @objc(
    feedbackViewControllerWithAdditionalFormText:releaseName:image:onDismiss:
  ) public static func feedbackViewController(additionalFormText: String,
                                              releaseName: String,
                                              image: UIImage?,
                                              onDismiss: @escaping ()
                                                -> Void)
    -> UIViewController {
    // TODO: Add the additionalInfoText parameter.
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
    let vc: FeedbackViewController = storyboard
      .instantiateViewController(withIdentifier: "fir-ad-iaf") as! FeedbackViewController

    vc.additionalFormText = additionalFormText
    vc.releaseName = releaseName
    vc.image = image
    vc.viewDidDisappearCallback = onDismiss

    return vc
  }

  @objc(getManuallyCapturedScreenshotWithCompletion:)
  public static func getManuallyCapturedScreenshot(completion: @escaping (_ screenshot: UIImage?)
    -> Void) {
    getPhotoPermissionIfNecessary(completionHandler: { authorized in
      guard authorized else {
        completion(nil)
        return
      }

      let manager = PHImageManager.default()

      let fetchOptions = PHFetchOptions()
      fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      fetchOptions.predicate = NSPredicate(
        format: "(mediaSubtype & %d) != 0",
        PHAssetMediaSubtype.photoScreenshot.rawValue
      )

      let requestOptions = PHImageRequestOptions()
      requestOptions.isSynchronous = true

      let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

      manager.requestImage(
        for: fetchResult.object(at: 0),
        // TODO: Identify the correct size.
        targetSize: CGSize(width: 358, height: 442),
        contentMode: .aspectFill,
        options: requestOptions
      ) { image, err in
        // TODO: Add logic to respond correctly if there's an error.
        completion(image)
      }
    })
  }

  static func getPhotoPermissionIfNecessary(completionHandler: @escaping (_ authorized: Bool)
    -> Void) {
    if #available(iOS 14, *) {
      // The iOS 14 API is used to prompt users for permission if they previously provided limited
      // access, but have now taken an additional screenshot.
      guard PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized else {
        completionHandler(true)
        return
      }

      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        completionHandler(status != .denied)
      }
    } else {
      guard PHPhotoLibrary.authorizationStatus() != .authorized else {
        completionHandler(true)
        return
      }

      PHPhotoLibrary.requestAuthorization { status in
        completionHandler(status != .denied)
      }
    }
  }

  @objc(captureProgrammaticScreenshot)
  public static func captureProgrammaticScreenshot() -> UIImage? {
    // TODO: Explore options besides keyWindow as keyWindow is deprecated.
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
