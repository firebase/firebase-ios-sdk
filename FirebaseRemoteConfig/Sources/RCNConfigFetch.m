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

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"

#import <GoogleUtilities/GULNSData+zlib.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"
#import "FirebaseRemoteConfig/Sources/RCNDevice.h"

#ifdef RCN_STAGING_SERVER
static NSString *const kServerURLDomain =
    @"https://staging-firebaseremoteconfig.sandbox.googleapis.com";
#else
static NSString *const kServerURLDomain = @"https://firebaseremoteconfig.googleapis.com";
#endif

static NSString *const kServerURLVersion = @"/v1";
static NSString *const kServerURLProjects = @"/projects/";
static NSString *const kServerURLNamespaces = @"/namespaces/";
static NSString *const kServerURLQuery = @":fetch?";
static NSString *const kServerURLKey = @"key=";
static NSString *const kRequestJSONKeyAppID = @"app_id";

static NSString *const kHTTPMethodPost = @"POST";  ///< HTTP request method config fetch using
static NSString *const kContentTypeHeaderName = @"Content-Type";  ///< HTTP Header Field Name
static NSString *const kContentEncodingHeaderName =
    @"Content-Encoding";                                                ///< HTTP Header Field Name
static NSString *const kAcceptEncodingHeaderName = @"Accept-Encoding";  ///< HTTP Header Field Name
static NSString *const kETagHeaderName = @"etag";                       ///< HTTP Header Field Name
static NSString *const kIfNoneMatchETagHeaderName = @"if-none-match";   ///< HTTP Header Field Name
static NSString *const kInstallationsAuthTokenHeaderName = @"x-goog-firebase-installations-auth";
// Sends the bundle ID. Refer to b/130301479 for details.
static NSString *const kiOSBundleIdentifierHeaderName =
    @"X-Ios-Bundle-Identifier";  ///< HTTP Header Field Name

static NSString *const kFetchTypeHeaderName =
    @"X-Firebase-RC-Fetch-Type";  ///< Custom Http header key to identify the fetch type
static NSString *const kBaseFetchType = @"BASE";          ///< Fetch identifier for Base Fetch
static NSString *const kRealtimeFetchType = @"REALTIME";  ///< Fetch identifier for Realtime Fetch

/// Config HTTP request content type proto buffer
static NSString *const kContentTypeValueJSON = @"application/json";

/// HTTP status codes. Ref: https://cloud.google.com/apis/design/errors#error_retries
static NSInteger const kRCNFetchResponseHTTPStatusCodeOK = 200;
static NSInteger const kRCNFetchResponseHTTPStatusTooManyRequests = 429;
static NSInteger const kRCNFetchResponseHTTPStatusCodeInternalError = 500;
static NSInteger const kRCNFetchResponseHTTPStatusCodeServiceUnavailable = 503;
static NSInteger const kRCNFetchResponseHTTPStatusCodeGatewayTimeout = 504;

#pragma mark - RCNConfig

@implementation RCNConfigFetch {
  RCNConfigContent *_content;
  RCNConfigSettings *_settings;
  id<FIRAnalyticsInterop> _analytics;
  RCNConfigExperiment *_experiment;
  dispatch_queue_t _lockQueue;  /// Guard the read/write operation.
  NSURLSession *_fetchSession;  /// Managed internally by the fetch instance.
  NSString *_FIRNamespace;
  FIROptions *_options;
  NSString *_templateVersionNumber;
}

- (instancetype)init {
  NSAssert(NO, @"Invalid initializer.");
  return nil;
}

/// Designated initializer
- (instancetype)initWithContent:(RCNConfigContent *)content
                      DBManager:(RCNConfigDBManager *)DBManager
                       settings:(RCNConfigSettings *)settings
                      analytics:(nullable id<FIRAnalyticsInterop>)analytics
                     experiment:(RCNConfigExperiment *)experiment
                          queue:(dispatch_queue_t)queue
                      namespace:(NSString *)FIRNamespace
                        options:(FIROptions *)options {
  self = [super init];
  if (self) {
    _FIRNamespace = FIRNamespace;
    _settings = settings;
    _analytics = analytics;
    _experiment = experiment;
    _lockQueue = queue;
    _content = content;
    _fetchSession = [self newFetchSession];
    _options = options;
    _templateVersionNumber = [self->_settings lastTemplateVersion];
  }
  return self;
}

