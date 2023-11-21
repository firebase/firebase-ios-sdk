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
import FirebaseCore
import FirebaseInstallations
import FirebaseMessaging
import SwiftUI
import UIKit

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
            Text("InstallationsID")
              .font(.subheadline)
              .fontWeight(.semibold)

            Text(identity.installationsID ?? "None").foregroundColor(.green)
          }

          VStack(alignment: .leading) {
            Text("Token")
              .font(.subheadline)
              .fontWeight(.semibold)
            Text(identity.token ?? "None")
              .foregroundColor(.green)
              // Increase the layout priority to allow more than one line to be shown. Without this,
              // the
              // simulator renders a single truncated line even though the Preview renders it
              // appropriately. Potentially a bug in the simulator?
              .layoutPriority(1)
              .lineLimit(7)
          }
          NavigationLink(destination: SettingsView()) {
            Text("Settings")
              .fontWeight(.semibold)
          }
          NavigationLink(destination: TopicView()) {
            Text("Topic")
              .fontWeight(.semibold)
          }

          // MARK: Action buttons

          VStack(alignment: .leading) {
            Text("getToken")
              .fontWeight(.semibold)
            HStack {
              Button(action: getIDAndToken) {
                HStack {
                  Image(systemName: "arrow.clockwise.circle.fill")
                  Text("FID & Token")
                    .fontWeight(.semibold)
                }
              }
              Button(action: getFCMToken) {
                HStack {
                  Image(systemName: "arrow.clockwise.circle.fill").font(.body)
                  Text("getToken")
                    .fontWeight(.semibold)
                }
              }
            }
          }.font(.system(size: 14))

          VStack(alignment: .leading) {
            Text("deleteToken")
              .fontWeight(.semibold)
            HStack {
              Button(action: deleteFCMToken) {
                HStack {
                  Image(systemName: "trash.fill")
                  Text("deleteToken")
                    .fontWeight(.semibold)
                }
              }
            }
          }.font(.system(size: 14))

          VStack(alignment: .leading) {
            Text("delete")
              .fontWeight(.semibold)
            HStack {
              Button(action: deleteFCM) {
                HStack {
                  Image(systemName: "trash.fill")
                  Text("FM.delete")
                    .fontWeight(.semibold)
                }
              }
              Button(action: deleteFID) {
                HStack {
                  Image(systemName: "trash.fill")
                  Text("FIS.delete")
                    .fontWeight(.semibold)
                }
              }
            }
          }.font(.system(size: 14))
          Text("\(log)")
            .lineLimit(10)
            .multilineTextAlignment(.leading)
        }
        .navigationBarTitle("Firebase Messaging")
      }.buttonStyle(IdentityButtonStyle())
    }
  }

  func getIDAndToken() {
    Messaging.messaging().token { token, error in
      guard let token = token, error == nil else {
        self.log = "Failed getting iid and token: \(String(describing: error))"
        return
      }
      self.identity.token = token
      self.log = "Successfully got token."
      print("Token: ", self.identity.token ?? "")
      Installations.installations().installationID { fid, error in
        self.identity.installationsID = fid
        self.log = "Successfully got iid and token."
      }
    }
  }

  func getFCMToken() {
    Messaging.messaging().token { token, error in
      guard let token = token, error == nil else {
        self.log = "Failed getting iid and token: \(String(describing: error))"
        return
      }
      self.identity.token = token
      self.log = "Successfully got token."
      print("Token: ", self.identity.token ?? "")
    }
  }

  func deleteFCMToken() {
    Messaging.messaging().deleteToken { error in
      if let error = error as NSError? {
        self.log = "Failed deleting token: \(error)"
        return
      }
      self.log = "Successfully deleted token."
    }
  }

  func deleteFCM() {
    Messaging.messaging().deleteData { error in
      if let error = error as NSError? {
        self.log = "Failed deleting Messaging: \(error)"
        return
      }
      self.log = "Successfully deleted Messaging data."
    }
  }

  func deleteFID() {
    Installations.installations().delete { error in
      if let error = error as NSError? {
        self.log = "Failed deleting FID: \(error)"
        return
      }
      self.log = "Successfully deleted FID."
    }
  }
}

struct ActivityViewController: UIViewControllerRepresentable {
  var activityItems: [Any]
  var applicationActivities: [UIActivity]? = nil

  func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>)
    -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: applicationActivities
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController,
                              context: UIViewControllerRepresentableContext<
                                ActivityViewController
                              >) {}
}

struct SettingsView: View {
  @EnvironmentObject var settings: UserSettings
  @State var shouldUseDelegate = true
  @State private var isSharePresented: Bool = false

  var body: some View {
    VStack {
      List {
        Toggle(isOn: $settings.isAutoInitEnabled) {
          Text("isAutoInitEnabled")
            .fontWeight(.semibold)
        }
        Toggle(isOn: $settings.shouldUseDelegateThanNotification) {
          Text("shouldUseDelegate")
            .fontWeight(.semibold)
        }
        Button(action: shareToken) {
          HStack {
            Image(systemName: "square.and.arrow.up").font(.body)
            Text("Share Token")
              .fontWeight(.semibold)
          }
        }
        .sheet(isPresented: $isSharePresented, onDismiss: {
          print("Dismiss")
        }, content: {
          let items = [Messaging.messaging().fcmToken]
          ActivityViewController(activityItems: items as [Any])
        })
      }
      .font(.subheadline)
      .foregroundColor(.blue)
    }
  }

  func shareToken() {
    isSharePresented = true
  }
}

struct ContentView_Previews: PreviewProvider {
  // A fake filled identity for testing rendering of a filled cell.
  static let filledIdentity: Identity = {
    var identity = Identity()
    identity.installationsID = UUID().uuidString

    // The token is a long string, generate a very long repeating string of characters to see how
    // the view
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
      .frame(minWidth: 0, maxWidth: 120)
      .padding()
      .foregroundColor(.white)
      .background(Color.yellow)
      .cornerRadius(20)
      // Push the button down a bit when it's pressed.
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .font(.footnote)
  }
}
