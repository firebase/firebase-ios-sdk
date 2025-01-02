//
//  Pipeline.swift
//  Firebase
//
//  Created by Cheryl Lin on 2024-12-18.
//

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class Pipeline {
  var cppPtr: firebase.firestore.api.Pipeline

  public init(_ cppSource: firebase.firestore.api.Pipeline) {
    cppPtr = cppSource
  }

  @discardableResult
  public func GetPipelineResult() async throws -> PipelineResult {
//    return try await withCheckedThrowingContinuation { continuation in
//
//      let callback: (
//        firebase.firestore.api.PipelineResult,
//        Bool
//      ) -> Void = { result, isSucceed in
//        if isSucceed {
//          continuation.resume(returning: PipelineResult(result))
//        } else {
//          continuation.resume(throwing: "ERROR!" as! Error)
//        }
//              }

    // cppPtr.fetchDataWithCppCallback(callback)
    return PipelineResult(firebase.firestore.api.PipelineResult
      .GetTestResult(cppPtr.GetFirestore()))
  }
}
