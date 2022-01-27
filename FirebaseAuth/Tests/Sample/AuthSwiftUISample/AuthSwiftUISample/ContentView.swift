// Copyright 2022 Google LLC
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

extension Image {
  func data(url:URL) -> Self {
    if  let data = try? Data(contentsOf: url) {
      return Image(uiImage: UIImage(data: data)!)
        .resizable()
    }
    return self.resizable()
  }
}

struct ContentView: View {
  @State private var imageURL = URL(string: "local")

    var body: some View {
      VStack{
                  
        Image(systemName: "person.fill")
          .data(url: self.imageURL!).onAppear(perform: loadImageFromFirebase)
        Text("Hello, world!")
            .padding()
      Button(action: signOut) {
        HStack {
          Image(systemName: "arrow.clockwise.circle.fill")
          Text("Sign out")
            .fontWeight(.semibold)
        }
      }
      }.onAppear(perform: loadImageFromFirebase)
    }
  
  func loadImageFromFirebase() {
    let storageRef = Storage.storage().reference(withPath: "sparky.png")
    storageRef.downloadURL { (url, error) in
      if error != nil {
        return
      }
      self.imageURL = url!
    }
  }
      
  func signOut() {
    do
    {
      try Auth.auth().signOut()
      loadImageFromFirebase()
    }
    catch let error as NSError
    {
      print(error.localizedDescription)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
