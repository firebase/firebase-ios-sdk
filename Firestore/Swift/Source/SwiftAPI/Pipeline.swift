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
  public func GetPipelineResult() async throws -> [PipelineResult] {
    return try await withCheckedThrowingContinuation { continuation in
      let listener = Query.wrapPipelineCallback(firestore: cppPtr.GetFirestore()) {
        result, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          // Our callbacks guarantee that we either return an error or a progress event.
          continuation.resume(returning: PipelineResult.convertToArrayFromCppVector(result))
        }
      }
      cppPtr.GetPipelineResult(listener)
    }
  }
}
