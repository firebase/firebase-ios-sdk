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

import FirebaseAppCheck
import FirebaseCore
import Foundation

/// An `AppCheckProvider` whose every response is scripted, and which records
/// what it was asked for.
///
/// Most of the token-lifecycle plan (caching, coalescing, forced refresh,
/// proactive refresh) is about how many times the SDK asks the provider for a
/// token and what it does with the answer. Against a live backend those
/// questions are answered indirectly, slowly, and flakily. Here they are
/// answered by a counter.
///
/// Every issued token is unique, which is what makes coalescing observable: if
/// ten callers receive the same string, the SDK made one request and shared it.
/// If they receive ten different strings, it did not.
final class ProgrammableProvider: NSObject, AppCheckProvider, @unchecked Sendable {
  /// What the provider should do for a given call.
  enum Outcome {
    /// Issue a fresh unique token valid for `ttl` seconds from now.
    case success(ttl: TimeInterval)
    /// Fail with `error`, without issuing a token.
    case failure(any Error)
  }

  /// A recorded request.
  struct Call {
    enum Kind { case standard, limitedUse }
    let kind: Kind
    let startedAt: Date
    let issuedToken: String?
  }

  /// Artificial latency, in seconds, applied before responding.
  ///
  /// Coalescing is only observable while a request is in flight. With no
  /// latency, concurrent callers serialize by accident and a broken
  /// implementation can pass, so overlap has to be forced.
  ///
  /// Expressed as `TimeInterval` rather than `Duration` because the host app
  /// deploys below iOS 16.
  var latency: TimeInterval = 0

  /// Outcome for the nth standard call, zero-based.
  var standardOutcome: @Sendable (Int) -> Outcome = { _ in .success(ttl: 3600) }

  /// Outcome for the nth limited-use call, zero-based.
  var limitedUseOutcome: @Sendable (Int) -> Outcome = { _ in .success(ttl: 3600) }

  private let lock = NSLock()
  private var calls: [Call] = []
  private var issuedCount = 0

  // MARK: - Recorded state

  /// Every call the SDK made, in completion order.
  var recordedCalls: [Call] {
    lock.withLock { calls }
  }

  var standardCallCount: Int {
    lock.withLock { calls.filter { $0.kind == .standard }.count }
  }

  var limitedUseCallCount: Int {
    lock.withLock { calls.filter { $0.kind == .limitedUse }.count }
  }

  var totalCallCount: Int {
    lock.withLock { calls.count }
  }

  /// Distinct token strings handed out, for detecting coalescing.
  var distinctIssuedTokens: Set<String> {
    lock.withLock { Set(calls.compactMap(\.issuedToken)) }
  }

  func reset() {
    lock.withLock {
      calls.removeAll()
      issuedCount = 0
    }
  }

  // MARK: - AppCheckProvider

  func getToken() async throws -> AppCheckToken {
    try await respond(kind: .standard, outcome: standardOutcome(standardCallCount))
  }

  func getLimitedUseToken() async throws -> AppCheckToken {
    try await respond(kind: .limitedUse, outcome: limitedUseOutcome(limitedUseCallCount))
  }

  private func respond(kind: Call.Kind, outcome: Outcome) async throws -> AppCheckToken {
    let startedAt = Date()

    if latency > 0 {
      try? await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
    }

    switch outcome {
    case let .failure(error):
      lock.withLock {
        calls.append(Call(kind: kind, startedAt: startedAt, issuedToken: nil))
      }
      throw error

    case let .success(ttl):
      let value: String = lock.withLock {
        issuedCount += 1
        let token = "programmable-token-\(issuedCount)"
        calls.append(Call(kind: kind, startedAt: startedAt, issuedToken: token))
        return token
      }
      return AppCheckToken(token: value, expirationDate: Date().addingTimeInterval(ttl))
    }
  }
}
