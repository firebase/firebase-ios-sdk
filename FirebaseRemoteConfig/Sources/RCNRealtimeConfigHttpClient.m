//
//  RCNRealtimeConfigHTTPClient.m
//  FirebaseRemoteConfig
//
//  Created by Quan Pham on 2/8/22.
//

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import <Foundation/Foundation.h>
#import "RCNConfigFetch.h"
#import "RCNRealtimeConfigHttpClient.h"

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

// Retry parameters
NSInteger MAX_RETRY = 10;
NSInteger MAX_RETRY_COUNT = 10;
NSInteger RETRY_MULTIPLIER = 2;
NSTimeInterval timeoutSeconds = 4320;
double RETRY_SECONDS = 5.5;
bool isFirstConnection = true;

NSInteger FETCH_DELAY = 120;
NSInteger FETCH_ATTEMPTS = 5;

static NSString *const hostAddress = @"http://127.0.0.1:8080";

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
    NSMutableURLRequest *_request;
    NSURLSession *_session;
    NSURLSessionDataTask *_dataTask;
    __strong id _eventListener;
    NSNotificationCenter *_notificationCenter;
    BOOL _inBackground;
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
        _notificationCenter = [NSNotificationCenter defaultCenter];
        _inBackground = FALSE;
        [self setUpHttpRequest];
    }
    
    return self;
}

- (dispatch_queue_t)dispatchQueue {
  return dispatch_get_main_queue();
}

#pragma mark - HTTP Client Helpers

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

    [_request setValue:_settings.configInstallationsToken
        forHTTPHeaderField:kInstallationsAuthTokenHeaderName];
    if (_settings.lastETag) {
      [_request setValue:_settings.lastETag forHTTPHeaderField:kIfNoneMatchETagHeaderName];
    }
    
    NSString *postBody = [NSString stringWithFormat:@"project=%@&namespace=%@&templateVersionNumber=%@", [self->_options projectID], self->_namespace, [self->_configFetch getTemplateVersionNumber]];
    NSData *postData = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    [_request setHTTPBody:postData];
}

// Creates request.
-(void) setUpHttpRequest {
    _request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:hostAddress] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeoutSeconds];
    [_request setHTTPMethod:kHTTPMethodPost];
    [_request setValue:@"application/json" forHTTPHeaderField:kContentTypeHeaderName];
//    [_request setValue:@"Transfer-Encoding" forKey:@"Chunked"];
    [_request setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
    [_request setValue:@"gzip" forHTTPHeaderField:kAcceptEncodingHeaderName];
    [_request setValue:[[NSBundle mainBundle] bundleIdentifier]
        forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
}

// Makes call to create session.
-(void) setUpHttpSession {
    NSURLSessionConfiguration *sessionConfig=[NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setTimeoutIntervalForResource:timeoutSeconds];
    
    _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

#pragma mark - NSURLSession Delegates

// Perform fetch and handle developers callbacks
-(void) fetchConfigAndHandleCallbacks:(NSInteger)remainingAttempts currentVersion:(NSInteger) currentVersion {
    if (remainingAttempts == 0) {
        return;
    }
    
    [self->_configFetch fetchConfigWithExpirationDuration: 0
        completionHandler: ^(FIRRemoteConfigFetchStatus status, NSError *error) {
            NSLog(@"Fetching new config");
            if (status == FIRRemoteConfigFetchStatusSuccess) {
                if ([[self->_configFetch getTemplateVersionNumber] integerValue] > currentVersion) {
                    NSLog(@"Executing callback delegate");
                    [self->_eventListener onEvent:self];
                } else {
                    NSLog(@"Fetched config's template version is the same or less then the current version, re-fetching");
                    [self fetchConfigAndHandleCallbacks:remainingAttempts - 1 currentVersion:currentVersion];
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

// Delegate to asynchronously handle every new notification that comes over the wire. Auto-fetches and runs callback for each new notification
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    NSLog(@"Received invalidation notification from server.");
    [self fetchConfigAndHandleCallbacks:FETCH_ATTEMPTS currentVersion:[[self->_configFetch getTemplateVersionNumber] integerValue]];
}

// Delegate that checks the final response of the connection and retries if necessary
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse * _httpURLResponse = (NSHTTPURLResponse*) response;
    if ([_httpURLResponse statusCode] != 200) {
        [self retryHTTPConnection];
    }
    completionHandler(NSURLSessionResponseAllow);
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error received: %@", error.localizedDescription);
    }
    [self retryHTTPConnection];
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    if (error != nil) {
        NSLog(@"Error received: %@", error.localizedDescription);
    }
    [self retryHTTPConnection];
}

#pragma mark - Reconnection Helpers

// Checks if app is in foreground or not.
- (void)viewDidLoad {
    [super viewDidLoad];

    [self->_notificationCenter addObserver:self selector:@selector(isInForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [self->_notificationCenter addObserver:self selector:@selector(isInBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)isInBackground {
    _inBackground = TRUE;
}

- (void)isInForeground {
    NSLog(@"Foreground");
    _inBackground = FALSE;
    [self startRealtimeConnection];
}

// Retry mechanism for HTTP connections
- (void)retryHTTPConnection {
    NSLog(@"Retrying connection request.");
    if (!_inBackground && MAX_RETRY_COUNT > 0) {
        MAX_RETRY_COUNT--;
        RETRY_MULTIPLIER++;
        [self pauseRealtimeConnection];
        [NSTimer scheduledTimerWithTimeInterval:RETRY_SECONDS * RETRY_MULTIPLIER target:self selector:@selector(startRealtimeConnection) userInfo:nil repeats:NO];
    } else {
        NSLog(@"No retries remaining");
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

-(bool) isThereNoRunningConnection {
    return self->_dataTask == NULL || self->_dataTask.state != NSURLSessionTaskStateRunning;
}

// Starts HTTP connection.
- (void)startRealtimeConnection {
    if (isFirstConnection) {
        [self retryOnEveryNetworkConnection];
        [self setUpHttpSession];
        isFirstConnection = false;
    }
    
    if (!_inBackground && [self isThereNoRunningConnection] && self->_eventListener != nil) {
        NSLog(@"HTTP connection started.");
        [self setRequestBody];
        self->_dataTask = [_session dataTaskWithRequest:_request];
        [_dataTask resume];
        
        if (_dataTask.state == NSURLSessionTaskStateRunning) {
            NSLog(@"Connection made to backend.");
            MAX_RETRY_COUNT = MAX_RETRY;
            RETRY_MULTIPLIER = arc4random_uniform(10) + 1;
        } else {
            [self retryHTTPConnection];
        }
    }
}

// Stops data task session.
- (void)pauseRealtimeConnection {
    if (self->_dataTask != NULL) {
        [_dataTask cancel];
        self->_dataTask = NULL;
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
