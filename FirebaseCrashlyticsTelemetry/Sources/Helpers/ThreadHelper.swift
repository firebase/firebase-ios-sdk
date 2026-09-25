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

/// A helper to use for methods to verify thread safety.
/// TODO: Explore having a common thread worker similar to
/// https://github.com/firebase/firebase-android-sdk/blob/e2aaa50e35ec14970ae49aa0b0d9bce94a3b443d/firebase-crashlytics/src/main/java/com/google/firebase/crashlytics/internal/concurrency/CrashlyticsWorkers.kt
public final class ThreadHelper: @unchecked Sendable {
  public static func isNotMainThread() {
    assert(!Thread.isMainThread, "This method must not be called on the main thread.")
  }
}
