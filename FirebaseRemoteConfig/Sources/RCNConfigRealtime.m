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
static NSString *const kServerURLDomain = @"https://firebaseremoteconfig.googleapis.com";
static NSString *const kServerURLVersion = @"/v1";
static NSString *const kServerURLProjects = @"/projects/";
static NSString *const kServerURLNamespaces = @"/namespaces/";
static NSString *const kServerURLQuery = @":streamFetchInvalidations?";
static NSString *const kServerURLKey = @"key=";

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
static NSString *const kTemplateVersionNumberKey = @"latestTemplateVersionNumber";
static NSString *const kIsFeatureDisabled = @"featureDisabled";

/// Completion handler invoked by config update methods when they get a response from the server.
///
/// @param error  Error message on failure.
typedef void (^RCNConfigUpdateCompletion)(NSError *_Nullable error);

static NSTimeInterval gTimeoutSeconds = 4320;
static NSInteger const gFetchAttempts = 3;

// Retry parameters
static NSInteger const gMaxRetries = 7;
static NSInteger gMaxRetryCount;
static NSInteger gRetrySeconds;
static bool gIsRetrying;
static bool gIsFeatureDisabled;

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

    /// Set retry seconds to a random number between 1 and 6 seconds.
    gRetrySeconds = arc4random_uniform(5) + 1;

    gMaxRetryCount = gMaxRetries;
    gIsRetrying = false;
    gIsFeatureDisabled = false;

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
      });
    }];
  };

  FIRLogDebug(kFIRLoggerRemoteConfig, @"I-RCN000039", @"Starting requesting token.");
  [installations authTokenWithCompletion:installationsTokenHandler];
}

- (void)setRequestBody {
  [self refreshInstallationsTokenWithCompletionHandler:^(FIRRemoteConfigFetchStatus status,
                                                         NSError *_Nullable error) {
    if (status != FIRRemoteConfigFetchStatusSuccess) {
      NSLog(@"Installation token retrival failed");
    }
  }];

  [_request setValue:_settings.configInstallationsToken
      forHTTPHeaderField:kInstallationsAuthTokenHeaderName];
  if (_settings.lastETag) {
    [_request setValue:_settings.lastETag forHTTPHeaderField:kIfNoneMatchETagHeaderName];
  }

  NSString *namespace = [_namespace substringToIndex:[_namespace rangeOfString:@":"].location];
  NSString *postBody = [NSString
      stringWithFormat:@"{project:'%@', namespace:'%@', lastKnownVersionNumber:'%@', appId:'%@', "
                       @"sdkVersion:'%@'}",
                       [self->_options GCMSenderID], namespace, _configFetch.templateVersionNumber,
                       _options.googleAppID, FIRRemoteConfigPodVersion()];
  NSData *postData = [postBody dataUsingEncoding:NSUTF8StringEncoding];
  NSError *compressionError;
  NSData *compressedContent = [NSData gul_dataByGzippingData:postData error:&compressionError];

  [_request setHTTPBody:compressedContent];
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

- (bool)noRunningConnection {
  return _dataTask == nil || _dataTask.state != NSURLSessionTaskStateRunning;
}

- (bool)canMakeConnection {
  return [self noRunningConnection] && [self->_listeners count] > 0 && !gIsFeatureDisabled;
}

#pragma mark - Retry Helpers

// Retry mechanism for HTTP connections
- (void)retryHTTPConnection {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    if ([strongSelf canMakeConnection] && gMaxRetryCount > 0 && !gIsRetrying) {
      if (gMaxRetryCount < gMaxRetries) {
        double RETRY_MULTIPLIER = arc4random_uniform(3) + 2;
        gRetrySeconds *= RETRY_MULTIPLIER;
      }
      gMaxRetryCount--;
      gIsRetrying = true;
      dispatch_time_t executionDelay =
          dispatch_time(DISPATCH_TIME_NOW, (gRetrySeconds * NSEC_PER_SEC));
      dispatch_after(executionDelay, strongSelf->_realtimeLockQueue, ^{
        [strongSelf beginRealtimeStream];
      });
    } else {
      NSLog(@"Cannot establish connection.");
      NSError *error = [NSError
          errorWithDomain:FIRRemoteConfigRealtimeErrorDomain
                     code:FIRRemoteConfigRealtimeErrorStream
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"StreamError: Unable to establish http connection."
                 }];
      for (RCNConfigUpdateCompletion listener in self->_listeners) {
        listener(error);
      }
    }
  });
}

