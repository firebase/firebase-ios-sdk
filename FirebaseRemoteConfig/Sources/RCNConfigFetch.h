//
//  RCNConfig.h
//  Firebase Remote Config service SDK
//  Copyright 2015 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfig.h"
#import "third_party/firebase/ios/Releases/FirebaseInterop/Analytics/Public/FIRAnalyticsInterop.h"

@class FIROptions;
@class RCNConfigContent;
@class RCNConfigSettings;
@class RCNConfigExperiment;
@class RCNConfigDBManager;

NS_ASSUME_NONNULL_BEGIN

/// Completion handler invoked by NSSessionFetcher.
typedef void (^RCNConfigFetcherCompletion)(NSData *data, NSURLResponse *response, NSError *error);

/// Test block used for global NSSessionFetcher.
typedef void (^RCNConfigFetcherTestBlock)(RCNConfigFetcherCompletion completion);

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

/// Fetches all config data keyed by namespace. Completion block will be called on the main queue.
/// @param expirationDuration  Expiration duration, in seconds.
/// @param completionHandler   Callback handler.
- (void)fetchAllConfigsWithExpirationDuration:(NSTimeInterval)expirationDuration
                            completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler;

/// Add the ability to update NSURLSession's timeout after a session has already been created.
- (void)recreateNetworkSession;

/// Sets the test block to mock the fetch response instead of performing the fetch task from server.
+ (void)setGlobalTestBlock:(RCNConfigFetcherTestBlock)block;

NS_ASSUME_NONNULL_END

@end