/// Force a new NSURLSession creation for updated config.
- (void)recreateNetworkSession {
  if (_fetchSession) {
    [_fetchSession invalidateAndCancel];
  }
  _fetchSession = [self newFetchSession];
}

/// Return the current session. (Tests).
- (NSURLSession *)currentNetworkSession {
  return _fetchSession;
}

- (void)dealloc {
  [_fetchSession invalidateAndCancel];
}

#pragma mark - Fetch Config API

- (void)fetchConfigWithExpirationDuration:(NSTimeInterval)expirationDuration
                        completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  // Note: We expect the googleAppID to always be available.
  BOOL hasDeviceContextChanged =
      FIRRemoteConfigHasDeviceContextChanged(_settings.deviceContext, _options.googleAppID);

  __weak RCNConfigFetch *weakSelf = self;
  dispatch_async(_lockQueue, ^{
    RCNConfigFetch *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }

    // Check whether we are outside of the minimum fetch interval.
    if (![strongSelf->_settings hasMinimumFetchIntervalElapsed:expirationDuration] &&
        !hasDeviceContextChanged) {
      FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000051", @"Returning cached data.");
      return [strongSelf reportCompletionOnHandler:completionHandler
                                        withStatus:FIRRemoteConfigFetchStatusSuccess
                                         withError:nil];
    }

    // Check if a fetch is already in progress.
    if (strongSelf->_settings.isFetchInProgress) {
      // Check if we have some fetched data.
      if (strongSelf->_settings.lastFetchTimeInterval > 0) {
        FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000052",
                    @"A fetch is already in progress. Using previous fetch results.");
        return [strongSelf reportCompletionOnHandler:completionHandler
                                          withStatus:strongSelf->_settings.lastFetchStatus
                                           withError:nil];
      } else {
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000053",
                    @"A fetch is already in progress. Ignoring duplicate request.");
        return [strongSelf reportCompletionOnHandler:completionHandler
                                          withStatus:FIRRemoteConfigFetchStatusFailure
                                           withError:nil];
      }
    }

    // Check whether cache data is within throttle limit.
    if ([strongSelf->_settings shouldThrottle] && !hasDeviceContextChanged) {
      // Must set lastFetchStatus before FailReason.
      strongSelf->_settings.lastFetchStatus = FIRRemoteConfigFetchStatusThrottled;
      strongSelf->_settings.lastFetchError = FIRRemoteConfigErrorThrottled;
      NSTimeInterval throttledEndTime = strongSelf->_settings.exponentialBackoffThrottleEndTime;

      NSError *error =
          [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                              code:FIRRemoteConfigErrorThrottled
                          userInfo:@{
                            FIRRemoteConfigThrottledEndTimeInSecondsKey : @(throttledEndTime)
                          }];
      return [strongSelf reportCompletionOnHandler:completionHandler
                                        withStatus:strongSelf->_settings.lastFetchStatus
                                         withError:error];
    }
    strongSelf->_settings.isFetchInProgress = YES;
    NSString *fetchTypeHeader = [NSString stringWithFormat:@"%@/1", kBaseFetchType];
    [strongSelf refreshInstallationsTokenWithFetchHeader:fetchTypeHeader
                                       completionHandler:completionHandler
                                 updateCompletionHandler:nil];
  });
}

#pragma mark - Fetch helpers

