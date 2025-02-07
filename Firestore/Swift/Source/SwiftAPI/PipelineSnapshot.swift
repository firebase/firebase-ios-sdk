//
//  PipelineSnapshot.swift
//  FirebaseFirestore
//
//  Created by Hui Wu on 2/7/25.
//

import Foundation

public struct PipelineSnapshot {
  private let bridge: __PipelineSnapshotBridge

  init(_ bridge: __PipelineSnapshotBridge) {
    self.bridge = bridge
  }
}
