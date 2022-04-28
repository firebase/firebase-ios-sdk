//
//  RCNRealtimeConfigHTTPClient.m
//  FirebaseRemoteConfig
//
//  Created by Quan Pham on 2/8/22.
//

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import <Foundation/Foundation.h>
#import "RCNConfigFetch.h"
#import "RCNRealtimeConfigHttpClient.h"

// URL params
static NSString *const kServerURLDomain = @"https://firebaseremoteconfig.googleapis.com";
static NSString *const kServerURLVersion = @"/v1";
static NSString *const kServerURLProjects = @"/projects/";
static NSString *const kServerURLNamespaces = @"/namespaces/";
static NSString *const kServerURLQuery = @":fetch?";
static NSString *const kServerURLKey = @"key=";

// Header names
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
static NSString *const templateVersionNumberKey = @"templateVersion";
static NSString *const hostAddress = @"http://127.0.0.1:8080";

static NSInteger const kRCNFetchResponseHTTPStatusCodeServiceUnavailable = 503;

// Retry parameters
NSInteger MAX_RETRY = 10;
NSInteger MAX_RETRY_COUNT = 10;
NSInteger RETRY_MULTIPLIER = 2;

bool isFirstConnection = true;
bool inBackground = false;
NSInteger FETCH_DELAY = 120;
NSInteger FETCH_ATTEMPTS = 5;
NSTimeInterval timeoutSeconds = 4320;

NSMutableURLRequest *request;
NSURLSession *session;
NSURLSessionDataTask *dataTask;
NSNotificationCenter *notificationCenter;

# pragma mark - Realtime Event Listener Registration
@implementation ListenerRegistration {
    RCNRealtimeConfigHttpClient *_realtimeClient;
}

- (instancetype) initWithClass: (RCNRealtimeConfigHttpClient *)realtimeClient {
    self = [super init];
    if (self) {
        _realtimeClient = realtimeClient;
    }
    return self;
}

- (void)remove {
    [self-> _realtimeClient removeRealtimeEventListener];
    [self-> _realtimeClient pauseRealtimeConnection];
}

@end

@implementation RCNRealtimeConfigHttpClient {
    RCNConfigFetch *_configFetch;
    RCNConfigSettings *_settings;
    FIROptions *_options;
    dispatch_queue_t _lockQueue;
    NSString *_namespace;
    __strong id _eventListener;
}

-(instancetype) initWithClass: (RCNConfigFetch *)configFetch
                           settings: (RCNConfigSettings *)settings
                           namespace: (NSString *)namespace
                           options: (FIROptions *)options
                           queue: (dispatch_queue_t)queue {
    self = [super init];
    if (self) {
        _configFetch = configFetch;
        _settings = settings;
        _namespace = namespace;
        _options = options;
        _lockQueue = queue;
        notificationCenter = [NSNotificationCenter defaultCenter];
        [self setUpHttpRequest];
    }
    
    return self;
}

- (dispatch_queue_t)dispatchQueue {
  return dispatch_get_main_queue();
}

#pragma mark - HTTP Client Helpers