- (void)realtimeFetchConfigWithNoExpirationDuration:(NSInteger)fetchAttemptNumber
                                  completionHandler:(RCNConfigFetchCompletion)completionHandler {
  // Note: We expect the googleAppID to always be available.
  BOOL hasDeviceContextChanged =
      FIRRemoteConfigHasDeviceContextChanged(_settings.deviceContext, _options.googleAppID);

  __weak RCNConfigFetch *weakSelf = self;
  dispatch_async(_lockQueue, ^{
    RCNConfigFetch *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }
    // Check whether cache data is within throttle limit.
    if ([strongSelf->_settings shouldThrottle] && !hasDeviceContextChanged) {
      // Must set lastFetchStatus before FailReason.
      strongSelf->_settings.lastFetchStatus = FIRRemoteConfigFetchStatusThrottled;
      strongSelf->_settings.lastFetchError = FIRRemoteConfigErrorThrottled;
      NSTimeInterval throttledEndTime = strongSelf->_settings.exponentialBackoffThrottleEndTime;

      NSError *error =
          [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                              code:FIRRemoteConfigErrorThrottled
                          userInfo:@{
                            FIRRemoteConfigThrottledEndTimeInSecondsKey : @(throttledEndTime)
                          }];
      return [strongSelf reportCompletionWithStatus:FIRRemoteConfigFetchStatusFailure
                                         withUpdate:nil
                                          withError:error
                                  completionHandler:nil
                            updateCompletionHandler:completionHandler];
    }
    strongSelf->_settings.isFetchInProgress = YES;

    NSString *fetchTypeHeader =
        [NSString stringWithFormat:@"%@/%ld", kRealtimeFetchType, (long)fetchAttemptNumber];
    [strongSelf refreshInstallationsTokenWithFetchHeader:fetchTypeHeader
                                       completionHandler:nil
                                 updateCompletionHandler:completionHandler];
  });
}

- (NSString *)FIRAppNameFromFullyQualifiedNamespace {
  return [[_FIRNamespace componentsSeparatedByString:@":"] lastObject];
}
/// Refresh installation ID token before fetching config. installation ID is now mandatory for fetch
/// requests to work.(b/14751422).
- (void)refreshInstallationsTokenWithFetchHeader:(NSString *)fetchTypeHeader
                               completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler
                         updateCompletionHandler:(RCNConfigFetchCompletion)updateCompletionHandler {
  FIRInstallations *installations = [FIRInstallations
      installationsWithApp:[FIRApp appNamed:[self FIRAppNameFromFullyQualifiedNamespace]]];
  if (!installations || !_options.GCMSenderID) {
    NSString *errorDescription = @"Failed to get GCMSenderID";
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000074", @"%@",
                [NSString stringWithFormat:@"%@", errorDescription]);
    self->_settings.isFetchInProgress = NO;
    return [self
        reportCompletionOnHandler:completionHandler
                       withStatus:FIRRemoteConfigFetchStatusFailure
                        withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                      code:FIRRemoteConfigErrorInternalError
                                                  userInfo:@{
                                                    NSLocalizedDescriptionKey : errorDescription
                                                  }]];
  }

  __weak RCNConfigFetch *weakSelf = self;
  FIRInstallationsTokenHandler installationsTokenHandler = ^(
      FIRInstallationsAuthTokenResult *tokenResult, NSError *error) {
    RCNConfigFetch *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }

    if (!tokenResult || !tokenResult.authToken || error) {
      NSString *errorDescription =
          [NSString stringWithFormat:@"Failed to get installations token. Error : %@.", error];
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000073", @"%@",
                  [NSString stringWithFormat:@"%@", errorDescription]);
      strongSelf->_settings.isFetchInProgress = NO;

      NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
      userInfo[NSLocalizedDescriptionKey] = errorDescription;
      userInfo[NSUnderlyingErrorKey] = error.userInfo[NSUnderlyingErrorKey];

      return [strongSelf
          reportCompletionOnHandler:completionHandler
                         withStatus:FIRRemoteConfigFetchStatusFailure
                          withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                        code:FIRRemoteConfigErrorInternalError
                                                    userInfo:userInfo]];
    }

    // We have a valid token. Get the backing installationID.
    [installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                  NSError *_Nullable error) {
      RCNConfigFetch *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      // Dispatch to the RC serial queue to update settings on the queue.
      dispatch_async(strongSelf->_lockQueue, ^{
        RCNConfigFetch *strongSelfQueue = weakSelf;
        if (strongSelfQueue == nil) {
          return;
        }

        // Update config settings with the IID and token.
        strongSelfQueue->_settings.configInstallationsToken = tokenResult.authToken;
        strongSelfQueue->_settings.configInstallationsIdentifier = identifier;

        if (!identifier || error) {
          NSString *errorDescription =
              [NSString stringWithFormat:@"Error getting iid : %@.", error];

          NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
          userInfo[NSLocalizedDescriptionKey] = errorDescription;
          userInfo[NSUnderlyingErrorKey] = error.userInfo[NSUnderlyingErrorKey];

          FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000055", @"%@",
                      [NSString stringWithFormat:@"%@", errorDescription]);
          strongSelfQueue->_settings.isFetchInProgress = NO;
          return [strongSelfQueue
              reportCompletionOnHandler:completionHandler
                             withStatus:FIRRemoteConfigFetchStatusFailure
                              withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                            code:FIRRemoteConfigErrorInternalError
                                                        userInfo:userInfo]];
        }

        FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000022", @"Success to get iid : %@.",
                   strongSelfQueue->_settings.configInstallationsIdentifier);
        [strongSelf doFetchCall:fetchTypeHeader
                  completionHandler:completionHandler
            updateCompletionHandler:updateCompletionHandler];
      });
    }];
  };

  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000039", @"Starting requesting token.");
  [installations authTokenWithCompletion:installationsTokenHandler];
}

