// Copyright 2020 Google LLC
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

import FirebaseMessaging
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest,
                           withContentHandler contentHandler: @escaping (UNNotificationContent)
                             -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    if let bestAttemptContent {
      // Modify the notification content here...
      bestAttemptContent.title = "\(bestAttemptContent.title) 👩🏻‍💻"

      // Log Delivery signals and export to BigQuery.
      Messaging.serviceExtension()
        .exportDeliveryMetricsToBigQuery(withMessageInfo: request.content.userInfo)

      // Add image, call this last to finish with the content handler.
      Messaging.serviceExtension()
        .populateNotificationContent(bestAttemptContent, withContentHandler: contentHandler)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the
    // original push payload will be used.
    if let contentHandler, let bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
