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

#import "FirebaseRemoteConfig/Sources/RCNConfigFetch.h"

#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseInstanceID/FIRInstanceID+Private.h>
#import <FirebaseInstanceID/FIRInstanceIDCheckinPreferences.h>
#import <GoogleUtilities/GULNSData+zlib.h>
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
static NSString *const kRequestJSONKeyAppInstanceID = @"app_instance_id";

static NSString *const kHTTPMethodPost = @"POST";  ///< HTTP request method config fetch using
static NSString *const kContentTypeHeaderName = @"Content-Type";  ///< HTTP Header Field Name
static NSString *const kContentEncodingHeaderName =
    @"Content-Encoding";                                                ///< HTTP Header Field Name
static NSString *const kAcceptEncodingHeaderName = @"Accept-Encoding";  ///< HTTP Header Field Name
static NSString *const kETagHeaderName = @"etag";                       ///< HTTP Header Field Name
static NSString *const kIfNoneMatchETagHeaderName = @"if-none-match";   ///< HTTP Header Field Name
// Sends the bundle ID. Refer to b/130301479 for details.
static NSString *const kiOSBundleIdentifierHeaderName =
    @"X-Ios-Bundle-Identifier";  ///< HTTP Header Field Name

/// Config HTTP request content type proto buffer
static NSString *const kContentTypeValueJSON = @"application/json";
static NSString *const kInstanceIDScopeConfig = @"*";  /// InstanceID scope

/// HTTP status codes. Ref: https://cloud.google.com/apis/design/errors#error_retries
static NSInteger const kRCNFetchResponseHTTPStatusCodeOK = 200;
static NSInteger const kRCNFetchResponseHTTPStatusTooManyRequests = 429;
static NSInteger const kRCNFetchResponseHTTPStatusCodeInternalError = 500;
static NSInteger const kRCNFetchResponseHTTPStatusCodeServiceUnavailable = 503;
static NSInteger const kRCNFetchResponseHTTPStatusCodeGatewayTimeout = 504;

// Deprecated error code previously from FirebaseCore
static const NSInteger FIRErrorCodeConfigFailed = -114;

static RCNConfigFetcherTestBlock gGlobalTestBlock;

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
  RCNConfigFetch *fetchWithExpirationSelf = weakSelf;
  dispatch_async(fetchWithExpirationSelf->_lockQueue, ^{
    RCNConfigFetch *strongSelf = fetchWithExpirationSelf;

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
        NSError *error =
            [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                code:FIRErrorCodeConfigFailed
                            userInfo:@{
                              @"FetchError" : @"Duplicate request while the previous one is pending"
                            }];
        return [strongSelf reportCompletionOnHandler:completionHandler
                                          withStatus:FIRRemoteConfigFetchStatusFailure
                                           withError:error];
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
    [strongSelf refreshInstanceIDTokenAndFetchCheckInInfoWithCompletionHandler:completionHandler];
  });
}

#pragma mark - Fetch helpers

/// Refresh instance ID token before fetching config. Instance ID is an optional field in config
/// request.
- (void)refreshInstanceIDTokenAndFetchCheckInInfoWithCompletionHandler:
    (FIRRemoteConfigFetchCompletion)completionHandler {
  FIRInstanceID *instanceID = [FIRInstanceID instanceID];
  // Only refresh instance ID when a valid sender ID is provided. If not, continue without
  // fetching instance ID. Instance ID is for data analytics purpose, which is only optional for
  // config fetching.
  if (!_options.GCMSenderID) {
    [self fetchCheckinInfoWithCompletionHandler:completionHandler];
    return;
  }
  FIRInstanceIDTokenHandler instanceIDHandler = ^(NSString *token, NSError *error) {
    if (error) {
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000020",
                  @"Failed to register InstanceID with error : %@.", error);
    }

    // If the token is available, try to get the instanceID.
    __weak RCNConfigFetch *weakSelf = self;
    if (token) {
      [instanceID getIDWithHandler:^(NSString *_Nullable identity, NSError *_Nullable error) {
        RCNConfigFetch *strongSelf = weakSelf;

        // Dispatch to the RC serial queue to update settings on the queue.
        dispatch_async(strongSelf->_lockQueue, ^{
          RCNConfigFetch *strongSelfQueue = weakSelf;

          // Update config settings with the IID and token.
          strongSelfQueue->_settings.configInstanceIDToken = [token copy];
          strongSelfQueue->_settings.configInstanceID = identity;

          if (identity && !error) {
            FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000022", @"Success to get iid : %@.",
                       strongSelfQueue->_settings.configInstanceID);
          } else {
            FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000055", @"Error getting iid : %@.",
                          error);
          }

          // Continue the fetch regardless of whether fetch of instance ID succeeded.
          [strongSelfQueue fetchCheckinInfoWithCompletionHandler:completionHandler];
        });
      }];

    } else {
      dispatch_async(self->_lockQueue, ^{
        RCNConfigFetch *strongSelfQueue = weakSelf;
        // Continue the fetch regardless of whether fetch of instance ID succeeded.
        [strongSelfQueue fetchCheckinInfoWithCompletionHandler:completionHandler];
      });
    }
  };
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000039", @"Starting requesting token.");
  // Note: We expect the GCMSenderID to always be available by the time this request is made.
  [instanceID tokenWithAuthorizedEntity:_options.GCMSenderID
                                  scope:kInstanceIDScopeConfig
                                options:nil
                                handler:instanceIDHandler];
}

