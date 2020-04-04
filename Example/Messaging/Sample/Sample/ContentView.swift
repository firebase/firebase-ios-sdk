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

struct ContentView: View {
  @State private var token = Messaging.messaging().fcmToken
  @State private var iid = ""
  
    var body: some View {
      
      VStack {
        HStack {
          Button("get ID and token", action: getToken).padding()
          Button("deleteToken", action: deleteToken).padding()
          Button("deleteID", action: deleteID).padding()
        }
        Text("IID:\n" + (self.iid)).padding(10)
        Text("Token:\n" + (self.token ?? "")).padding(10)
      }
    }
  func getToken() {
    InstanceID.instanceID().instanceID { (result, error) in
      if result != nil && error == nil {
        self.token = result?.token
        self.iid = result?.instanceID ?? ""
      }
    }
  }
  
  func deleteToken() {
    Messaging.messaging().deleteFCMToken(forSenderID: FirebaseApp.app()?.options.gcmSenderID ?? "") { (error) in
      if (error != nil) {
        print ("Failed delete token: ", error ?? "")
        return
      }
      self.token = ""
    }
  }
  
  func deleteID() {
    InstanceID.instanceID().deleteID { (error) in
      if error != nil {
        print ("Failed delete ID: ", error ?? "")
        return
      }
    }
  }
  
  func OnTokenRefresh() {
    self.token = Messaging.messaging().fcmToken
  }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
