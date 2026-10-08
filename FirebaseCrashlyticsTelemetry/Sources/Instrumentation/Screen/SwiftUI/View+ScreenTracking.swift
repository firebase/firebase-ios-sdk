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

public extension View {
  /// Tracks when the screen appears and disappears.
  ///
  /// - Parameter name: The name of the screen to report to Crashlytics.
  func crashlyticsScreen(_ name: String) -> some View {
    modifier(ScreenTrackingModifier(screenName: name))
  }
}
