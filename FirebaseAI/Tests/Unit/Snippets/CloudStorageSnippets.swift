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

#if SWIFT_PACKAGE // The FirebaseStorage dependency has only been added in Package.swift.

  import FirebaseAILogic
  import FirebaseCore
  import FirebaseStorage

  // These CloudStorageSnippets are not currently runnable due to the GCS upload paths but are used
  // as compilation tests.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  final class CloudStorageSnippets {
    let model: GenerativeModel! = nil

    func cloudStorageFile_referenceMIMEType() async throws {
      // Upload an image file using Cloud Storage for Firebase.
      let storageRef = Storage.storage().reference(withPath: "images/image.jpg")
      guard let imageURL = Bundle.main.url(forResource: "image", withExtension: "jpg") else {
        fatalError("File 'image.jpg' not found in main bundle.")
      }
      let metadata = try await storageRef.putFileAsync(from: imageURL)

      // Get the MIME type and Cloud Storage for Firebase URL.
      guard let mimeType = metadata.contentType else {
        fatalError("The MIME type of the uploaded image is nil.")
      }
      // Construct a URL in the required format.
      let storageURL = "gs://\(storageRef.bucket)/\(storageRef.fullPath)"

      let prompt = "What's in this picture?"
      // Construct the imagePart with the MIME type and the URL.
      let imagePart = FileDataPart(uri: storageURL, mimeType: mimeType)

      // To generate text output, call generateContent with the prompt and the imagePart.
      let result = try await model.generateContent(prompt, imagePart)
      if let text = result.text {
        print(text)
      }
    }

    func cloudStorageFile_explicitMIMEType() async throws {
      let prompt = "What's in this picture?"
      // Construct an imagePart that explicitly includes the MIME type and
      // Cloud Storage for Firebase URL values.
      let imagePart = FileDataPart(uri: "gs://bucket-name/path/image.jpg", mimeType: "image/jpeg")

      // To generate text output, call generateContent with the prompt and imagePart.
      let result = try await model.generateContent(prompt, imagePart)
      if let text = result.text {
        print(text)
      }
    }
  }

#endif // SWIFT_PACKAGE
