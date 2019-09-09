/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import GoogleDataTransport

// For use by GDT.
class TestDataObject: NSObject, GDTEventDataObject {
  func transportBytes() -> Data {
    return "Normally, some SDK's data object would populate this. \(Date())".data(using: String.Encoding.utf8)!
  }
}

class TestPrioritizer: NSObject, GDTPrioritizer {
  func prioritizeEvent(_ event: GDTStoredEvent) {}

  func uploadPackage(with conditions: GDTUploadConditions) -> GDTUploadPackage {
    return GDTUploadPackage(target: GDTTarget.test)
  }
}

class TestUploader: NSObject, GDTUploader {
  func readyToUpload(with conditions: GDTUploadConditions) -> Bool {
    return false
  }

  func uploadPackage(_ package: GDTUploadPackage) {}
}
