//
// Copyright 2024 Google LLC
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
//

import FirebaseRemoteConfig
import Foundation
import SwiftUI

struct RemoteConfigButtonView: View {
  @State private var turnOnRealTimeRC = false
  let rc = RemoteConfig.remoteConfig()
  @RemoteConfigProperty(key: "ios_rollouts", fallback: "unfetched") var iosRollouts: String

  var body: some View {
    NavigationView {
      VStack(
        alignment: .leading,
        spacing: 10
      ) {
        Button(action: {
          rc.fetch()
        }) {
          Text("Fetch")
        }
        Button(action: {
          rc.activate()
        }) {
          Text("Activate")
        }
        Text(iosRollouts)
        Toggle("Turn on RealTime RC", isOn: $turnOnRealTimeRC).toggleStyle(.button).tint(.mint)
          .onChange(of: self.turnOnRealTimeRC, perform: { value in
            rc.addOnConfigUpdateListener { u, e in rc.activate() }
          })
      }
      .navigationTitle("Remote Config Example")
    }
  }
}
