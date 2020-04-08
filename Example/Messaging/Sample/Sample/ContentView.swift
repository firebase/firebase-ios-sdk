// Copyright 2020 Google
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
import FirebaseCore
import FirebaseMessaging
import FirebaseInstanceID
import FirebaseInstallations

struct ContentView: View {
  @EnvironmentObject var identity: Identity

  var body: some View {
    NavigationView {
      List {
        Button(action: getToken) {
          HStack {
            Image(systemName: "arrow.clockwise.circle.fill").font(.body)
            Text("Get ID and Token")
              .fontWeight(.semibold)
          }
        }
        .buttonStyle(IdentityButtonStyle())

        Button(action: deleteToken) {
          HStack {
            Image(systemName: "trash.fill").font(.body)
            Text("Delete Token")
              .fontWeight(.semibold)
          }
        }
        .buttonStyle(IdentityButtonStyle())

        Button(action: deleteID) {
          HStack {
            Image(systemName: "trash.fill").font(.body)
            Text("Delete ID")
              .fontWeight(.semibold)
          }
        }
        .buttonStyle(IdentityButtonStyle())

        Button(action: deleteFID) {
          HStack {
            Image(systemName: "trash.fill").font(.body)
            Text("Delete FID")
              .fontWeight(.semibold)
          }
        }
        .buttonStyle(IdentityButtonStyle())

        Text("InstanceID: \(identity.instanceID)")
          .foregroundColor(.blue)
        Text("Token: \(identity.token)")
          .foregroundColor(.blue)
        NavigationLink(destination: DetailView()) {
          Text("Show Detail View")
        }
      }
    }
  }

  func getToken() {
    InstanceID.instanceID().instanceID { result, error in
      guard let result = result, error == nil else {
        print("Failed getting iid and token: ", error ?? "")
        return
      }
      self.identity.token = result.token
      self.identity.instanceID = result.instanceID
    }
  }

  func deleteToken() {
    guard let senderID = FirebaseApp.app()?.options.gcmSenderID else { return }
    Messaging.messaging().deleteFCMToken(forSenderID: senderID) { error in
      if let error = error as NSError? {
        print("Failed delete token: ", error)
        return
      }
      self.identity.token = ""
    }
  }

  func deleteID() {
    InstanceID.instanceID().deleteID { error in
      if let error = error as NSError? {
        print("Failed delete ID: ", error)
        return
      }
      self.identity.instanceID = ""
      self.identity.token = ""
    }
  }

  func deleteFID() {
    Installations.installations().delete { error in
      if let error = error as NSError? {
        print("Failed delete FID: ", error)
        return
      }
    }
  }
}

struct DetailView: View {
  @EnvironmentObject var identity: Identity

  var body: some View {
    VStack {
      Text("InstanceID: \(self.identity.instanceID)")
      Text("Token: \(self.identity.token)")
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView().environmentObject(Identity())
  }
}

struct IdentityButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .frame(minWidth: 0, maxWidth: 200)
      .padding()
      .foregroundColor(.white)
      .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.pink]),
                                 startPoint: .leading, endPoint: .trailing))
      .cornerRadius(40)
  }
}
