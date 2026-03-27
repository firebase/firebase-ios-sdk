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

/// An internal `Expression` wrapper that allows a `Pipeline` to be used as an expression.
///
/// This enables a `Pipeline` (composed of multiple stages) to be passed via bridging into a
/// `FunctionExpression` or other expression contexts in the iOS SDK, without requiring the
/// `Pipeline` itself to conform to the `Expression` protocol.
struct PipelineExpression: Expression, BridgeWrapper, @unchecked Sendable {
  let bridge: ExprBridge
  let errorMessage: String?

  init(_ pipeline: Pipeline) {
    if let errorMessage = pipeline.errorMessage {
      // PipelineExpression must conform to BridgeWrapper for downstream protocol casts
      // inside `Expression.toBridge()`. Since `BridgeWrapper.bridge` demands a non-optional
      // ExprBridge, we cannot use an optional field and instead use a safe dummy bridge here.
      bridge = Constant.nil.bridge
      self.errorMessage = errorMessage
    } else {
      bridge = PipelineExprBridge(stages: pipeline.stages.map { $0.bridge })
      errorMessage = nil
    }
  }
}
