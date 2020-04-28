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

import Combine
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseInstanceID
import FirebaseInstallations

struct ContentView: View {
  @EnvironmentObject var identity: Identity
  @EnvironmentObject var settings: UserSettings
  @State private var log: String = ""

  var body: some View {
    NavigationView {
      // Outer stack containing the list and the buttons.
      VStack {
        List {
          VStack(alignment: .leading) {
            Text("InstanceID").font(.subheadline)
            Text(identity.instanceID ?? "None").foregroundColor(.blue)
          }

          VStack(alignment: .leading) {
            Text("Token").font(.subheadline)
            Text(identity.token ?? "None")
              .foregroundColor(.blue)
              // Increase the layout priority to allow more than one line to be shown. Without this, the
              // simulator renders a single truncated line even though the Preview renders it
              // appropriately. Potentially a bug in the simulator?
              .layoutPriority(1)
          }

          NavigationLink(destination: SettingsView()) {
            Text("Settings")
          }
          NavigationLink(destination: TopicView()) {
            Text("Topic")
          }
        }
        .navigationBarTitle("Firebase Messaging")

        // MARK: Action buttons

        Button(action: getToken) {
          HStack {
            Image(systemName: "arrow.clockwise.circle.fill").font(.body)
            Text("Get ID and Token")
              .fontWeight(.semibold)
          }
        }

        Button(action: deleteToken) {
          HStack {
            Image(systemName: "trash.fill").font(.body)
            Text("Delete Token")
              .fontWeight(.semibold)
          }
        }

        Button(action: deleteID) {
          HStack {
            Image(systemName: "trash.fill").font(.body)
            Text("Delete ID")
              .fontWeight(.semibold)
          }
        }

        Button(action: deleteFID) {
          HStack {
            Image(systemName: "trash.fill").font(.body)
            Text("Delete FID")
              .fontWeight(.semibold)
          }
        }

        Text("\(log)")
          .lineLimit(10)
          .multilineTextAlignment(.leading)
      }.buttonStyle(IdentityButtonStyle())
    }
  }

  func getToken() {
    InstanceID.instanceID().instanceID { result, error in
      guard let result = result, error == nil else {
        self.log = "Failed getting iid and token: \(String(describing: error))"
        return
      }
      self.identity.token = result.token
      self.identity.instanceID = result.instanceID
      self.log = "Successfully get token."
    }
  }

  func deleteToken() {
    guard let app = FirebaseApp.app() else {
      return
    }
    let senderID = app.options.gcmSenderID
    Messaging.messaging().deleteFCMToken(forSenderID: senderID) { error in
      if let error = error as NSError? {
        self.log = "Failed delete token: \(error)"
        return
      }
      self.log = "Successfully delete token."
    }
  }

  func deleteID() {
    InstanceID.instanceID().deleteID { error in
      if let error = error as NSError? {
        self.log = "Failed delete ID: \(error)"
        return
      }
      self.log = "Successfully delete ID."
    }
  }

  func deleteFID() {
    Installations.installations().delete { error in
      if let error = error as NSError? {
        self.log = "Failed delete FID: \(error)"
        return
      }
      self.log = "Successfully delete FID."
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject var settings: UserSettings
  @State var shouldUseDelegate = true

  var body: some View {
    VStack {
      List {
        Toggle(isOn: $settings.isAutoInitEnabled) {
          Text("isAutoInitEnabled")
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        Toggle(isOn: $settings.shouldUseDelegateThanNotification) {
          Text("shouldUseDelegate")
            .font(.subheadline)
            .foregroundColor(.blue)
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  // A fake filled identity for testing rendering of a filled cell.
  static let filledIdentity: Identity = {
    var identity = Identity()
    identity.instanceID = UUID().uuidString

    // The token is a long string, generate a very long repeating string of characters to see how the view
    // will react.
    let longString = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    identity.token = Array(repeating: longString, count: 8).reduce("", +)

    return identity
  }()

  static let filledSettings: UserSettings = {
    var settings = UserSettings()
    settings.shouldUseDelegateThanNotification = true
    settings.isAutoInitEnabled = true
    return settings
  }()

  static var previews: some View {
    Group {
      ContentView().environmentObject(filledIdentity).environmentObject(filledSettings)
    }
  }
}

struct IdentityButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .frame(minWidth: 0, maxWidth: 200)
      .padding()
      .foregroundColor(.white)
      .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.yellow]),
                                 startPoint: .leading, endPoint: .trailing))
      .cornerRadius(40)
      // Push the button down a bit when it's pressed.
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
  }
}