- (NSString *)constructServerURL {
  NSString *serverURLStr = [[NSString alloc] initWithString:kServerURLDomain];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLVersion];
  serverURLStr = [serverURLStr stringByAppendingString:kServerURLProjects];
  serverURLStr = [serverURLStr stringByAppendingString:_options.projectID];
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

  __weak RCNRealtimeConfigHttpClient *weakSelf = self;
  FIRInstallationsTokenHandler installationsTokenHandler = ^(
      FIRInstallationsAuthTokenResult *tokenResult, NSError *error) {
    RCNRealtimeConfigHttpClient *strongSelf = weakSelf;
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
      RCNRealtimeConfigHttpClient *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      // Dispatch to the RC serial queue to update settings on the queue.
      dispatch_async(strongSelf->_lockQueue, ^{
        RCNRealtimeConfigHttpClient *strongSelfQueue = weakSelf;
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
    
    NSString *postBody = [NSString stringWithFormat:@"project=%@&namespace=%@&templateVersionNumber=%@", [self->_options projectID], self->_namespace, [self->_configFetch getTemplateVersionNumber]];
    NSData *postData = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:postData];
}

// Creates request.
-(void) setUpHttpRequest {
    request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:hostAddress] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeoutSeconds];
    [request setHTTPMethod:kHTTPMethodPost];
    [request setValue:@"application/json" forHTTPHeaderField:kContentTypeHeaderName];
    [request setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
    [request setValue:@"gzip" forHTTPHeaderField:kAcceptEncodingHeaderName];
    [request setValue:[[NSBundle mainBundle] bundleIdentifier]
        forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
}

// Makes call to create session.
-(void) setUpHttpSession {
    NSURLSessionConfiguration *sessionConfig=[NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setTimeoutIntervalForResource:timeoutSeconds];
    
    session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

#pragma mark - Autofetch Helpers

- (void) fetchLatestConfig: (NSTimer *)timer {
    NSArray *input = [[[timer userInfo] objectForKey:@"key"] componentsSeparatedByString:@"-"];
    NSInteger remainingAttempts = [input[0] integerValue];
    NSInteger currentVersion = [input[1] integerValue];
    
    [self->_configFetch fetchConfigWithExpirationDuration: 0
        completionHandler: ^(FIRRemoteConfigFetchStatus status, NSError *error) {
            NSLog(@"Fetching new config");
            if (status == FIRRemoteConfigFetchStatusSuccess) {
                if ([[self->_configFetch getTemplateVersionNumber] integerValue] > currentVersion) {
                    NSLog(@"Executing callback delegate");
                    if (self->_eventListener != NULL) {
                        [self->_eventListener onEvent:self];
                    }
                } else {
                    NSLog(@"Fetched config's template version is the same or less then the current version, re-fetching");
                    [self autoFetch:remainingAttempts - 1 currentVersion:currentVersion];
                }
            } else {
                NSLog(@"Config not fetched");
                if (error != nil) {
                    NSLog(@"Error received: %@", error.localizedDescription);
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
            [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                code:kRCNFetchResponseHTTPStatusCodeServiceUnavailable
                            userInfo:@{
                              NSLocalizedDescriptionKey :
                                  @"FetchError: Unable to retrieve the latest config."
                            }];
        if (self->_eventListener != NULL) {
            [self->_eventListener onError:error];
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
    [self autoFetch:FETCH_ATTEMPTS currentVersion:[[self->_configFetch getTemplateVersionNumber] integerValue]];
}

// Delegate that checks the final response of the connection and retries if necessary
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse * _httpURLResponse = (NSHTTPURLResponse*) response;
    if ([_httpURLResponse statusCode] != 200) {
        [self pauseRealtimeConnection];
        [self retryHTTPConnection];
    }
    completionHandler(NSURLSessionResponseAllow);
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error received: %@", error.localizedDescription);
    }
    [self pauseRealtimeConnection];
    [self retryHTTPConnection];
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error received: %@", error.localizedDescription);
    }
    [self pauseRealtimeConnection];
    [self retryHTTPConnection];
}

#pragma mark - Reconnection Helpers

// Checks if app is in foreground or not.
- (void)viewDidLoad {
    [super viewDidLoad];

    [notificationCenter addObserver:self selector:@selector(isInForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(isInBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)isInBackground {
    inBackground = TRUE;
}

- (void)isInForeground {
    NSLog(@"Foreground");
    inBackground = FALSE;
    [self startRealtimeConnection];
}

// Retry mechanism for HTTP connections
- (void)retryHTTPConnection {
    NSLog(@"Retrying connection request.");
    if ([self canMakeConnection] && MAX_RETRY_COUNT > 0) {
        MAX_RETRY_COUNT--;
        RETRY_MULTIPLIER++;
        double RETRY_SECONDS = arc4random_uniform(60) + 10;
        [NSTimer scheduledTimerWithTimeInterval:RETRY_SECONDS target:self selector:@selector(startRealtimeConnection) userInfo:nil repeats:NO];
    } else {
        NSLog(@"Cannot establish connection.");
        NSError *error =
            [NSError errorWithDomain:FIRRemoteConfigErrorDomain
                                code:kRCNFetchResponseHTTPStatusCodeServiceUnavailable
                            userInfo:@{
                              NSLocalizedDescriptionKey :
                                  @"StreamError: Can't establish Realtime stream connection."
                            }];
        if (self->_eventListener != NULL) {
            [self->_eventListener onError:error];
        }
    }
}

- (void)checkNetworkConnection {
    NSString *testString = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com"] encoding:NSUTF8StringEncoding error:Nil];
    if (testString != nil) {
        [self startRealtimeConnection];
    }
}

- (void)retryOnEveryNetworkConnection {
    [NSTimer scheduledTimerWithTimeInterval:300 target:self selector:@selector(checkNetworkConnection) userInfo:nil repeats:YES];
}

#pragma mark - Realtime Helper Methods

-(bool) noRunningConnection {
    return dataTask == NULL || dataTask.state != NSURLSessionTaskStateRunning;
}

-(bool) canMakeConnection {
    return [self noRunningConnection] && !inBackground && self->_eventListener != nil;
}

// Starts HTTP connection.
- (void)startRealtimeConnection {
    if (isFirstConnection) {
        [self retryOnEveryNetworkConnection];
        [self setUpHttpSession];
        isFirstConnection = false;
    }
    
    if ([self canMakeConnection]) {
        NSLog(@"HTTP connection started.");
        [self setRequestBody];
        dataTask = [session dataTaskWithRequest:request];
        [dataTask resume];
        
        if (dataTask.state == NSURLSessionTaskStateRunning) {
            NSLog(@"Connection made to backend.");
            MAX_RETRY_COUNT = MAX_RETRY;
            RETRY_MULTIPLIER = arc4random_uniform(10) + 1;
        } else {
            [self pauseRealtimeConnection];
            [self retryHTTPConnection];
        }
    }
}

// Stops data task session.
- (void)pauseRealtimeConnection {
    if (dataTask != NULL) {
        [dataTask cancel];
        dataTask = NULL;
    }
}

// Sets Delegate callback
- (ListenerRegistration *)setRealtimeEventListener:(id)eventListener {
    self->_eventListener = eventListener;
    return [[ListenerRegistration alloc] initWithClass: self];
}

// Removes Delegate callback
- (void)removeRealtimeEventListener {
    self->_eventListener = NULL;
}

@end

