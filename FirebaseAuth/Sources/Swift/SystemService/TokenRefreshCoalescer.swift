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

/// Coalesces multiple concurrent token refresh requests into a single network call.
///
/// When multiple requests for a token refresh arrive concurrently (e.g., from Storage, Firestore,
/// and auto-refresh), instead of making separate network calls for each one, this class ensures
/// that only ONE network request is made. All concurrent callers wait for and receive the same
/// refreshed token.
///
/// This prevents redundant STS (Secure Token Service) calls and reduces load on both the client
/// and server.
///
/// Example:
/// ```
/// // Multiple concurrent requests arrive at the same time
/// Task { try await tokenRefreshCoalescer.coalescedRefresh(currentToken: token, ...) }  // 1
/// Task { try await tokenRefreshCoalescer.coalescedRefresh(currentToken: token, ...) }  // 2
/// Task { try await tokenRefreshCoalescer.coalescedRefresh(currentToken: token, ...) }  // 3
///
/// // Only ONE network call is made. All three tasks receive the same refreshed token.
/// ```
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
actor TokenRefreshCoalescer {
  /// The in-flight token refresh task, if any.
  /// When this is set, all concurrent calls wait for this task instead of starting their own.
  private var pendingRefreshTask: Task<(String?, Bool), Error>?

  /// The token string of the pending refresh.
  /// Used to ensure we only coalesce requests for the same token.
  private var pendingRefreshToken: String?

  /// Performs a coalesced token refresh.
  ///
  /// If a refresh is already in progress, this method waits for that refresh to complete
  /// and returns its result. If no refresh is in progress, it starts a new one and stores
  /// the task so other concurrent callers can wait for it.
  ///
  /// - Parameters:
  ///   - currentToken: The current token string. Used to detect token changes.
  ///                   If the current token differs from the pending refresh token,
  ///                   a new refresh is started (old one is ignored).
  ///   - refreshFunction: A closure that performs the actual network request and refresh.
  ///                     Should be called only if a new refresh is needed.
  ///
  /// - Returns: A tuple containing (refreshedToken, wasUpdated) matching the format
  ///           of SecureTokenService.
  ///
  /// - Throws: Any error from the refresh operation.
  func coalescedRefresh(currentToken: String,
                        refreshFunction: @escaping () async throws -> (String?, Bool)) async throws
    -> (
      String?,
      Bool
    ) {
    // Check if a refresh is already in progress for this token
    if let pendingTask = pendingRefreshTask,
       pendingRefreshToken == currentToken {
      // Token hasn't changed and a refresh is in progress
      // Wait for the pending refresh to complete
      return try await pendingTask.value
    }

    // Either no refresh is in progress, or the token has changed.
    // Start a new refresh task.
    let task = Task {
      try await refreshFunction()
    }

    // Store the task so other concurrent callers can wait for it
    pendingRefreshTask = task
    pendingRefreshToken = currentToken

    defer {
      // Clean up the pending task after it completes
      pendingRefreshTask = nil
      pendingRefreshToken = nil
    }

    do {
      return try await task.value
    } catch {
      // On error, clear the pending task so the next call will retry
      pendingRefreshTask = nil
      pendingRefreshToken = nil
      throw error
    }
  }
}
