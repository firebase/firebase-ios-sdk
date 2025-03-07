//
//  PipelineTests.swift
//  Firestore
//
//  Created by Hui Wu on 2/7/25.
//  Copyright © 2025 Google. All rights reserved.
//

import FirebaseFirestore
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class PipelineIntegrationTests: FSTIntegrationTestCase {
  func testCount() async throws {
    let snapshot = try await firestore()
      .pipeline()
      .collection(path: "foo")
      .where(eq(field("foo"), constant(42)))
      .execute()

    print(snapshot)
  }
}