/// Fetch checkin info before fetching config. Checkin info including device authentication ID,
/// secret token and device data version are optional fields in config request.
- (void)fetchCheckinInfoWithCompletionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  FIRInstanceID *instanceID = [FIRInstanceID instanceID];
  __weak RCNConfigFetch *weakSelf = self;
  [instanceID fetchCheckinInfoWithHandler:^(FIRInstanceIDCheckinPreferences *preferences,
                                            NSError *error) {
    RCNConfigFetch *fetchCheckinInfoWithHandlerSelf = weakSelf;
    dispatch_async(fetchCheckinInfoWithHandlerSelf->_lockQueue, ^{
      RCNConfigFetch *strongSelf = fetchCheckinInfoWithHandlerSelf;
      if (error) {
        FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000023", @"Failed to fetch checkin info: %@.",
                    error);
      } else {
        strongSelf->_settings.deviceAuthID = preferences.deviceID;
        strongSelf->_settings.secretToken = preferences.secretToken;
        strongSelf->_settings.deviceDataVersion = preferences.deviceDataVersion;
        if (strongSelf->_settings.deviceAuthID.length && strongSelf->_settings.secretToken.length) {
          FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000024",
                     @"Success to get device authentication ID: %@, security token: %@.",
                     self->_settings.deviceAuthID, self->_settings.secretToken);
        }
      }
      // Checkin info is optional, continue fetch config regardless fetch of checkin info
      // succeeded.
      [strongSelf fetchWithUserPropertiesCompletionHandler:^(NSDictionary *userProperties) {
        dispatch_async(strongSelf->_lockQueue, ^{
          [strongSelf fetchWithUserProperties:userProperties completionHandler:completionHandler];
        });
      }];
    });
  }];
}

- (void)fetchWithUserPropertiesCompletionHandler:
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
  if (completionHandler) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completionHandler(status, error);
    });
  }
}

