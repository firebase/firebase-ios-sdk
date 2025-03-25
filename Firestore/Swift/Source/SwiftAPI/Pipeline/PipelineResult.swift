// Copyright 2025 Google LLC
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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct PipelineResult {
  let bridge: __PipelineResultBridge

  init(_ bridge: __PipelineResultBridge) {
    self.bridge = bridge
    ref = self.bridge.reference
    id = self.bridge.documentID
    data = self.bridge.data()
    createTime = self.bridge.create_time
    updateTime = self.bridge.update_time
  }

  /// The reference of the document, if the query returns the `__name__` field.
  public let ref: DocumentReference?

  /// The ID of the document for which this `PipelineResult` contains data, if available.
  public let id: String?

  /// The time the document was created, if available.
  public let createTime: Timestamp?

  /// The time the document was last updated when the snapshot was generated.
  public let updateTime: Timestamp?

  /// Retrieves all fields in the result as a dictionary.
  public let data: [String: Any]

  /// Retrieves the field specified by `fieldPath`.
  /// - Parameter fieldPath: The field path (e.g., "foo" or "foo.bar").
  /// - Returns: The data at the specified field location or `nil` if no such field exists.
  public func get(_ fieldPath: Any) -> Any? {
    return "PLACEHOLDER"
  }
}
