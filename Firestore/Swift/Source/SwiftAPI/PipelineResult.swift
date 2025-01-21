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
public struct PipelineResult {
  let cppObj: firebase.firestore.api.PipelineResult

  public init(_ cppSource: firebase.firestore.api.PipelineResult) {
    cppObj = cppSource
    print("zzyzx SwiftObj id: \(cppObj.id_)")
  }

  static func convertToArrayFromCppVector(_ vector: CppPipelineResult)
    -> [PipelineResult] {
    // Create a Swift array and populate it by iterating over the C++ vector
    var swiftArray: [PipelineResult] = []

//    for index in vector.indices {
//      let cppResult = vector[index]
//      swiftArray.append(PipelineResult(cppResult))
//    }

    return swiftArray
  }
}
