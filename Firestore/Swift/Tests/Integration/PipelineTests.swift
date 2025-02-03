// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import XCTest

import FirebaseFirestore

#if swift(>=5.5.2)
  final class PipelineTests: FSTIntegrationTestCase {
    func testCreatePipeline() async throws {
      let pipelineSource: PipelineSource = db.pipeline()
//    let docs: [DocumentReference] = [
//        db.collection("foo").document("bar"),
//        db.document("foo/baz")
//    ]
      // let pipelineA: Pipeline = pipelineSource.documents(docs)
//    let pipelineA: Pipeline = pipelineSource.documents(
//      [db.collection("foo").document("bar"), db.document("foo/baz")]
//    )
      let _: Pipeline = pipelineSource.collection("foo")
      let pipelineC: Pipeline = pipelineSource.collectionGroup("foo")
      let _: Pipeline = pipelineSource.database()
      let _: PipelineResult = try await pipelineC.execute()
    }
  }
#endif
