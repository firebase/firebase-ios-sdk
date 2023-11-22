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

import FirebaseInAppMessaging
import SwiftUI

struct ContentView: View {
  @State private var analyticsEvent = ""

  var body: some View {
    VStack {
      Text("Firebase In-App Messaging")
        .font(.largeTitle)
        .bold()
        .multilineTextAlignment(.center)
        .padding()
      Text("🔥💍")
        .font(.system(size: 60.0))
        .padding()
      TextField("Enter an analytics event to trigger",
                text: $analyticsEvent) { _ in
      } onCommit: { InAppMessaging.inAppMessaging().triggerEvent(analyticsEvent) }
        .multilineTextAlignment(.center)
        .autocapitalization(.none)
        .padding()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
