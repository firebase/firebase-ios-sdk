/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import PackageGraph

public extension ResolvedModule {
  /// Indicates whether the resolved module represents a pre-compiled binary target (e.g. an
  /// `.xcframework` or static library).
  var isBinary: Bool {
    type == .binary
  }

  /// Indicates whether the resolved module represents a test target.
  var isTest: Bool {
    type == .test
  }
}

public extension ResolvedModule.Dependency {
  /// Returns the identifier name of the underlying module or product dependency.
  var name: String {
    switch self {
    case let .module(m, _): return m.name
    case let .product(p, _): return p.name
    }
  }
}
