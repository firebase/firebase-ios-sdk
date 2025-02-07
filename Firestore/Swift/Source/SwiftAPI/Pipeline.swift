//
//  Pipeline.swift
//  FirebaseFirestore
//
//  Created by Hui Wu on 2/7/25.
//

import Foundation

public struct Pipeline {
  private var stages: [Stage]
  private var bridge: PipelineBridge
  private let db: Firestore

  init(stages: [Stage], db: Firestore) {
    self.stages = stages
    self.db = db
    bridge = PipelineBridge(stages: stages.map { $0.bridge }, db: db)
  }

  public func `where`(_ condition: Expr) -> Pipeline {
    return Pipeline(stages: stages + [Where(condition: condition)], db: db)
  }

  public func execute() async throws -> PipelineSnapshot {
    return try await withCheckedThrowingContinuation { continuation in
      self.bridge.execute { result, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: PipelineSnapshot(result!))
        }
      }
    }
  }
}
