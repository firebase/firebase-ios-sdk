//
//  PipelineResult.swift
//  Firebase
//
//  Created by Cheryl Lin on 2024-12-18.
//
#if SWIFT_PACKAGE
 import FirebaseFirestoreCpp
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class PipelineResult {
  let cppObj: firebase.firestore.api.PipelineResult

  public init(_ cppSource: firebase.firestore.api.PipelineResult) {
    cppObj = cppSource
  }

  static func convertToArrayFromCppVector(_ vectorPtr: PipelineResultVectorPtr)
    -> [PipelineResult] {
    // Create a Swift array and populate it by iterating over the C++ vector
    var swiftArray: [PipelineResult] = []

    for index in vectorPtr.pointee.indices {
      let cppResult = vectorPtr.pointee[index]
      swiftArray.append(PipelineResult(cppResult))
    }

    return swiftArray
  }
}
