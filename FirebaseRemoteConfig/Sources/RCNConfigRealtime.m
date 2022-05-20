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

#import <GoogleUtilities/GULNSData+zlib.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigRealtime.h"
#import <Foundation/Foundation.h>
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"

// URL params
static NSString *const kServerURLDomain = @"https://firebaseremoteconfig.googleapis.com";
static NSString *const kServerURLVersion = @"/v1";
static NSString *const kServerURLProjects = @"/projects/";
static NSString *const kServerURLNamespaces = @"/namespaces/";
static NSString *const kServerURLQuery = @":streamFetchInvalidations?";
static NSString *const kServerURLKey = @"key=";

// Header names
static NSString *const kHTTPMethodPost = @"POST";  ///< HTTP request method config fetch using
static NSString *const kContentTypeHeaderName = @"Content-Type";  ///< HTTP Header Field Name
static NSString *const kContentEncodingHeaderName =
    @"Content-Encoding";                                                ///< HTTP Header Field Name
static NSString *const kAcceptEncodingHeaderName = @"Accept";  ///< HTTP Header Field Name
static NSString *const kETagHeaderName = @"etag";                       ///< HTTP Header Field Name
static NSString *const kIfNoneMatchETagHeaderName = @"if-none-match";   ///< HTTP Header Field Name
static NSString *const kInstallationsAuthTokenHeaderName = @"x-goog-firebase-installations-auth";
// Sends the bundle ID. Refer to b/130301479 for details.
static NSString *const kiOSBundleIdentifierHeaderName =
    @"X-Ios-Bundle-Identifier";  ///< HTTP Header Field Name
static NSString *const templateVersionNumberKey = @"templateVersion";

/// Completion handler invoked by config update methods when they get a response from the server.
///
/// @param error  Error message on failure.
typedef void (^FIRConfigUpdateCompletion)(NSError *_Nullable error);

NSTimeInterval timeoutSeconds = 4320;
NSInteger FETCH_ATTEMPTS = 5;

@implementation FIRConfigUpdateListenerRegistration {
  RCNConfigRealtime *_realtimeClient;
  id completionHandler;
}

- (instancetype)initWithClient:(RCNConfigRealtime *)realtimeClient
             completionHandler:(FIRConfigUpdateCompletion)completionHandler {
  self = [super init];
  if (self) {
    _realtimeClient = realtimeClient;
    completionHandler = completionHandler;
  }
  return self;
}

- (void)remove {
  [self->_realtimeClient removeConfigUpdateListener:completionHandler];
}

@end

@interface RCNConfigRealtime ()

@property(strong, atomic, nonnull) NSMutableSet<id> *listeners;
@property(strong, atomic, nonnull) dispatch_queue_t realtimeLockQueue;

@end

@implementation RCNConfigRealtime {
    RCNConfigFetch *_configFetch;
        RCNConfigSettings *_settings;
        FIROptions *_options;
        NSString *_namespace;
    NSMutableURLRequest *request;
    NSURLSession *session;
    NSURLSessionDataTask *dataTask;
}

