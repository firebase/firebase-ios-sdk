//
//  PipelineSource.swift
//  FirebaseFirestore
//
//  Created by Hui Wu on 2/7/25.
//

import Foundation

public class PipelineSource {
  private let db: Firestore
  public init(db: Firestore) {
    self.db = db
  }

  public func collection(path: String) -> Pipeline {
    return Pipeline(stages: [CollectionSource(collection: path)], db: db)
  }
}
