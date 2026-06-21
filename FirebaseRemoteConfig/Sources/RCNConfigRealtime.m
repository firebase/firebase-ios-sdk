/*
 * Copyright 2022 Google LLC
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

#import "FirebaseRemoteConfig/Sources/RCNConfigRealtime.h"
#import <Foundation/Foundation.h>
#import <GoogleUtilities/GULNSData+zlib.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNDevice.h"

/// URL params
static NSString *const kServerURLDomain = @"https://firebaseremoteconfigrealtime.googleapis.com";
static NSString *const kServerURLVersion = @"/v1";
static NSString *const kServerURLProjects = @"/projects/";
static NSString *const kServerURLNamespaces = @"/namespaces/";
static NSString *const kServerURLQuery = @":streamFetchInvalidations?";
static NSString *const kServerURLKey = @"key=";

/// Realtime API enablement
static NSString *const kServerForbiddenStatusCode = @"\"code\": 403";

/// Header names
static NSString *const kHTTPMethodPost = @"POST";  ///< HTTP request method config fetch using
static NSString *const kContentTypeHeaderName = @"Content-Type";  ///< HTTP Header Field Name
static NSString *const kContentEncodingHeaderName =
    @"Content-Encoding";                                               ///< HTTP Header Field Name
static NSString *const kAcceptEncodingHeaderName = @"Accept";          ///< HTTP Header Field Name
static NSString *const kETagHeaderName = @"etag";                      ///< HTTP Header Field Name
static NSString *const kIfNoneMatchETagHeaderName = @"if-none-match";  ///< HTTP Header Field Name
static NSString *const kInstallationsAuthTokenHeaderName = @"x-goog-firebase-installations-auth";
// Sends the bundle ID. Refer to b/130301479 for details.
static NSString *const kiOSBundleIdentifierHeaderName =
    @"X-Ios-Bundle-Identifier";  ///< HTTP Header Field Name

/// Retryable HTTP status code.
static NSInteger const kRCNFetchResponseHTTPStatusOk = 200;
static NSInteger const kRCNFetchResponseHTTPStatusClientTimeout = 429;
static NSInteger const kRCNFetchResponseHTTPStatusTooManyRequests = 429;
static NSInteger const kRCNFetchResponseHTTPStatusCodeBadGateway = 502;
static NSInteger const kRCNFetchResponseHTTPStatusCodeServiceUnavailable = 503;
static NSInteger const kRCNFetchResponseHTTPStatusCodeGatewayTimeout = 504;

/// Invalidation message field names.
static NSString *const kTemplateVersionNumberKey = @"latestTemplateVersionNumber";
static NSString *const kIsFeatureDisabled = @"featureDisabled";
static NSString *const kRealtime_Retry_Interval = @"retryIntervalSeconds";

static NSTimeInterval gTimeoutSeconds = 330;
static NSInteger const gFetchAttempts = 3;

// Retry parameters
static NSInteger const gMaxRetries = 7;

@interface FIRConfigUpdateListenerRegistration ()
@property(strong, atomic, nonnull) RCNConfigUpdateCompletion completionHandler;
@end

@implementation FIRConfigUpdateListenerRegistration {
  RCNConfigRealtime *_realtimeClient;
}

- (instancetype)initWithClient:(RCNConfigRealtime *)realtimeClient
             completionHandler:(RCNConfigUpdateCompletion)completionHandler {
  self = [super init];
  if (self) {
    _realtimeClient = realtimeClient;
    _completionHandler = completionHandler;
  }
  return self;
}

- (void)remove {
  [self->_realtimeClient removeConfigUpdateListener:_completionHandler];
}

@end

@interface RCNConfigRealtime ()

@property(strong, atomic, nonnull) NSMutableSet<RCNConfigUpdateCompletion> *listeners;
@property(strong, atomic, nonnull) dispatch_queue_t realtimeLockQueue;
@property(strong, atomic, nonnull) NSNotificationCenter *notificationCenter;

@property(strong, atomic) NSURLSession *session;
@property(strong, atomic) NSURLSessionDataTask *dataTask;
@property(strong, atomic) NSMutableURLRequest *request;

@end

@implementation RCNConfigRealtime {
  RCNConfigFetch *_configFetch;
  RCNConfigSettings *_settings;
  FIROptions *_options;
  NSString *_namespace;
  NSInteger _remainingRetryCount;
  bool _isRequestInProgress;
  bool _isInBackground;
  bool _isRealtimeDisabled;
}

- (instancetype)init:(RCNConfigFetch *)configFetch
            settings:(RCNConfigSettings *)settings
           namespace:(NSString *)namespace
             options:(FIROptions *)options {
  self = [super init];
  if (self) {
    _listeners = [[NSMutableSet alloc] init];
    _realtimeLockQueue = [RCNConfigRealtime realtimeRemoteConfigSerialQueue];
    _notificationCenter = [NSNotificationCenter defaultCenter];

    _configFetch = configFetch;
    _settings = settings;
    _options = options;
    _namespace = namespace;

    _remainingRetryCount = MAX(gMaxRetries - [_settings realtimeRetryCount], 1);
    _isRequestInProgress = false;
    _isRealtimeDisabled = false;
    _isInBackground = false;

    [self setUpHttpRequest];
    [self setUpHttpSession];
    [self backgroundChangeListener];
  }

  return self;
}

/// Singleton instance of serial queue for queuing all incoming RC calls.
+ (dispatch_queue_t)realtimeRemoteConfigSerialQueue {
  static dispatch_once_t onceToken;
  static dispatch_queue_t realtimeRemoteConfigQueue;
  dispatch_once(&onceToken, ^{
    realtimeRemoteConfigQueue =
        dispatch_queue_create(RCNRemoteConfigQueueLabel, DISPATCH_QUEUE_SERIAL);
  });
  return realtimeRemoteConfigQueue;
}

- (void)propagateErrors:(NSError *)error {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    for (RCNConfigUpdateCompletion listener in strongSelf->_listeners) {
      listener(nil, error);
    }
  });
}

#pragma mark - Test Only Helpers

// TESTING ONLY
- (void)triggerListenerForTesting:(void (^_Nonnull)(FIRRemoteConfigUpdate *configUpdate,
                                                    NSError *_Nullable error))listener {
  listener([[FIRRemoteConfigUpdate alloc] init], nil);
}

#pragma mark - Http Helpers

- (NSString *)constructServerURL {
  NSString *serverURLStr = [[NSString alloc] initWithString:kServerURLDomain];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLVersion];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLProjects];
  serverURLStr = [serverURLStr stringByAppendingString:_options.GCMSenderID];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLNamespaces];

  /// Get the namespace from the fully qualified namespace string of "namespace:FIRAppName".
  NSString *namespace = [_namespace substringToIndex:[_namespace rangeOfString:@":"].location];
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

- (NSString *)FIRAppNameFromFullyQualifiedNamespace {
  return [[_namespace componentsSeparatedByString:@":"] lastObject];
}

- (void)reportCompletionOnHandler:(FIRRemoteConfigFetchCompletion)completionHandler
                       withStatus:(FIRRemoteConfigFetchStatus)status
                        withError:(NSError *)error {
  if (completionHandler) {
    dispatch_async(_realtimeLockQueue, ^{
      completionHandler(status, error);
    });
  }
}

/// Refresh installation ID token before fetching config. installation ID is now mandatory for fetch
/// requests to work.(b/14751422).
- (void)refreshInstallationsTokenWithCompletionHandler:
    (FIRRemoteConfigFetchCompletion)completionHandler {
  FIRInstallations *installations = [FIRInstallations
      installationsWithApp:[FIRApp appNamed:[self FIRAppNameFromFullyQualifiedNamespace]]];
  if (!installations || !_options.GCMSenderID) {
    NSString *errorDescription = @"Failed to get GCMSenderID";
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000074", @"%@",
                [NSString stringWithFormat:@"%@", errorDescription]);
    return [self
        reportCompletionOnHandler:completionHandler
                       withStatus:FIRRemoteConfigFetchStatusFailure
                        withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                      code:FIRRemoteConfigErrorInternalError
                                                  userInfo:@{
                                                    NSLocalizedDescriptionKey : errorDescription
                                                  }]];
  }

  __weak RCNConfigRealtime *weakSelf = self;
  FIRInstallationsTokenHandler installationsTokenHandler = ^(
      FIRInstallationsAuthTokenResult *tokenResult, NSError *error) {
    RCNConfigRealtime *strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }

    if (!tokenResult || !tokenResult.authToken || error) {
      NSString *errorDescription =
          [NSString stringWithFormat:@"Failed to get installations token. Error : %@.", error];
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000073", @"%@",
                  [NSString stringWithFormat:@"%@", errorDescription]);
      return [strongSelf
          reportCompletionOnHandler:completionHandler
                         withStatus:FIRRemoteConfigFetchStatusFailure
                          withError:[NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                                        code:FIRRemoteConfigErrorInternalError
                                                    userInfo:@{
                                                      NSLocalizedDescriptionKey : errorDescription
                                                    }]];
    }

    /// We have a valid token. Get the backing installationID.
    [installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                  NSError *_Nullable error) {
      RCNConfigRealtime *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      // Dispatch to the RC serial queue to update settings on the queue.
      dispatch_async(strongSelf->_realtimeLockQueue, ^{
        RCNConfigRealtime *strongSelfQueue = weakSelf;
        if (strongSelfQueue == nil) {
          return;
        }

        /// Update config settings with the IID and token.
        strongSelfQueue->_settings.configInstallationsToken = tokenResult.authToken;
        strongSelfQueue->_settings.configInstallationsIdentifier = identifier;

        if (!identifier || error) {
          NSString *errorDescription =
              [NSString stringWithFormat:@"Error getting iid : %@.", error];
          FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000055", @"%@",
                      [NSString stringWithFormat:@"%@", errorDescription]);
          strongSelfQueue->_settings.isFetchInProgress = NO;
          return [strongSelfQueue
              reportCompletionOnHandler:completionHandler
                             withStatus:FIRRemoteConfigFetchStatusFailure
                              withError:[NSError
                                            errorWithDomain:FIRRemoteConfigErrorDomain
                                                       code:FIRRemoteConfigErrorInternalError
                                                   userInfo:@{
                                                     NSLocalizedDescriptionKey : errorDescription
                                                   }]];
        }

        FIRLogInfo(kFIRLoggerRemoteConfig, @"I-RCN000022", @"Success to get iid : %@.",
                   strongSelfQueue->_settings.configInstallationsIdentifier);
        return [strongSelfQueue reportCompletionOnHandler:completionHandler
                                               withStatus:FIRRemoteConfigFetchStatusNoFetchYet
                                                withError:nil];
      });
    }];
  };

  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000039", @"Starting requesting token.");
  [installations authTokenWithCompletion:installationsTokenHandler];
}

- (void)createRequestBodyWithCompletion:(void (^)(NSData *_Nonnull requestBody))completion {
  __weak __typeof(self) weakSelf = self;
  [self refreshInstallationsTokenWithCompletionHandler:^(FIRRemoteConfigFetchStatus status,
                                                         NSError *_Nullable error) {
    __strong __typeof(self) strongSelf = weakSelf;
    if (!strongSelf) return;

    if (![strongSelf->_settings.configInstallationsIdentifier length]) {
      FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000013",
                  @"Installation token retrieval failed. Realtime connection will not include "
                  @"valid installations token.");
    }

    [strongSelf.request setValue:strongSelf->_settings.configInstallationsToken
              forHTTPHeaderField:kInstallationsAuthTokenHeaderName];
    if (strongSelf->_settings.lastETag) {
      [strongSelf.request setValue:strongSelf->_settings.lastETag
                forHTTPHeaderField:kIfNoneMatchETagHeaderName];
    }

    NSString *namespace = [strongSelf->_namespace
        substringToIndex:[strongSelf->_namespace rangeOfString:@":"].location];
    NSString *postBody = [NSString
        stringWithFormat:@"{project:'%@', namespace:'%@', lastKnownVersionNumber:'%@', appId:'%@', "
                         @"sdkVersion:'%@', appInstanceId:'%@'}",
                         [strongSelf->_options GCMSenderID], namespace,
                         strongSelf->_configFetch.templateVersionNumber,
                         strongSelf->_options.googleAppID, FIRRemoteConfigPodVersion(),
                         strongSelf->_settings.configInstallationsIdentifier];
    NSData *postData = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    NSError *compressionError;
    completion([NSData gul_dataByGzippingData:postData error:&compressionError]);
  }];
}

/// Creates request.
- (void)setUpHttpRequest {
  NSString *address = [self constructServerURL];
  _request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:address]
                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                      timeoutInterval:gTimeoutSeconds];
  [_request setHTTPMethod:kHTTPMethodPost];
  [_request setValue:@"application/json" forHTTPHeaderField:kContentTypeHeaderName];
  [_request setValue:@"application/json" forHTTPHeaderField:kAcceptEncodingHeaderName];
  [_request setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
  [_request setValue:@"true" forHTTPHeaderField:@"X-Google-GFE-Can-Retry"];
  [_request setValue:[_options APIKey] forHTTPHeaderField:@"X-Goog-Api-Key"];
  [_request setValue:[[NSBundle mainBundle] bundleIdentifier]
      forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
}

/// Makes call to create session.
- (void)setUpHttpSession {
  NSURLSessionConfiguration *sessionConfig =
      [[NSURLSessionConfiguration defaultSessionConfiguration] copy];
  [sessionConfig setTimeoutIntervalForResource:gTimeoutSeconds];
  [sessionConfig setTimeoutIntervalForRequest:gTimeoutSeconds];
  _session = [NSURLSession sessionWithConfiguration:sessionConfig
                                           delegate:self
                                      delegateQueue:[NSOperationQueue mainQueue]];
}

#pragma mark - Retry Helpers

- (BOOL)canMakeConnection {
  BOOL noRunningConnection =
      self->_dataTask == nil || self->_dataTask.state != NSURLSessionTaskStateRunning;
  BOOL canMakeConnection = noRunningConnection && [self->_listeners count] > 0 &&
                           !self->_isInBackground && !self->_isRealtimeDisabled;
  return canMakeConnection;
}

// Retry mechanism for HTTP connections
- (void)retryHTTPConnection {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    if (!strongSelf || strongSelf->_isInBackground) {
      return;
    }

    if ([strongSelf canMakeConnection] && strongSelf->_remainingRetryCount > 0) {
      NSTimeInterval backOffInterval = self->_settings.getRealtimeBackoffInterval;

      strongSelf->_remainingRetryCount--;
      [strongSelf->_settings setRealtimeRetryCount:[strongSelf->_settings realtimeRetryCount] + 1];
      dispatch_time_t executionDelay =
          dispatch_time(DISPATCH_TIME_NOW, (backOffInterval * NSEC_PER_SEC));
      dispatch_after(executionDelay, strongSelf->_realtimeLockQueue, ^{
        [strongSelf beginRealtimeStream];
      });
    } else {
      NSError *error = [NSError
          errorWithDomain:FIRRemoteConfigUpdateErrorDomain
                     code:FIRRemoteConfigUpdateErrorStreamError
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"Unable to connect to the server. Check your connection and try again."
                 }];
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000014", @"Cannot establish connection. Error: %@",
                  error);
      [self propagateErrors:error];
    }
  });
}

- (void)backgroundChangeListener {
  [_notificationCenter addObserver:self
                          selector:@selector(isInForeground)
                              name:@"UIApplicationWillEnterForegroundNotification"
                            object:nil];

  [_notificationCenter addObserver:self
                          selector:@selector(isInBackground)
                              name:@"UIApplicationDidEnterBackgroundNotification"
                            object:nil];
}

- (void)isInForeground {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    strongSelf->_isInBackground = false;
    [strongSelf beginRealtimeStream];
  });
}

- (void)isInBackground {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf pauseRealtimeStream];
    strongSelf->_isInBackground = true;
  });
}

#pragma mark - Autofetch Helpers

- (void)fetchLatestConfig:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    NSInteger attempts = remainingAttempts - 1;

    [strongSelf->_configFetch
        realtimeFetchConfigWithNoExpirationDuration:gFetchAttempts - attempts
                                  completionHandler:^(FIRRemoteConfigFetchStatus status,
                                                      FIRRemoteConfigUpdate *update,
                                                      NSError *error) {
                                    if (error != nil) {
                                      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000010",
                                                  @"Failed to retrieve config due to fetch error. "
                                                  @"Error: %@",
                                                  error);
                                      return [self propagateErrors:error];
                                    }
                                    if (status == FIRRemoteConfigFetchStatusSuccess) {
                                      if ([strongSelf->_configFetch.templateVersionNumber
                                                  integerValue] >= targetVersion) {
                                        // only notify listeners if there is a change
                                        if ([update updatedKeys].count > 0) {
                                          dispatch_async(strongSelf->_realtimeLockQueue, ^{
                                            for (RCNConfigUpdateCompletion listener in strongSelf
                                                     ->_listeners) {
                                              listener(update, nil);
                                            }
                                          });
                                        }
                                      } else {
                                        FIRLogDebug(
                                            kFIRLoggerRemoteConfig, @"I-RCN000016",
                                            @"Fetched config's template version is outdated, "
                                            @"re-fetching");
                                        [strongSelf autoFetch:attempts targetVersion:targetVersion];
                                      }
                                    } else {
                                      FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000016",
                                                  @"Fetched config's template version is "
                                                  @"outdated, re-fetching");
                                      [strongSelf autoFetch:attempts targetVersion:targetVersion];
                                    }
                                  }];
  });
}

- (void)scheduleFetch:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion {
  /// Needs fetch to occur between 0 - 3 seconds. Randomize to not cause DDoS alerts in backend
  dispatch_time_t executionDelay =
      dispatch_time(DISPATCH_TIME_NOW, arc4random_uniform(4) * NSEC_PER_SEC);
  dispatch_after(executionDelay, _realtimeLockQueue, ^{
    [self fetchLatestConfig:remainingAttempts targetVersion:targetVersion];
  });
}

/// Perform fetch and handle developers callbacks
- (void)autoFetch:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    if (remainingAttempts == 0) {
      NSError *error = [NSError errorWithDomain:FIRRemoteConfigUpdateErrorDomain
                                           code:FIRRemoteConfigUpdateErrorNotFetched
                                       userInfo:@{
                                         NSLocalizedDescriptionKey :
                                             @"Unable to fetch the latest version of the template."
                                       }];
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000011",
                  @"Ran out of fetch attempts, cannot find target config version.");
      [self propagateErrors:error];
      return;
    }

    [strongSelf scheduleFetch:remainingAttempts targetVersion:targetVersion];
  });
}

#pragma mark - NSURLSession Delegates

- (void)evaluateStreamResponse:(NSDictionary *)response error:(NSError *)dataError {
  NSInteger updateTemplateVersion = 1;
  NSTimeInterval realtimeRetryInterval = 0;
  if (dataError == nil) {
    if ([response objectForKey:kTemplateVersionNumberKey]) {
      updateTemplateVersion = [[response objectForKey:kTemplateVersionNumberKey] integerValue];
    }
    if ([response objectForKey:kIsFeatureDisabled]) {
      self->_isRealtimeDisabled = [response objectForKey:kIsFeatureDisabled];
    }
    if ([response objectForKey:kRealtime_Retry_Interval]) {
      realtimeRetryInterval = [[response objectForKey:kRealtime_Retry_Interval] integerValue];
    }

    if (self->_isRealtimeDisabled) {
      [self pauseRealtimeStream];
      NSError *error = [NSError
          errorWithDomain:FIRRemoteConfigUpdateErrorDomain
                     code:FIRRemoteConfigUpdateErrorUnavailable
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       @"The server is temporarily unavailable. Try again in a few minutes."
                 }];
      [self propagateErrors:error];
    } else {
      NSInteger clientTemplateVersion = [_configFetch.templateVersionNumber integerValue];
      if (updateTemplateVersion > clientTemplateVersion) {
        [self autoFetch:gFetchAttempts targetVersion:updateTemplateVersion];
      }

      /// This field in the response indicates that the realtime request should retry after the
      /// specified interval to establish a long-lived connection. This interval extends the backoff
      /// duration without affecting the number of retries, so it will not enter an exponential
      /// backoff state.
      if (realtimeRetryInterval > 0) {
        [self->_settings updateRealtimeBackoffTimeWithInterval:realtimeRetryInterval];
      }
    }
  } else {
    NSError *error =
        [NSError errorWithDomain:FIRRemoteConfigUpdateErrorDomain
                            code:FIRRemoteConfigUpdateErrorMessageInvalid
                        userInfo:@{NSLocalizedDescriptionKey : @"Unable to parse ConfigUpdate."}];
    [self propagateErrors:error];
  }
}

/// Delegate to asynchronously handle every new notification that comes over the wire. Auto-fetches
/// and runs callback for each new notification
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
  NSError *dataError;
  NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

  /// If response data contains the API enablement link, return the entire message to the user in
  /// the form of a error.
  if ([strData containsString:kServerForbiddenStatusCode]) {
    NSError *error = [NSError errorWithDomain:FIRRemoteConfigUpdateErrorDomain
                                         code:FIRRemoteConfigUpdateErrorStreamError
                                     userInfo:@{NSLocalizedDescriptionKey : strData}];
    FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000021", @"Cannot establish connection. %@", error);
    [self propagateErrors:error];
    return;
  }

  NSRange beginRange = [strData rangeOfString:@"{"];
  if (beginRange.location != NSNotFound) {
    NSRange endRange =
        [strData rangeOfString:@"}"
                       options:0
                         range:NSMakeRange(beginRange.location + 1,
                                           strData.length - beginRange.location - 1)];
    if (endRange.location != NSNotFound) {
      FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000015",
                  @"Received config update message on stream.");
      NSRange msgRange =
          NSMakeRange(beginRange.location, endRange.location - beginRange.location + 1);
      strData = [strData substringWithRange:msgRange];
      data = [strData dataUsingEncoding:NSUTF8StringEncoding];
      NSDictionary *response =
          [NSJSONSerialization JSONObjectWithData:data
                                          options:NSJSONReadingMutableContainers
                                            error:&dataError];

      [self evaluateStreamResponse:response error:dataError];
    }
  }
}

/// Check if response code is retryable
- (bool)isStatusCodeRetryable:(NSInteger)statusCode {
  return statusCode == kRCNFetchResponseHTTPStatusClientTimeout ||
         statusCode == kRCNFetchResponseHTTPStatusTooManyRequests ||
         statusCode == kRCNFetchResponseHTTPStatusCodeServiceUnavailable ||
         statusCode == kRCNFetchResponseHTTPStatusCodeBadGateway ||
         statusCode == kRCNFetchResponseHTTPStatusCodeGatewayTimeout;
}

/// Delegate to handle initial reply from the server
- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
  _isRequestInProgress = false;
  NSHTTPURLResponse *_httpURLResponse = (NSHTTPURLResponse *)response;
  NSInteger statusCode = [_httpURLResponse statusCode];

  if (statusCode == 403) {
    completionHandler(NSURLSessionResponseAllow);
    return;
  }

  if (statusCode != kRCNFetchResponseHTTPStatusOk) {
    [self->_settings updateRealtimeExponentialBackoffTime];
    [self pauseRealtimeStream];

    if ([self isStatusCodeRetryable:statusCode]) {
      [self retryHTTPConnection];
    } else {
      NSError *error = [NSError
          errorWithDomain:FIRRemoteConfigUpdateErrorDomain
                     code:FIRRemoteConfigUpdateErrorStreamError
                 userInfo:@{
                   NSLocalizedDescriptionKey :
                       [NSString stringWithFormat:@"Unable to connect to the server. Try again in "
                                                  @"a few minutes. Http Status code: %@",
                                                  [@(statusCode) stringValue]]
                 }];
      FIRLogError(kFIRLoggerRemoteConfig, @"I-RCN000021", @"Cannot establish connection. Error: %@",
                  error);
    }
  } else {
    /// on success reset retry parameters
    _remainingRetryCount = gMaxRetries;
    [self->_settings setRealtimeRetryCount:0];
  }

  completionHandler(NSURLSessionResponseAllow);
}

/// Delegate to handle data task completion
- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  _isRequestInProgress = false;
  if (error != nil && [error code] != NSURLErrorCancelled) {
    [self->_settings updateRealtimeExponentialBackoffTime];
  }
  [self pauseRealtimeStream];
  [self retryHTTPConnection];
}

/// Delegate to handle session invalidation
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
  if (!_isRequestInProgress) {
    if (error != nil) {
      [self->_settings updateRealtimeExponentialBackoffTime];
    }
    [self pauseRealtimeStream];
    [self retryHTTPConnection];
  }
}

#pragma mark - Top level methods

- (void)beginRealtimeStream {
  __weak __typeof(self) weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong __typeof(self) strongSelf = weakSelf;

    if (strongSelf->_settings.getRealtimeBackoffInterval > 0) {
      [strongSelf retryHTTPConnection];
      return;
    }

    if ([strongSelf canMakeConnection]) {
      __weak __typeof(self) weakSelf = strongSelf;
      [strongSelf createRequestBodyWithCompletion:^(NSData *_Nonnull requestBody) {
        __strong __typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_isRequestInProgress = true;
        [strongSelf->_request setHTTPBody:requestBody];
        strongSelf->_dataTask = [strongSelf->_session dataTaskWithRequest:strongSelf->_request];
        [strongSelf->_dataTask resume];
      }];
    }
  });
}

- (void)pauseRealtimeStream {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    if (strongSelf->_dataTask != nil) {
      [strongSelf->_dataTask cancel];
      strongSelf->_dataTask = nil;
    }
  });
}

- (FIRConfigUpdateListenerRegistration *)addConfigUpdateListener:
    (void (^_Nonnull)(FIRRemoteConfigUpdate *configUpdate, NSError *_Nullable error))listener {
  if (listener == nil) {
    return nil;
  }
  __block id listenerCopy = listener;

  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf->_listeners addObject:listenerCopy];
    [strongSelf beginRealtimeStream];
  });

  return [[FIRConfigUpdateListenerRegistration alloc] initWithClient:self
                                                   completionHandler:listenerCopy];
}

- (void)removeConfigUpdateListener:(void (^_Nonnull)(FIRRemoteConfigUpdate *configUpdate,
                                                     NSError *_Nullable error))listener {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf->_listeners removeObject:listener];
    if (strongSelf->_listeners.count == 0) {
      [strongSelf pauseRealtimeStream];
    }
  });
}

@end
