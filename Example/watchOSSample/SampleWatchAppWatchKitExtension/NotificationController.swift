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

import Foundation
import UserNotifications
import WatchKit

class NotificationController: WKUserNotificationInterfaceController {
  override init() {
    // Initialize variables here.
    super.init()

    // Configure interface objects here.
  }

  override func willActivate() {
    // This method is called when watch view controller is about to be visible to user
    super.willActivate()
  }

  override func didDeactivate() {
    // This method is called when watch view controller is no longer visible
    super.didDeactivate()
  }

  override func didReceive(_ notification: UNNotification) {
    // This method is called when a notification needs to be presented.
    // Implement it if you use a dynamic notification interface.
    // Populate your dynamic notification interface as quickly as possible.
  }
}