- (instancetype)init: (RCNConfigFetch *)configFetch
                    settings: (RCNConfigSettings *)settings
                    namespace: (NSString *)namespace
                    options: (FIROptions *)options {
  self = [super init];
  if (self) {
    _listeners = [NSMutableSet alloc];
    _realtimeLockQueue = [RCNConfigRealtime realtimeRemoteConfigSerialQueue];
    
      _configFetch = configFetch;
      _settings = settings;
      _options = options;
      _namespace = namespace;
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

- (NSString *)constructServerURL {
  NSString *serverURLStr = [[NSString alloc] initWithString:kServerURLDomain];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLVersion];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLProjects];
  serverURLStr = [serverURLStr stringByAppendingString:_options.GCMSenderID];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLNamespaces];

  // Get the namespace from the fully qualified namespace string of "namespace:FIRAppName".
  NSString *namespace =
      [_namespace substringToIndex:[_namespace rangeOfString:@":"].location];
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
    dispatch_async(dispatch_get_main_queue(), ^{
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

    // We have a valid token. Get the backing installationID.
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

        // Update config settings with the IID and token.
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


-(void) setRequestBody {
    [self refreshInstallationsTokenWithCompletionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
        if (status != FIRRemoteConfigFetchStatusSuccess) {
            NSLog(@"Installation token retrival failed");
        }
    }];

    [request setValue:_settings.configInstallationsToken
        forHTTPHeaderField:kInstallationsAuthTokenHeaderName];
    if (_settings.lastETag) {
      [request setValue:_settings.lastETag forHTTPHeaderField:kIfNoneMatchETagHeaderName];
    }

    NSString *namespace =
        [_namespace substringToIndex:[_namespace rangeOfString:@":"].location];

    NSString *postBody = [NSString stringWithFormat:@"{project:'%@', namespace:'%@', lastKnownVersionNumber:'%@'}", [self->_options GCMSenderID], namespace, [_configFetch getTemplateVersionNumber]];
    NSData *postData = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    NSError *compressionError;
    NSData *compressedContent = [NSData gul_dataByGzippingData:postData error:&compressionError];

    [request setHTTPBody:compressedContent];
}

// Creates request.
-(void) setUpHttpRequest {
    NSString *address = [self constructServerURL];
    request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString: address] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeoutSeconds];
    [request setHTTPMethod:kHTTPMethodPost];
    [request setValue:@"application/json" forHTTPHeaderField:kContentTypeHeaderName];
    [request setValue:@"application/json" forHTTPHeaderField:kAcceptEncodingHeaderName];
    [request setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
    [request setValue:@"true" forHTTPHeaderField:@"X-Google-GFE-Can-Retry"];
    [request setValue:[_options APIKey] forHTTPHeaderField:@"X-Goog-Api-Key"];
    [request setValue:[[NSBundle mainBundle] bundleIdentifier]
        forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
}

// Makes call to create session.
-(void) setUpHttpSession {
    NSURLSessionConfiguration *sessionConfig = [[NSURLSessionConfiguration defaultSessionConfiguration] copy];
    [sessionConfig setTimeoutIntervalForResource:timeoutSeconds];
    [sessionConfig setTimeoutIntervalForRequest:timeoutSeconds];
    session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

#pragma mark - Autofetch Helpers

-(void) executeAutofetchCompletion:(void (^_Nonnull)(NSError *_Nullable error))listener {
    
}

- (void) fetchLatestConfig: (NSTimer *)timer {
    NSArray *input = [[[timer userInfo] objectForKey:@"key"] componentsSeparatedByString:@"-"];
    NSInteger remainingAttempts = [input[0] integerValue];
    NSInteger currentVersion = [input[1] integerValue];

    [self->_configFetch fetchConfigWithExpirationDuration: 0
        completionHandler: ^(FIRRemoteConfigFetchStatus status, NSError *error) {
            NSLog(@"Fetching new config");
            if (status == FIRRemoteConfigFetchStatusSuccess) {
                if ([@"template" integerValue] > currentVersion) {
                    NSLog(@"Executing callback delegate");
                    for (FIRConfigUpdateCompletion listener in self->_listeners) {
                        listener(nil);
                    }
                } else {
                    NSLog(@"Fetched config's template version is the same or less then the current version, re-fetching");
                    [self autoFetch:remainingAttempts - 1 currentVersion:currentVersion];
                }
            } else {
                NSLog(@"Config not fetched");
                if (error != nil) {
                    NSLog(@"Error receiveds: %@", error.localizedDescription);
                }
            }
        }
    ];
}

- (void) scheduleFetch: (NSInteger)remainingAttempts currentVersion:(NSInteger) currentVersion {
    NSString *inputKey = [NSString stringWithFormat:@"%ld-%ld", (long)remainingAttempts, (long)currentVersion];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:inputKey forKey:@"key"];

    if (remainingAttempts == FETCH_ATTEMPTS) {
        [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(fetchLatestConfig:) userInfo:dictionary repeats:NO];
    } else {
        [NSTimer scheduledTimerWithTimeInterval:arc4random_uniform(11) + 2 target:self selector:@selector(fetchLatestConfig:) userInfo:dictionary repeats:NO];
    }
}

// Perform fetch and handle developers callbacks
-(void) autoFetch:(NSInteger)remainingAttempts currentVersion:(NSInteger) currentVersion {
    if (remainingAttempts == 0) {
        NSError *error =
            [NSError errorWithDomain:FIRRemoteConfigRealtimeErrorDomain
                                code:FIRRemoteConfigRealtimeErrorFetch
                            userInfo:@{
                              NSLocalizedDescriptionKey :
                                  @"FetchError: Unable to retrieve the latest config."
                            }];
        for (FIRConfigUpdateCompletion listener in self->_listeners) {
            listener(error);
        }
        return;
    }

    [self scheduleFetch:remainingAttempts currentVersion:currentVersion];
}

#pragma mark - NSURLSession Delegates

// Delegate to asynchronously handle every new notification that comes over the wire. Auto-fetches and runs callback for each new notification
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    NSLog(@"Received invalidation notification from server.");
    [self autoFetch:FETCH_ATTEMPTS currentVersion:[[_configFetch getTemplateVersionNumber] integerValue]];
}

// Delegate that checks the final response of the connection and retries if necessary
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse * _httpURLResponse = (NSHTTPURLResponse*) response;
    if ([_httpURLResponse statusCode] != 200) {
        [self pauseRealtimeStream];
    }
    completionHandler(NSURLSessionResponseAllow);
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self pauseRealtimeStream];
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [self pauseRealtimeStream];
}

- (void)beginRealtimeStream {
}

- (void)pauseRealtimeStream {
}

- (FIRConfigUpdateListenerRegistration *)addConfigUpdateListener:
    (void (^_Nonnull)(NSError *_Nullable error))listener {
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
