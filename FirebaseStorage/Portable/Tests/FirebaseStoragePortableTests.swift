// Copyright 2026 Google LLC
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

import FirebaseCore
import FirebaseStorage
import Foundation
import Testing

@Suite("FirebaseStorage Portable Tests")
struct FirebaseStoragePortableTests {
  private func makeTestApp(storageBucket: String? = "test-project.firebasestorage.app") throws
    -> FirebaseApp {
    let appName = "test-storage-\(UUID().uuidString)"
    let options = FirebaseOptions(googleAppID: "1:123:ios:abc", gcmSenderID: "123")
    options.projectID = "test-project"
    options.apiKey = "test-api-key"
    options.storageBucket = storageBucket
    FirebaseApp.configure(name: appName, options: options)
    return try #require(FirebaseApp.app(name: appName))
  }

  @Test
  func storageFromAppUsesDefaultBucket() throws {
    let app = try makeTestApp(storageBucket: "my-default-bucket.appspot.com")

    let storage = Storage.storage(app: app)
    let rootRef = storage.reference()

    #expect(storage.app === app)
    #expect(rootRef.bucket == "my-default-bucket.appspot.com")
    #expect(rootRef.fullPath == "")
    #expect(rootRef.name == "")
  }

  @Test
  func storageWithCustomBucketURLReturnsSameInstancePerBucket() throws {
    let app = try makeTestApp()

    let storage1 = Storage.storage(app: app, url: "gs://custom-bucket-1")
    let storage1Duplicate = Storage.storage(app: app, url: "gs://custom-bucket-1/")
    let storage2 = Storage.storage(app: app, url: "gs://custom-bucket-2")

    #expect(storage1 === storage1Duplicate)
    #expect(storage1 !== storage2)
    #expect(storage1.reference().bucket == "custom-bucket-1")
    #expect(storage2.reference().bucket == "custom-bucket-2")
  }

  @Test
  func referenceWithPathAndDescription() throws {
    let app = try makeTestApp(storageBucket: "my-bucket")
    let storage = Storage.storage(app: app)

    let ref = storage.reference(withPath: "vertexai/public/green.png")

    #expect(ref.storage === storage)
    #expect(ref.bucket == "my-bucket")
    #expect(ref.fullPath == "vertexai/public/green.png")
    #expect(ref.name == "green.png")
    #expect(ref.description == "gs://my-bucket/vertexai/public/green.png")
  }

  @Test
  func referenceHierarchyNavigation() throws {
    let app = try makeTestApp(storageBucket: "my-bucket")
    let storage = Storage.storage(app: app)

    let root = storage.reference()
    let child = root.child("images").child("avatars/profile.jpg")
    let parent = try #require(child.parent())
    let rootParent = root.parent()

    #expect(child.fullPath == "images/avatars/profile.jpg")
    #expect(child.name == "profile.jpg")
    #expect(parent.fullPath == "images/avatars")
    #expect(parent.name == "avatars")
    #expect(child.root().fullPath == "")
    #expect(rootParent == nil)
  }

  @Test
  func referenceFromGSAndHTTPSURLs() throws {
    let app = try makeTestApp(storageBucket: "my-bucket")
    let storage = Storage.storage(app: app)

    let gsRef = storage.reference(forURL: "gs://my-bucket/folder/file.txt")
    let httpsRef = storage.reference(
      forURL: "https://firebasestorage.googleapis.com/v0/b/my-bucket/o/folder%2Ffile.txt?alt=media"
    )

    #expect(gsRef.bucket == "my-bucket")
    #expect(gsRef.fullPath == "folder/file.txt")
    #expect(gsRef.name == "file.txt")
    #expect(httpsRef.bucket == "my-bucket")
    #expect(httpsRef.fullPath == "folder/file.txt")
    #expect(httpsRef.name == "file.txt")
  }

  @Test
  func storageMetadataContentType() {
    let defaultMetadata = StorageMetadata()
    let dictionaryMetadata = StorageMetadata(dictionary: ["contentType": "image/png"])

    defaultMetadata.contentType = "image/jpeg"

    #expect(defaultMetadata.contentType == "image/jpeg")
    #expect(dictionaryMetadata.contentType == "image/png")
  }

  @Test
  func putFileAsyncThrowsUnimplementedError() async throws {
    let app = try makeTestApp(storageBucket: "my-bucket")
    let storage = Storage.storage(app: app)
    let ref = storage.reference(withPath: "images/image.jpg")
    let fileURL = URL(fileURLWithPath: "/tmp/image.jpg")

    await #expect(throws: NSError.self) {
      _ = try await ref.putFileAsync(from: fileURL)
    }
  }
}
