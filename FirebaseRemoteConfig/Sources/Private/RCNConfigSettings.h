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

#import <FirebaseRemoteConfig/FIRRemoteConfig.h>

@class RCNConfigDBManager;

/// This internal class contains a set of variables that are unique among all the config instances.
/// It also handles all metadata and internal metadata. This class is not thread safe and does not
/// inherently allow for synchronized accesss. Callers are responsible for synchronization
/// (currently using serial dispatch queues).
@interface RCNConfigSettings : NSObject

/// The time interval that config data stays fresh.
@property(nonatomic, readwrite, assign) NSTimeInterval minimumFetchInterval;

/// The timeout to set for outgoing fetch requests.
@property(nonatomic, readwrite, assign) NSTimeInterval fetchTimeout;
// The Google App ID of the configured FIRApp.
@property(nonatomic, readwrite, copy) NSString *googleAppID;
#pragma mark - Data required by config request.
/// Device authentication ID required by config request.
@property(nonatomic, copy) NSString *deviceAuthID;
/// Secret Token required by config request.
@property(nonatomic, copy) NSString *secretToken;
/// Device data version of checkin information.
@property(nonatomic, copy) NSString *deviceDataVersion;
/// InstallationsID.
@property(nonatomic, copy) NSString *configInstallationsIdentifier;
/// Installations token.
@property(nonatomic, copy) NSString *configInstallationsToken;

/// A list of successful fetch timestamps in milliseconds.
/// TODO Not used anymore. Safe to remove.
@property(nonatomic, readonly, copy) NSArray *successFetchTimes;
/// A list of failed fetch timestamps in milliseconds.
@property(nonatomic, readonly, copy) NSArray *failureFetchTimes;
/// Custom variable (aka App context digest). This is the pending custom variables request before
/// fetching.
@property(nonatomic, copy) NSDictionary *customVariables;
/// Cached internal metadata from internal metadata table. It contains customized information such
/// as HTTP connection timeout, HTTP read timeout, success/failure throttling rate and time
/// interval. Client has the default value of each parameters, they are only saved in
/// internalMetadata if they have been customize by developers.
@property(nonatomic, readonly, copy) NSDictionary *internalMetadata;
/// Device conditions since last successful fetch from the backend. Device conditions including
/// app
/// version, iOS version, device localte, language, GMP project ID and Game project ID. Used for
/// determing whether to throttle.
@property(nonatomic, readonly, copy) NSDictionary *deviceContext;
/// Bundle Identifier
@property(nonatomic, readonly, copy) NSString *bundleIdentifier;
/// The time of last successful config fetch.
@property(nonatomic, readonly, assign) NSTimeInterval lastFetchTimeInterval;
/// Last fetch status.
@property(nonatomic, readwrite, assign) FIRRemoteConfigFetchStatus lastFetchStatus;
/// The reason that last fetch failed.
@property(nonatomic, readwrite, assign) FIRRemoteConfigError lastFetchError;
/// The time of last apply timestamp.
@property(nonatomic, readwrite, assign) NSTimeInterval lastApplyTimeInterval;
/// The time of last setDefaults timestamp.
@property(nonatomic, readwrite, assign) NSTimeInterval lastSetDefaultsTimeInterval;
/// The latest eTag value stored from the last successful response.
@property(nonatomic, readwrite, assign) NSString *lastETag;
/// The timestamp of the last eTag update.
@property(nonatomic, readwrite, assign) NSTimeInterval lastETagUpdateTime;
/// Last fetched template version.
@property(nonatomic, readwrite, assign) NSString *lastFetchedTemplateVersion;
/// Last active template version.
@property(nonatomic, readwrite, assign) NSString *lastActiveTemplateVersion;

#pragma mark Throttling properties

/// Throttling intervals are based on https://cloud.google.com/storage/docs/exponential-backoff
/// Returns true if client has fetched config and has not got back from server. This is used to
/// determine whether there is another config task infight when fetching.
@property(atomic, readwrite, assign) BOOL isFetchInProgress;
/// Returns the current retry interval in seconds set for exponential backoff.
@property(nonatomic, readwrite, assign) double exponentialBackoffRetryInterval;
/// Returns the time in seconds until the next request is allowed while in exponential backoff mode.
@property(nonatomic, readonly, assign) NSTimeInterval exponentialBackoffThrottleEndTime;
/// Returns the current retry interval in seconds set for exponential backoff for the Realtime
/// service.
@property(nonatomic, readwrite, assign) double realtimeExponentialBackoffRetryInterval;
/// Returns the time in seconds until the next request is allowed while in exponential backoff mode
/// for the Realtime service.
@property(nonatomic, readonly, assign) NSTimeInterval realtimeExponentialBackoffThrottleEndTime;
/// Realtime connection attempts.
@property(nonatomic, readwrite, assign) int realtimeRetryCount;

#pragma mark Throttling Methods

/// Designated initializer.
- (instancetype)initWithDatabaseManager:(RCNConfigDBManager *)manager
                              namespace:(NSString *)FIRNamespace
                        firebaseAppName:(NSString *)appName
                            googleAppID:(NSString *)googleAppID;

/// Returns a fetch request with the latest device and config change.
/// Whenever user issues a fetch api call, collect the latest request.
/// @param userProperties  User properties to set to config request.
/// @return                Config fetch request string
- (NSString *)nextRequestWithUserProperties:(NSDictionary *)userProperties;

/// Returns metadata from metadata table.
- (NSDictionary *)loadConfigFromMetadataTable;

/// Updates internal content with the latest successful config response.
- (void)updateInternalContentWithResponse:(NSDictionary *)response;

/// Updates the metadata table with the current fetch status.
/// @param fetchSuccess True if fetch was successful.
- (void)updateMetadataWithFetchSuccessStatus:(BOOL)fetchSuccess
                             templateVersion:(NSString *)templateVersion;

/// Increases the throttling time. Should only be called if the fetch error indicates a server
/// issue.
- (void)updateExponentialBackoffTime;

/// Increases the throttling time for Realtime. Should only be called if the Realtime error
/// indicates a server issue.
- (void)updateRealtimeExponentialBackoffTime;

/// Update last active template version from last fetched template version.
- (void)updateLastActiveTemplateVersion;

/// Returns the difference between the Realtime backoff end time and the current time in a
/// NSTimeInterval format.
- (NSTimeInterval)getRealtimeBackoffInterval;

/// Returns true if we are in exponential backoff mode and it is not yet the next request time.
- (BOOL)shouldThrottle;

/// Returns true if the last fetch is outside the minimum fetch interval supplied.
- (BOOL)hasMinimumFetchIntervalElapsed:(NSTimeInterval)minimumFetchInterval;

@end
