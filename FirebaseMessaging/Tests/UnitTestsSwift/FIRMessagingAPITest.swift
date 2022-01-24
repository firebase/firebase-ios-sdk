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

  if let _ = messaging.apnsToken {}

  let apnsToken = Data()
  messaging.setAPNSToken(apnsToken, type: .prod)

  let topic = "cat_video"
  messaging.subscribe(toTopic: topic)
  messaging.unsubscribe(fromTopic: topic)

  messaging.appDidReceiveMessage([:])

  if #available(macOS 10.14, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
    let serviceExtension = Messaging.serviceExtension()
    let content = UNMutableNotificationContent()
    serviceExtension.populateNotificationContent(content) { content in
    }
    serviceExtension.exportDeliveryMetricsToBigQuery(withMessageInfo: [:])
  }
}

@available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
func apiAsync() async throws {
  let messaging = Messaging.messaging()
  let topic = "cat_video"
  #if compiler(>=5.5) && canImport(_Concurrency)
    try await messaging.subscribe(toTopic: topic)

    try await messaging.unsubscribe(fromTopic: topic)

    try await messaging.token()

    try await messaging.retrieveFCMToken(forSenderID: "fakeSenderID")

    try await messaging.deleteToken()

    try await messaging.deleteFCMToken(forSenderID: "fakeSenderID")

    try await messaging.deleteData()
  #endif
}
