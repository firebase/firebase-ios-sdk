//
//  PipelineSource.swift
//  Pods
//
//  Created by Cheryl Lin on 2024-12-12.
//

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class PipelineSource {
  let cppPtr: firebase.firestore.api.PipelineSource

  public init(_ cppSource: firebase.firestore.api.PipelineSource) {
    cppPtr = cppSource
  }

  public func GetCollection(_ path: String) -> Pipeline {
    return Pipeline(cppPtr.GetCollection(std.string(path)))
  }
}
