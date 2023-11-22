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

import FirebaseStorage
import SwiftUI

class InterfaceController: WKInterfaceController {
  @IBOutlet var imageView: WKInterfaceImage!

  override func willActivate() {
    let storage = Storage.storage()
    let storageRef = storage.reference().child("sparky.png")
    storageRef.getData(maxSize: 20 * 1024 * 1024) { (data: Data?, error: Error?) in
      self.imageView.setImageData(data)
    }
  }
}
