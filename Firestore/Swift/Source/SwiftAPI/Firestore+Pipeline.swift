//
//  Firestore+Pipeline.swift
//  FirebaseFirestore
//
//  Created by Hui Wu on 2/10/25.
//

import Foundation

@objc public extension Firestore {
  @nonobjc func pipeline() -> PipelineSource {
    return PipelineSource(db: self)
  }
}
