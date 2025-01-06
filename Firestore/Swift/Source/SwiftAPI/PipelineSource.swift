//
//  PipelineSource.swift
//  Pods
//
//  Created by Cheryl Lin on 2024-12-12.
//

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public class PipelineSource {
  let cppObj: firebase.firestore.api.PipelineSource

  public init(_ cppSource: firebase.firestore.api.PipelineSource) {
    cppObj = cppSource
  }

  public func GetCollection(_ path: String) -> Pipeline {
    return Pipeline(cppObj.GetCollection(std.string(path)))
  }
}