- (void)doFetchCall:(NSString *)fetchTypeHeader
          completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler
    updateCompletionHandler:(RCNConfigFetchCompletion)updateCompletionHandler {
  [self getAnalyticsUserPropertiesWithCompletionHandler:^(NSDictionary *userProperties) {
    dispatch_async(self->_lockQueue, ^{
      [self fetchWithUserProperties:userProperties
                    fetchTypeHeader:fetchTypeHeader
                  completionHandler:completionHandler
            updateCompletionHandler:updateCompletionHandler];
    });
  }];
}

- (void)getAnalyticsUserPropertiesWithCompletionHandler:
    (FIRAInteropUserPropertiesCallback)completionHandler {
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000060", @"Fetch with user properties completed.");
  id<FIRAnalyticsInterop> analytics = self->_analytics;
  if (analytics == nil) {
    completionHandler(@{});
  } else {
    [analytics getUserPropertiesWithCallback:completionHandler];
  }
}

- (void)reportCompletionOnHandler:(FIRRemoteConfigFetchCompletion)completionHandler
                       withStatus:(FIRRemoteConfigFetchStatus)status
                        withError:(NSError *)error {
  [self reportCompletionWithStatus:status
                        withUpdate:nil
                         withError:error
                 completionHandler:completionHandler
           updateCompletionHandler:nil];
}

- (void)reportCompletionWithStatus:(FIRRemoteConfigFetchStatus)status
                        withUpdate:(FIRRemoteConfigUpdate *)update
                         withError:(NSError *)error
                 completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler
           updateCompletionHandler:(RCNConfigFetchCompletion)updateCompletionHandler {
  if (completionHandler) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completionHandler(status, error);
    });
  }
  // if completion handler expects a config update response
  if (updateCompletionHandler) {
    dispatch_async(dispatch_get_main_queue(), ^{
      updateCompletionHandler(status, update, error);
    });
  }
}

