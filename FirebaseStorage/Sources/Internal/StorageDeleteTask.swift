// Copyright 2022 Google LLC
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

#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

/// Task which provides the ability to delete an object in Firebase Storage.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
enum StorageDeleteTask {
  static func deleteTask(reference: StorageReference,
                         queue: DispatchQueue,
                         completion: ((_: Data?, _: Error?) -> Void)?) {
    StorageInternalTask(reference: reference,
                        queue: queue,
                        httpMethod: "DELETE",
                        fetcherComment: "DeleteTask",
                        completion: completion)
  }
}
