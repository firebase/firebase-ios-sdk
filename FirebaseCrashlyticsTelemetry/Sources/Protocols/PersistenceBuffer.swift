// Copyright 2026 Google LLC
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
import PersistenceWrapper

internal protocol PersistenceBuffer: AnyObject, Sendable {
  func add(_ span: PersistenceSpan)
  func setAttribute(_ value: String, forKey key: String, onSpanId spanId: UInt64)
  func endSpanId(_ spanId: UInt64, endTime: UInt64)
  func removeSpanId(_ spanId: UInt64)
}

extension PersistenceBufferWrapper: PersistenceBuffer {}