- (void)fetchWithUserProperties:(NSDictionary *)userProperties
                fetchTypeHeader:(NSString *)fetchTypeHeader
              completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler
        updateCompletionHandler:(RCNConfigFetchCompletion)updateCompletionHandler {
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000061", @"Fetch with user properties initiated.");

  NSString *postRequestString = [_settings nextRequestWithUserProperties:userProperties];

  // Get POST request content.
  NSData *content = [postRequestString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *compressionError;
  NSData *compressedContent = [NSData gul_dataByGzippingData:content error:&compressionError];
  if (compressionError) {
    NSString *errString = [NSString stringWithFormat:@"Failed to compress the config request."];
    FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000033", @"%@", errString);
    NSError *error = [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                         code:FIRRemoteConfigErrorInternalError
                                     userInfo:@{NSLocalizedDescriptionKey : errString}];

    self->_settings.isFetchInProgress = NO;
    return [self reportCompletionWithStatus:FIRRemoteConfigFetchStatusFailure
                                 withUpdate:nil
                                  withError:error
                          completionHandler:completionHandler
                    updateCompletionHandler:updateCompletionHandler];
  }

  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000040", @"Start config fetch.");
  __weak RCNConfigFetch *weakSelf = self;
  RCNConfigFetcherCompletion fetcherCompletion = ^(NSData *data, NSURLResponse *response,
                                                   NSError *error) {
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000050",
                @"config fetch completed. Error: %@ StatusCode: %ld", (error ? error : @"nil"),
                (long)[((NSHTTPURLResponse *)response) statusCode]);

    RCNConfigFetch *fetcherCompletionSelf = weakSelf;
    if (fetcherCompletionSelf == nil) {
      return;
    }

    // The fetch has completed.
    fetcherCompletionSelf->_settings.isFetchInProgress = NO;

    dispatch_async(fetcherCompletionSelf->_lockQueue, ^{
      RCNConfigFetch *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];

      if (error || (statusCode != kRCNFetchResponseHTTPStatusCodeOK)) {
        // Update metadata about fetch failure.
        [strongSelf->_settings updateMetadataWithFetchSuccessStatus:NO templateVersion:nil];
        if (error) {
          if (strongSelf->_settings.lastFetchStatus == FIRRemoteConfigFetchStatusSuccess) {
            FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000025",
                        @"RCN Fetch failure: %@. Using cached config result.", error);
          } else {
            FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000026",
                        @"RCN Fetch failure: %@. No cached config result.", error);
          }
        }
        if (statusCode != kRCNFetchResponseHTTPStatusCodeOK) {
          FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000026",
                      @"RCN Fetch failure. Response http error code: %ld", (long)statusCode);
          // Response error code 429, 500, 503 will trigger exponential backoff mode.
          // TODO: check error code in helper
          if (statusCode == kRCNFetchResponseHTTPStatusTooManyRequests ||
              statusCode == kRCNFetchResponseHTTPStatusCodeInternalError ||
              statusCode == kRCNFetchResponseHTTPStatusCodeServiceUnavailable ||
              statusCode == kRCNFetchResponseHTTPStatusCodeGatewayTimeout) {
            [strongSelf->_settings updateExponentialBackoffTime];
            if ([strongSelf->_settings shouldThrottle]) {
              // Must set lastFetchStatus before FailReason.
              strongSelf->_settings.lastFetchStatus = FIRRemoteConfigFetchStatusThrottled;
              strongSelf->_settings.lastFetchError = FIRRemoteConfigErrorThrottled;
              NSTimeInterval throttledEndTime =
                  strongSelf->_settings.exponentialBackoffThrottleEndTime;

              NSError *error = [NSError
                  errorWithDomain:FIRRemoteConfigErrorDomain
                             code:FIRRemoteConfigErrorThrottled
                         userInfo:@{
                           FIRRemoteConfigThrottledEndTimeInSecondsKey : @(throttledEndTime)
                         }];
              return [strongSelf reportCompletionWithStatus:strongSelf->_settings.lastFetchStatus
                                                 withUpdate:nil
                                                  withError:error
                                          completionHandler:completionHandler
                                    updateCompletionHandler:updateCompletionHandler];
            }
          }
        }
        // Return back the received error.
        // Must set lastFetchStatus before setting Fetch Error.
        strongSelf->_settings.lastFetchStatus = FIRRemoteConfigFetchStatusFailure;
        strongSelf->_settings.lastFetchError = FIRRemoteConfigErrorInternalError;
        NSMutableDictionary<NSErrorUserInfoKey, id> *userInfo = [NSMutableDictionary dictionary];
        userInfo[NSUnderlyingErrorKey] = error;
        userInfo[NSLocalizedDescriptionKey] =
            error.localizedDescription
                ?: [NSString
                       stringWithFormat:@"Internal Error. Status code: %ld", (long)statusCode];

        return [strongSelf
            reportCompletionWithStatus:FIRRemoteConfigFetchStatusFailure
                            withUpdate:nil
                             withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                           code:FIRRemoteConfigErrorInternalError
                                                       userInfo:userInfo]
                     completionHandler:completionHandler
               updateCompletionHandler:updateCompletionHandler];
      }

      // Fetch was successful. Check if we have data.
      NSError *retError;
      if (!data) {
        FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000043", @"RCN Fetch: No data in fetch response");
        // There may still be a difference between fetched and active config
        FIRRemoteConfigUpdate *update =
            [strongSelf->_content getConfigUpdateForNamespace:strongSelf->_FIRNamespace];
        return [strongSelf reportCompletionWithStatus:FIRRemoteConfigFetchStatusSuccess
                                           withUpdate:update
                                            withError:nil
                                    completionHandler:completionHandler
                              updateCompletionHandler:updateCompletionHandler];
      }

      // Config fetch succeeded.
      // JSONObjectWithData is always expected to return an NSDictionary in our case
      NSMutableDictionary *fetchedConfig =
          [NSJSONSerialization JSONObjectWithData:data
                                          options:NSJSONReadingMutableContainers
                                            error:&retError];
      if (retError) {
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000042",
                    @"RCN Fetch failure: %@. Could not parse response data as JSON", error);
      }

      // Check and log if we received an error from the server
      if (fetchedConfig && fetchedConfig.count == 1 && fetchedConfig[RCNFetchResponseKeyError]) {
        NSString *errStr = [NSString stringWithFormat:@"RCN Fetch Failure: Server returned error:"];
        NSDictionary *errDict = fetchedConfig[RCNFetchResponseKeyError];
        if (errDict[RCNFetchResponseKeyErrorCode]) {
          errStr = [errStr
              stringByAppendingString:[NSString
                                          stringWithFormat:@"code: %@",
                                                           errDict[RCNFetchResponseKeyErrorCode]]];
        }
        if (errDict[RCNFetchResponseKeyErrorStatus]) {
          errStr = [errStr stringByAppendingString:
                               [NSString stringWithFormat:@". Status: %@",
                                                          errDict[RCNFetchResponseKeyErrorStatus]]];
        }
        if (errDict[RCNFetchResponseKeyErrorMessage]) {
          errStr =
              [errStr stringByAppendingString:
                          [NSString stringWithFormat:@". Message: %@",
                                                     errDict[RCNFetchResponseKeyErrorMessage]]];
        }
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000044", @"%@.", errStr);
        NSError *error = [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                             code:FIRRemoteConfigErrorInternalError
                                         userInfo:@{NSLocalizedDescriptionKey : errStr}];
        return [strongSelf reportCompletionWithStatus:FIRRemoteConfigFetchStatusFailure
                                           withUpdate:nil
                                            withError:error
                                    completionHandler:completionHandler
                              updateCompletionHandler:updateCompletionHandler];
      }

      // Add the fetched config to the database.
      if (fetchedConfig) {
        // Update config content to cache and DB.
        [strongSelf->_content updateConfigContentWithResponse:fetchedConfig
                                                 forNamespace:strongSelf->_FIRNamespace];
        // Update experiments only for 3p namespace
        NSString *namespace = [strongSelf->_FIRNamespace
            substringToIndex:[strongSelf->_FIRNamespace rangeOfString:@":"].location];
        if ([namespace isEqualToString:FIRNamespaceGoogleMobilePlatform]) {
          [strongSelf->_experiment updateExperimentsWithResponse:
                                       fetchedConfig[RCNFetchResponseKeyExperimentDescriptions]];
        }

        strongSelf->_templateVersionNumber = [strongSelf getTemplateVersionNumber:fetchedConfig];
      } else {
        FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000063",
                    @"Empty response with no fetched config.");
      }

      // We had a successful fetch. Update the current eTag in settings if different.
      NSString *latestETag = ((NSHTTPURLResponse *)response).allHeaderFields[kETagHeaderName];
      if (!strongSelf->_settings.lastETag ||
          !([strongSelf->_settings.lastETag isEqualToString:latestETag])) {
        strongSelf->_settings.lastETag = latestETag;
      }
      // Compute config update after successful fetch
      FIRRemoteConfigUpdate *update =
          [strongSelf->_content getConfigUpdateForNamespace:strongSelf->_FIRNamespace];

      [strongSelf->_settings
          updateMetadataWithFetchSuccessStatus:YES
                               templateVersion:strongSelf->_templateVersionNumber];
      return [strongSelf reportCompletionWithStatus:FIRRemoteConfigFetchStatusSuccess
                                         withUpdate:update
                                          withError:nil
                                  completionHandler:completionHandler
                            updateCompletionHandler:updateCompletionHandler];
    });
  };

  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000061", @"Making remote config fetch.");

  NSURLSessionDataTask *dataTask = [self URLSessionDataTaskWithContent:compressedContent
                                                       fetchTypeHeader:fetchTypeHeader
                                                     completionHandler:fetcherCompletion];
  [dataTask resume];
}

