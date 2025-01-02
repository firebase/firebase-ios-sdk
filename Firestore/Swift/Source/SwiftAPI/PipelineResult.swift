//
//  PipelineResult.swift
//  Firebase
//
//  Created by Cheryl Lin on 2024-12-18.
//

public class PipelineResult {
  let cppPtr: firebase.firestore.api.PipelineResult

  public init(_ cppSource: firebase.firestore.api.PipelineResult) {
    cppPtr = cppSource
  }
}
