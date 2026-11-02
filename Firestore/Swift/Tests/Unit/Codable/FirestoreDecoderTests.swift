/*
 * Copyright 2026 Google LLC
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

import FirebaseCore
import FirebaseFirestore
import Testing

@MainActor
private let firebaseApp: FirebaseApp = {
  if let app = FirebaseApp.app() { return app }
  let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
  options.projectID = "Firestore-Testing-Project"
  FirebaseApp.configure(options: options)
  return FirebaseApp.app()!
}()

private struct Model: Decodable, Equatable {
  var name: String
  @DocumentID var docId: String?
}

private let customUserInfoKey = CodingUserInfoKey(rawValue: "FirestoreDecoderTestsKey")!

private struct UserInfoReader: Decodable {
  var value: String?

  init(from decoder: Decoder) throws {
    value = decoder.userInfo[customUserInfoKey] as? String
  }
}

@Suite("Firestore.Decoder Tests")
struct FirestoreDecoderTests {
  @MainActor
  @Test("A reused decoder does not reuse the document reference of a previous call")
  func reusedDecoderDoesNotReusePreviousDocumentReference() throws {
    let db = Firestore.firestore(app: firebaseApp)
    let decoder = Firestore.Decoder()

    let first = try decoder.decode(
      Model.self, from: ["name": "first"], in: db.document("coll/first")
    )
    #expect(first == Model(name: "first", docId: "first"))

    // Without a reference, `@DocumentID` cannot be populated by a new decoder...
    #expect(throws: FirestoreDecodingError.self) {
      try Firestore.Decoder().decode(Model.self, from: ["name": "second"], in: nil)
    }
    // ...and a reused decoder must not populate it from the previous call's reference.
    #expect(throws: FirestoreDecodingError.self) {
      try decoder.decode(Model.self, from: ["name": "second"], in: nil)
    }
    #expect(throws: FirestoreDecodingError.self) {
      try decoder.decode(Model.self, from: ["name": "second"])
    }

    let third = try decoder.decode(
      Model.self, from: ["name": "third"], in: db.document("coll/third")
    )
    #expect(third == Model(name: "third", docId: "third"))
  }

  @MainActor
  @Test("Decoding with a document reference passes through but does not modify userInfo")
  func decodingWithDocumentReferenceDoesNotModifyUserInfo() throws {
    let db = Firestore.firestore(app: firebaseApp)
    let decoder = Firestore.Decoder()
    decoder.userInfo[customUserInfoKey] = "custom value"

    let decoded = try decoder.decode(
      UserInfoReader.self, from: [String: Any](), in: db.document("coll/doc")
    )

    #expect(decoded.value == "custom value")
    #expect(decoder.userInfo.count == 1)
    #expect(decoder.userInfo[customUserInfoKey] as? String == "custom value")
  }
}
