// Copyright 2024 Google LLC
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

/// Manage Storage's fetcherService
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
actor StorageFetcherService {
  private var _fetcherService: GTMSessionFetcherService?

  func fetcherService(_ storage: Storage) -> GTMSessionFetcherService {
    if let _fetcherService {
      return _fetcherService
    }
    let app = storage.app
    if StorageFetcherService.fetcherServiceMap[app.name] == nil {
      StorageFetcherService.fetcherServiceMap[app.name] = [:]
    }
    var fetcherService = StorageFetcherService.fetcherServiceMap[app.name]?[storage.storageBucket]
    if fetcherService == nil {
      fetcherService = GTMSessionFetcherService()
      fetcherService?.isRetryEnabled = true
      fetcherService?.retryBlock = retryWhenOffline
      fetcherService?.allowLocalhostRequest = true
      fetcherService?.maxRetryInterval = storage.maxOperationRetryInterval
      fetcherService?.testBlock = testBlock
      let authorizer = StorageTokenAuthorizer(
        googleAppID: app.options.googleAppID,
        callbackQueue: storage.callbackQueue,
        authProvider: storage.auth,
        appCheck: storage.appCheck
      )
      fetcherService?.authorizer = authorizer
      StorageFetcherService.fetcherServiceMap[app.name]?[storage.storageBucket] = fetcherService
    }
    if storage.usesEmulator {
      fetcherService?.allowLocalhostRequest = true
      fetcherService?.allowedInsecureSchemes = ["http"]
    }
    _fetcherService = fetcherService
    return fetcherService!
  }

  /// Update the testBlock for unit testing. Save it as a property since this may be called before
  /// fetcherService is initialized.
  func updateTestBlock(_ block: @escaping GTMSessionFetcherTestBlock) {
    testBlock = block
    if let _fetcherService {
      _fetcherService.testBlock = testBlock
    }
  }

  private var testBlock: GTMSessionFetcherTestBlock?

  /// Map of apps to a dictionary of buckets to GTMSessionFetcherService.
  private static var fetcherServiceMap: [String: [String: GTMSessionFetcherService]] = [:]

  private var retryWhenOffline: GTMSessionFetcherRetryBlock = {
    (suggestedWillRetry: Bool,
     error: Error?,
     response: @escaping GTMSessionFetcherRetryResponse) in
    var shouldRetry = suggestedWillRetry
    // GTMSessionFetcher does not consider being offline a retryable error, but we do, so we
    // special-case it here.
    if !shouldRetry, error != nil {
      shouldRetry = (error as? NSError)?.code == URLError.notConnectedToInternet.rawValue
    }
    response(shouldRetry)
  }
}
