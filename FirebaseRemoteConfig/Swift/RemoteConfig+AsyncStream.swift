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

public extension RemoteConfig {
  /// Asynchronous stream of configuration updates.
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, watchOS 7.0, tvOS 13.0, *)
  var updateStream: AsyncStream<Result<RemoteConfigUpdate, Error>> {
    AsyncStream { continuation in
      let registration = self.addOnConfigUpdateListener { update, error in
        if let error = error {
          continuation.yield(.failure(error))
        } else if let update {
          continuation.yield(.success(update))
        }
      }
      continuation.onTermination = { _ in
        registration.remove()
      }
    }
  }
}
