//// Copyright 2024 Google LLC
////
//// Licensed under the Apache License, Version 2.0 (the "License");
//// you may not use this file except in compliance with the License.
//// You may obtain a copy of the License at
////
////      http://www.apache.org/licenses/LICENSE-2.0
////
//// Unless required by applicable law or agreed to in writing, software
//// distributed under the License is distributed on an "AS IS" BASIS,
//// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//// See the License for the specific language governing permissions and
//// limitations under the License.
//
// import Foundation
// import FirebaseCore
//
//// TODO(ncooke3): Port RCNConfigSettings
// public class ConfigSettings {}
//
///// Completion handler invoked by NSSessionFetcher.
// public typealias RCNConfigFetcherCompletion = (Data, URLResponse, any Error) -> Void
//
///// Completion handler invoked after a fetch that contains the updated keys
// public typealias RCNConfigFetchCompletion = (
//  RemoteConfigFetchStatus,
//  RemoteConfigUpdate,
//  any Error
// ) -> Void
//
// open class RCNConfigFetch : NSObject {
//    /// Designated initializer
//  init(
//    content: ConfigContent,
//    dbManager: ConfigDBManager,
//    settings: ConfigSettings,
//    analytics: (any FIRAnalyticsInterop)?,
//    experiment: ConfigExperiment?,
//    queue: DispatchQueue,
//    namespace: String,
//    options: FirebaseOptions
//  ) {
//
//  }
//
//  typedef void (^FIRRemoteConfigFetchCompletion)(FIRRemoteConfigFetchStatus status,
//                                                 NSError *_Nullable error)
//      NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");
//
//  /// Fetches config data keyed by namespace. Completion block will be called on the main queue.
//  /// @param expirationDuration  Expiration duration, in seconds.
//  /// @param completionHandler   Callback handler.
//  open func fetchConfig(
//    withExpirationDuration expirationDuration: TimeInterval,
//    completionHandler: Int32) {
//
//  }
//
//  /// Fetches config data immediately, keyed by namespace. Completion block will be called on the
//  /main
//  /// queue.
//  /// @param fetchAttemptNumber The number of the fetch attempt.
//  /// @param completionHandler   Callback handler.
//  open func realtimeFetchConfigWithNoExpirationDuration(_ fetchAttemptNumber: Int,
//  completionHandler: @escaping RCNConfigFetchCompletion) {
//
//  }
//
//  /// Add the ability to update NSURLSession's timeout after a session has already been created.
//  open func recreateNetworkSession() {
//
//  }
//
//  /// Provide fetchSession for tests to override.
//  open var fetchSession: URLSession {
//
//  }
//
//  /// Provide config template version number for Realtime config client.
//  open var templateVersionNumber: String {
//
//  }
// }
