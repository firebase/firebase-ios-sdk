// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to
// build this package.

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
  import FirebaseFirestoreCpp
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct Pipeline {
  var cppObj: firebase.firestore.api.Pipeline

  public init(_ cppSource: firebase.firestore.api.Pipeline) {
    cppObj = cppSource
  }

  @discardableResult
  public func GetPipelineResult() async throws -> [PipelineResult] {
    return try await withCheckedThrowingContinuation { continuation in
      let listener = CallbackWrapper.wrapPipelineCallback(firestore: cppObj.GetFirestore()) {
        result, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          // Our callbacks guarantee that we either return an error or a progress event.
          continuation.resume(returning: PipelineResult.convertToArrayFromCppVector(result))
        }
      }
      cppObj.GetPipelineResult(listener)
    }
  }
}
