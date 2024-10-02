/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit

class CommonMessageTestVC: UIViewController, InAppMessagingDisplayDelegate {
  var messageClosedWithClick = false

  var messageClosedDismiss = false

  // start of InAppMessagingDisplayDelegate functions
  func messageClicked(_ inAppMessage: InAppMessagingDisplayMessage,
                      with action: InAppMessagingAction) {
    print("message clicked to follow action url")
    messageClosedWithClick = true
  }

  func impressionDetected(for inAppMessage: InAppMessagingDisplayMessage) {
    print("valid impression detected")
  }

  func displayError(for inAppMessage: InAppMessagingDisplayMessage, error: Error) {
    print("error encountered \(error)")
  }

  func messageDismissed(_ inAppMessage: InAppMessagingDisplayMessage,
                        dismissType: InAppMessagingDismissType) {
    print("message dismissed with type \(dismissType)")
    messageClosedDismiss = true
  }

  // end of InAppMessagingDisplayDelegate functions

  let normalMessageTitle = "Firebase In-App Message title"
  let normalMessageBody = "Firebase In-App Message body"
  let longBodyText = String(repeating: "This is long message body.", count: 40) +
    "End of body text."
  let longTitleText = String(repeating: "This is long message title.", count: 10) +
    "End of title text."

  let startTime = Date().timeIntervalSince1970
  let endTime = Date().timeIntervalSince1970 + 1000

  let defaultActionButton = InAppMessagingActionButton(buttonText: "Take action",
                                                       buttonTextColor: UIColor.black,
                                                       backgroundColor: UIColor.yellow)

  let defaultSecondaryActionButton = InAppMessagingActionButton(buttonText: "Take another action",
                                                                buttonTextColor: UIColor.black,
                                                                backgroundColor: UIColor.yellow)

  let longTextButton =
    InAppMessagingActionButton(buttonText: "Hakuna matata, it's a wonderful phrase",
                               buttonTextColor: UIColor.black,
                               backgroundColor: UIColor.white)

  func produceImageOfSize(size: CGSize) -> Data? {
    let color = UIColor.cyan

    let rect = CGRect(origin: .zero, size: size)
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    color.setFill()
    UIRectFill(rect)

    if let context = UIGraphicsGetCurrentContext() {
      context.setStrokeColor(UIColor.red.cgColor)
      context.strokeEllipse(in: rect)
    }

    let imageFromGraphics = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsEndImageContext()

    if let image = imageFromGraphics {
      return image.pngData()
    } else {
      return nil
    }
  }
}
