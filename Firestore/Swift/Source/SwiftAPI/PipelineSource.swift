//
//  PipelineSource.swift
//  Pods
//
//  Created by Cheryl Lin on 2024-12-12.
//

public class PipelineSource {
  let cppPtr: firebase.firestore.api.PipelineSource

  public init(_ cppSource: firebase.firestore.api.PipelineSource) {
    cppPtr = cppSource
  }
}
