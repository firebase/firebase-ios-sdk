/*
 * Copyright 2019 Google
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

#import <Foundation/Foundation.h>

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

@class FIROptions;
@class RCNConfigContent;
@class RCNConfigSettings;
@class RCNConfigExperiment;
@class RCNConfigDBManager;

NS_ASSUME_NONNULL_BEGIN

/// Completion handler invoked by NSSessionFetcher.
typedef void (^RCNConfigFetcherCompletion)(NSData *data, NSURLResponse *response, NSError *error);

/// Completion handler invoked after a fetch that contains the updated keys
typedef void (^RCNConfigFetchCompletion)(FIRRemoteConfigFetchStatus status,
                                         FIRRemoteConfigUpdate *update,
                                         NSError *error);

@interface RCNConfigFetch : NSObject

- (instancetype)init NS_UNAVAILABLE;

/// Designated initializer
- (instancetype)initWithContent:(RCNConfigContent *)content
                      DBManager:(RCNConfigDBManager *)DBManager
                       settings:(RCNConfigSettings *)settings
                      analytics:(nullable id<FIRAnalyticsInterop>)analytics
                     experiment:(nullable RCNConfigExperiment *)experiment
                          queue:(dispatch_queue_t)queue
                      namespace:(NSString *)firebaseNamespace
                        options:(FIROptions *)firebaseOptions NS_DESIGNATED_INITIALIZER;

/// Fetches config data keyed by namespace. Completion block will be called on the main queue.
/// @param expirationDuration  Expiration duration, in seconds.
/// @param completionHandler   Callback handler.
- (void)fetchConfigWithExpirationDuration:(NSTimeInterval)expirationDuration
                        completionHandler:
                            (_Nullable FIRRemoteConfigFetchCompletion)completionHandler;

/// Fetches config data immediately, keyed by namespace. Completion block will be called on the main
/// queue.
/// @param fetchAttemptNumber The number of the fetch attempt.
/// @param completionHandler   Callback handler.
- (void)realtimeFetchConfigWithNoExpirationDuration:(NSInteger)fetchAttemptNumber
                                  completionHandler:(RCNConfigFetchCompletion)completionHandler;

/// Add the ability to update NSURLSession's timeout after a session has already been created.
- (void)recreateNetworkSession;

/// Provide fetchSession for tests to override.
@property(atomic, readwrite, strong, nonnull) NSURLSession *fetchSession;

/// Provide config template version number for Realtime config client.
@property(nonatomic, copy, nonnull) NSString *templateVersionNumber;

NS_ASSUME_NONNULL_END

@end