- (void)backgroundChangeListener {
  [_notificationCenter addObserver:self
                          selector:@selector(isInForeground)
                              name:@"UIApplicationDidEnterBackgroundNotification"
                            object:nil];
}

- (void)isInForeground {
  [self beginRealtimeStream];
}

#pragma mark - Autofetch Helpers

- (void)fetchLatestConfig:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf->_configFetch
        fetchConfigWithExpirationDuration:0
                        completionHandler:^(FIRRemoteConfigFetchStatus status, NSError *error) {
                          NSLog(@"Fetching new config");
                          if (status == FIRRemoteConfigFetchStatusSuccess) {
                            if ([strongSelf->_configFetch.templateVersionNumber integerValue] >=
                                targetVersion) {
                              NSLog(@"Executing callback delegate");
                              for (RCNConfigUpdateCompletion listener in strongSelf->_listeners) {
                                listener(nil);
                              }
                            } else {
                              NSLog(
                                  @"Fetched config's template version is the same or less then the "
                                  @"current version, re-fetching");
                              [strongSelf autoFetch:remainingAttempts - 1
                                      targetVersion:targetVersion];
                            }
                          } else {
                            NSLog(@"Config not fetched");
                            if (error != nil) {
                              for (RCNConfigUpdateCompletion listener in strongSelf->_listeners) {
                                listener(error);
                              }
                            }
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
      NSError *error = [NSError
          errorWithDomain:FIRRemoteConfigRealtimeErrorDomain
                     code:FIRRemoteConfigRealtimeErrorFetch
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"FetchError: Unable to retrieve the latest config."
                 }];
      for (RCNConfigUpdateCompletion listener in strongSelf->_listeners) {
        listener(error);
      }
      return;
    }

    [strongSelf scheduleFetch:remainingAttempts targetVersion:targetVersion];
  });
}

#pragma mark - NSURLSession Delegates

/// Delegate to asynchronously handle every new notification that comes over the wire. Auto-fetches
/// and runs callback for each new notification
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
  NSError *dataError;
  NSString *strData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  strData = [strData substringFromIndex:1];
  data = [strData dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                           options:NSJSONReadingMutableContainers
                                                             error:&dataError];
  NSString *targetTemplateVersion = _configFetch.templateVersionNumber;
  if (dataError == nil) {
    if ([response objectForKey:kTemplateVersionNumberKey]) {
      targetTemplateVersion = [response objectForKey:kTemplateVersionNumberKey];
    }
    if ([response objectForKey:kIsFeatureDisabled]) {
      gIsFeatureDisabled = [response objectForKey:kIsFeatureDisabled];
      if (gIsFeatureDisabled) {
        [self pauseRealtimeStream];
      }
    }
  }

  [self autoFetch:gFetchAttempts targetVersion:[targetTemplateVersion integerValue]];
}

/// Delegate that checks the final response of the connection and retries if necessary
- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
  NSHTTPURLResponse *_httpURLResponse = (NSHTTPURLResponse *)response;
  if ([_httpURLResponse statusCode] != 200 && !gIsRetrying) {
    [self pauseRealtimeStream];
    [self retryHTTPConnection];
  }
  completionHandler(NSURLSessionResponseAllow);
}

/// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  if (!gIsRetrying) {
    [self pauseRealtimeStream];
    [self retryHTTPConnection];
  }
}

/// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
  if (!gIsRetrying) {
    [self pauseRealtimeStream];
    [self retryHTTPConnection];
  }
}

#pragma mark - Top level methods

- (void)beginRealtimeStream {
  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    if ([strongSelf canMakeConnection]) {
      [strongSelf setRequestBody];
      strongSelf->_dataTask = [strongSelf->_session dataTaskWithRequest:strongSelf->_request];
      [strongSelf->_dataTask resume];
      gMaxRetryCount = gMaxRetries;
      gIsRetrying = false;

      /// Set retry seconds to a random number between 1 and 6 seconds.
      gRetrySeconds = arc4random_uniform(5) + 1;
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
    (void (^_Nonnull)(NSError *_Nullable error))listener {
  if (listener == nil) {
    return nil;
  }

  __weak RCNConfigRealtime *weakSelf = self;
  dispatch_async(_realtimeLockQueue, ^{
    __strong RCNConfigRealtime *strongSelf = weakSelf;
    [strongSelf->_listeners addObject:listener];
    [strongSelf beginRealtimeStream];
  });

  return [[FIRConfigUpdateListenerRegistration alloc] initWithClient:self
                                                   completionHandler:listener];
}

- (void)removeConfigUpdateListener:(void (^_Nonnull)(NSError *_Nullable error))listener {
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
