// Copyright 2026 Google LLC
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

import SwiftUI

/// A view modifier that posts notifications when a view appears or disappears.
struct ViewTrackingModifier: ViewModifier {
  @State private var instanceID = UUID()
  let screenName: String

  func body(content: Content) -> some View {
    content
      .onAppear {
        NotificationCenter.default.post(
          name: .viewTrackingEvent,
          object: nil,
          userInfo: [
            "screenName": screenName,
            "type": ViewEventType.appear,
            "id": instanceID,
          ]
        )
      }
      .onDisappear {
        NotificationCenter.default.post(
          name: .viewTrackingEvent,
          object: nil,
          userInfo: [
            "screenName": screenName,
            "type": ViewEventType.disappear,
            "id": instanceID,
          ]
        )
      }
  }
}