- (void)fetchWithUserProperties:(NSDictionary *)userProperties
              completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler {
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000061", @"Fetch with user properties initiated.");

  NSString *postRequestString = [_settings nextRequestWithUserProperties:userProperties];

  // Get POST request content.
  NSData *content = [postRequestString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *compressionError;
  NSData *compressedContent = [NSData gul_dataByGzippingData:content error:&compressionError];
  if (compressionError) {
    NSString *errString = [NSString stringWithFormat:@"Failed to compress the config request."];
    FIRLogWarning(kFIRLoggerRemoteConfig, @"I-RCN000033", @"%@", errString);

    return [self
        reportCompletionOnHandler:completionHandler
                       withStatus:FIRRemoteConfigFetchStatusFailure
                        withError:[NSError
                                      errorWithDomain:FIRRemoteConfigErrorDomain
                                                 code:FIRRemoteConfigErrorInternalError
                                             userInfo:@{NSLocalizedDescriptionKey : errString}]];
  }

  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000040", @"Start config fetch.");
  __weak RCNConfigFetch *weakSelf = self;
  RCNConfigFetcherCompletion fetcherCompletion = ^(NSData *data, NSURLResponse *response,
                                                   NSError *error) {
    FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000050",
                @"config fetch completed. Error: %@ StatusCode: %ld", (error ? error : @"nil"),
                (long)[((NSHTTPURLResponse *)response) statusCode]);
    RCNConfigFetch *fetcherCompletionSelf = weakSelf;
    if (!fetcherCompletionSelf) {
      return;
    };

    dispatch_async(fetcherCompletionSelf->_lockQueue, ^{
      RCNConfigFetch *strongSelf = weakSelf;
      if (!strongSelf) {
        return;
      }

      strongSelf->_settings.isFetchInProgress = NO;
      NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];

      if (error || (statusCode != kRCNFetchResponseHTTPStatusCodeOK)) {
        // Update metadata about fetch failure.
        [strongSelf->_settings updateMetadataWithFetchSuccessStatus:NO];
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
          if (statusCode == kRCNFetchResponseHTTPStatusTooManyRequests ||
              statusCode == kRCNFetchResponseHTTPStatusCodeInternalError ||
              statusCode == kRCNFetchResponseHTTPStatusCodeServiceUnavailable ||
              statusCode == kRCNFetchResponseHTTPStatusCodeGatewayTimeout) {
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
              return [strongSelf reportCompletionOnHandler:completionHandler
                                                withStatus:strongSelf->_settings.lastFetchStatus
                                                 withError:error];
            }
          }  // Response error code 429, 500, 503
        }    // StatusCode != kRCNFetchResponseHTTPStatusCodeOK
        // Return back the received error.
        // Must set lastFetchStatus before setting Fetch Error.
        strongSelf->_settings.lastFetchStatus = FIRRemoteConfigFetchStatusFailure;
        strongSelf->_settings.lastFetchError = FIRRemoteConfigErrorInternalError;
        NSDictionary<NSErrorUserInfoKey, id> *userInfo = @{
          NSLocalizedDescriptionKey :
              (error ? [error localizedDescription]
                     : [NSString
                           stringWithFormat:@"Internal Error. Status code: %ld", (long)statusCode])
        };
        return [strongSelf
            reportCompletionOnHandler:completionHandler
                           withStatus:FIRRemoteConfigFetchStatusFailure
                            withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                          code:FIRRemoteConfigErrorInternalError
                                                      userInfo:userInfo]];
      }

      // Fetch was successful. Check if we have data.
      NSError *retError;
      if (!data) {
        FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000043", @"RCN Fetch: No data in fetch response");
        return [strongSelf reportCompletionOnHandler:completionHandler
                                          withStatus:FIRRemoteConfigFetchStatusSuccess
                                           withError:nil];
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
        return [strongSelf
            reportCompletionOnHandler:completionHandler
                           withStatus:FIRRemoteConfigFetchStatusFailure
                            withError:[NSError
                                          errorWithDomain:FIRRemoteConfigErrorDomain
                                                     code:FIRRemoteConfigErrorInternalError
                                                 userInfo:@{NSLocalizedDescriptionKey : errStr}]];
      }

      // Add the fetched config to the database.
      if (fetchedConfig) {
        // Update config content to cache and DB.
        [self->_content updateConfigContentWithResponse:fetchedConfig
                                           forNamespace:self->_FIRNamespace];
        // Update experiments.
        [strongSelf->_experiment
            updateExperimentsWithResponse:fetchedConfig[RCNFetchResponseKeyExperimentDescriptions]];
      } else {
        FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000063",
                    @"Empty response with no fetched config.");
      }

      // We had a successful fetch. Update the current eTag in settings if different.
      NSString *latestETag = ((NSHTTPURLResponse *)response).allHeaderFields[kETagHeaderName];
      if (!self->_settings.lastETag || !([self->_settings.lastETag isEqualToString:latestETag])) {
        self->_settings.lastETag = latestETag;
      }

      [self->_settings updateMetadataWithFetchSuccessStatus:YES];
      return [strongSelf reportCompletionOnHandler:completionHandler
                                        withStatus:FIRRemoteConfigFetchStatusSuccess
                                         withError:nil];
    });
  };

  if (gGlobalTestBlock) {
    gGlobalTestBlock(fetcherCompletion);
    return;
  }
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000061", @"Making remote config fetch.");

  NSURLSessionDataTask *dataTask = [self URLSessionDataTaskWithContent:compressedContent
                                                     completionHandler:fetcherCompletion];
  [dataTask resume];
}

+ (void)setGlobalTestBlock:(RCNConfigFetcherTestBlock)block {
  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000027",
              @"Set global test block for NSSessionFetcher, it will not fetch from server.");
  gGlobalTestBlock = [block copy];
}

- (NSString *)constructServerURL {
  NSString *serverURLStr = [[NSString alloc] initWithString:kServerURLDomain];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLVersion];

  if (_options.projectID) {
    serverURLStr = [serverURLStr stringByAppendingString:kServerURLProjects];
    serverURLStr = [serverURLStr stringByAppendingString:_options.projectID];
  } else {
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000070",
                @"Missing `projectID` from `FirebaseOptions`, please ensure the configured "
                @"`FirebaseApp` is configured with `FirebaseOptions` that contains a `projectID`.");
  }

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
  [URLRequest setValue:[[NSBundle mainBundle] bundleIdentifier]
      forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
  [URLRequest setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
  [URLRequest setValue:@"gzip" forHTTPHeaderField:kAcceptEncodingHeaderName];
  // Set the eTag from the last successful fetch, if available.
  if (_settings.lastETag) {
    [URLRequest setValue:_settings.lastETag forHTTPHeaderField:kIfNoneMatchETagHeaderName];
  }
  [URLRequest setHTTPBody:content];

  return [_fetchSession dataTaskWithRequest:URLRequest completionHandler:fetcherCompletion];
}

@end
