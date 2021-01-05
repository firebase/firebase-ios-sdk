/*
 * Copyright 2020 Google LLC
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

import UserNotifications
import FirebaseMessaging
import GoogleDataTransport

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  var transport: GDTCORTransport = GDTCORTransport(mappingID: "1018", transformers: nil,
                                                   target: GDTCORTarget.FLL)!

  override func didReceive(_ request: UNNotificationRequest,
                           withContentHandler contentHandler: @escaping (UNNotificationContent)
                             -> Void) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    if let bestAttemptContent = bestAttemptContent {
      // Modify the notification content here...
      bestAttemptContent.title = "\(bestAttemptContent.title) [High]"

      // Please generate high priority event in notification service extension
      print("Generating high priority event on watchOS notification service extension")
      let transportToUse = transport
      let event: GDTCOREvent = transportToUse.eventForTransport()
      let testMessage = FirelogTestMessageHolder()
      testMessage.root.identifier = "watchos_test_app_service_extension_high_priority_event"
      testMessage.root.repeatedID = ["id1", "id2", "id3"]
      testMessage.root.warriorChampionships = 1337
      event.qosTier = GDTCOREventQoS.qoSFast
      event.dataObject = testMessage
      let encoder = JSONEncoder()
      if let jsonData = try? encoder.encode(["needs_network_connection_info": true]) {
        event.customBytes = jsonData
      }
      transportToUse.sendDataEvent(event)

      bestAttemptContent.title = "\(bestAttemptContent.title) [Priority Event]"

      Messaging.serviceExtension()
        .populateNotificationContent(bestAttemptContent, withContentHandler: self.contentHandler!)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content.
    // Otherwise the original push payload will be used.
    if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