- (NSString *)constructServerURL {
  NSString *serverURLStr = [[NSString alloc] initWithString:kServerURLDomain];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLVersion];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLProjects];
  serverURLStr = [serverURLStr stringByAppendingString:_options.projectID];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLNamespaces];

  // Get the namespace from the fully qualified namespace string of "namespace:FIRAppName".
  NSString *namespace =
      [_FIRNamespace substringToIndex:[_FIRNamespace rangeOfString:@":"].location];
  serverURLStr = [serverURLStr stringByAppendingString:namespace];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLQuery];

  if (_options.APIKey) {
    serverURLStr = [serverURLStr stringByAppendingString:kServerURLKey];
    serverURLStr = [serverURLStr stringByAppendingString:_options.APIKey];
  } else {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000071",
                @"Missing `APIKey` from `FirebaseOptions`, please ensure the configured "
                @"`FirebaseApp` is configured with `FirebaseOptions` that contains an `APIKey`.");
  }

  return serverURLStr;
}

- (NSURLSession *)newFetchSession {
  NSURLSessionConfiguration *config =
      [[NSURLSessionConfiguration defaultSessionConfiguration] copy];
  config.timeoutIntervalForRequest = _settings.fetchTimeout;
  config.timeoutIntervalForResource = _settings.fetchTimeout;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
  return session;
}

