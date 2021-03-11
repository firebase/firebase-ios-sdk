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
import SwiftUI
import FirebaseAuth
import FirebaseStorage

struct ContentView: View {
  @State var image: UIImage = UIImage()

  var body: some View {
    VStack(alignment: .leading) {
      Image(uiImage: image).resizable()
        .frame(width: 64.0, height: 64.0)

      Button(action: getImage) {
        HStack {
          Image(systemName: "arrow.clockwise.circle.fill")
          Text("getImage")
            .fontWeight(.semibold)
        }
      }
    }
  }

  func getImage() {
//    if (Auth.auth().currentUser == nil) {
//        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
//        }
//    }
//    Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
    let storage = Storage.storage()
    let storageRef = storage.reference().child("sparky.png")
    storageRef.getData(maxSize: 20 * 1024 * 1024) { (data: Data?, error: Error?) in
      if data != nil {
        self.image = UIImage(data: data!)!
      }
    }
//    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
