// Copyright 2021 Google LLC
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

import FirebaseCore
import FirebaseMessaging
import UserNotifications

// This file is a build-only test for the public Messaging Swift APIs not
// exercised in the integration tests.
func apis() {
  let messaging = Messaging.messaging()
  let delegate = CustomDelegate()
  messaging.delegate = delegate
  messaging.isAutoInitEnabled = false
  messaging.token(completion: { _, _ in
  })
  messaging.deleteToken { _ in
  }
  messaging.retrieveFCMToken(forSenderID: "fakeSenderID") { _, _ in
  }
  messaging.deleteData { _ in
  }
  messaging.deleteFCMToken(forSenderID: "fakeSenderID") { _ in
  }

  if let _ = messaging.apnsToken {}

  let apnsToken = Data()
  messaging.setAPNSToken(apnsToken, type: .prod)

  // Use random to eliminate the warning that we're evaluating to a constant.
  let type: MessagingAPNSTokenType = Bool.random() ? .prod : .sandbox
  switch type {
  case .prod: ()
  case .sandbox: ()
  case .unknown: ()
  // The following case serves to silence the warning that this
  // enum "may have additional unknown values". In the event that the existing
  // cases change, this switch statement will generate
  // a "Switch must be exhaustive" warning.
  @unknown default: ()
  }

  // Use random to eliminate the warning that we're evaluating to a constant.
  let messagingError: MessagingError = Bool
    .random() ? MessagingError(.unknown) : MessagingError(.authentication)
  switch messagingError.code {
  case .unknown: ()
  case .authentication: ()
  case .noAccess: ()
  case .timeout: ()
  case .network: ()
  case .operationInProgress: ()
  case .invalidRequest: ()
  case .invalidTopicName: ()
  // The following case serves to silence the warning that this
  // enum "may have additional unknown values". In the event that the existing
  // cases change, this switch statement will generate
  // a "Switch must be exhaustive" warning.
  @unknown default: ()
  }

  // Use random to eliminate the warning that we're evaluating to a constant.
  let status: MessagingMessageStatus = Bool.random() ? .unknown : .new
  switch status {
  case .new: ()
  case .unknown: ()
  // The following case serves to silence the warning that this
  // enum "may have additional unknown values". In the event that the existing
  // cases change, this switch statement will generate
  // a "Switch must be exhaustive" warning.
  @unknown default: ()
  }

  // TODO: Mark the initializer as unavialable, as devs shouldn't be able to instantiate this.
  _ = MessagingMessageInfo().status

  NotificationCenter.default.post(name: .MessagingRegistrationTokenRefreshed, object: nil)

  let topic = "cat_video"
  messaging.subscribe(toTopic: topic)
  messaging.unsubscribe(fromTopic: topic)
  messaging.unsubscribe(fromTopic: topic, completion: { error in
    if let error {
      switch error {
      // Handle errors in the new format.
      case MessagingError.timeout:
        ()
      default:
        ()
      }
    }
  })

  messaging.unsubscribe(fromTopic: topic) { _ in
  }

  messaging.appDidReceiveMessage([:])

  if #available(macOS 10.14, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
    let serviceExtension = Messaging.serviceExtension()
    let content = UNMutableNotificationContent()
    serviceExtension.populateNotificationContent(content) { content in
    }
    serviceExtension.exportDeliveryMetricsToBigQuery(withMessageInfo: [:])
  }
}

class CustomDelegate: NSObject, MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {}
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
func apiAsync() async throws {
  let messaging = Messaging.messaging()
  let topic = "cat_video"
  try await messaging.subscribe(toTopic: topic)

  try await messaging.unsubscribe(fromTopic: topic)

  try await messaging.token()

  try await messaging.retrieveFCMToken(forSenderID: "fakeSenderID")

  try await messaging.deleteToken()

  try await messaging.deleteFCMToken(forSenderID: "fakeSenderID")

  try await messaging.deleteData()

  // Test new handling of errors
  do {
    try await messaging.unsubscribe(fromTopic: topic)
  } catch MessagingError.timeout {
  } catch {}
}