- (NSURLSessionDataTask *)URLSessionDataTaskWithContent:(NSData *)content
                                        fetchTypeHeader:(NSString *)fetchTypeHeader
                                      completionHandler:
                                          (RCNConfigFetcherCompletion)fetcherCompletion {
  NSURL *URL = [NSURL URLWithString:[self constructServerURL]];
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000046", @"%@",
              [NSString stringWithFormat:@"Making config request: %@", [URL absoluteString]]);

  NSTimeInterval timeoutInterval = _fetchSession.configuration.timeoutIntervalForResource;
  NSMutableURLRequest *URLRequest =
      [[NSMutableURLRequest alloc] initWithURL:URL
                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                               timeoutInterval:timeoutInterval];
  URLRequest.HTTPMethod = kHTTPMethodPost;
  [URLRequest setValue:kContentTypeValueJSON forHTTPHeaderField:kContentTypeHeaderName];
  [URLRequest setValue:_settings.configInstallationsToken
      forHTTPHeaderField:kInstallationsAuthTokenHeaderName];
  [URLRequest setValue:[[NSBundle mainBundle] bundleIdentifier]
      forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
  [URLRequest setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
  [URLRequest setValue:@"gzip" forHTTPHeaderField:kAcceptEncodingHeaderName];
  [URLRequest setValue:fetchTypeHeader forHTTPHeaderField:kFetchTypeHeaderName];
  // Set the eTag from the last successful fetch, if available.
  if (_settings.lastETag) {
    [URLRequest setValue:_settings.lastETag forHTTPHeaderField:kIfNoneMatchETagHeaderName];
  }
  [URLRequest setHTTPBody:content];

  return [_fetchSession dataTaskWithRequest:URLRequest completionHandler:fetcherCompletion];
}

- (NSString *)getTemplateVersionNumber:(NSDictionary *)fetchedConfig {
  if (fetchedConfig != nil && [fetchedConfig objectForKey:RCNFetchResponseKeyTemplateVersion] &&
      [[fetchedConfig objectForKey:RCNFetchResponseKeyTemplateVersion]
          isKindOfClass:[NSString class]]) {
    return (NSString *)[fetchedConfig objectForKey:RCNFetchResponseKeyTemplateVersion];
  }

  return @"0";
}

@end
