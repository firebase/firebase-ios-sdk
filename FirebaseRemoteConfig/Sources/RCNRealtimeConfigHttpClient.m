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
static NSString *const kHTTPMethodGet = @"GET";  ///< HTTP request method config fetch using
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

// Retry parameters
NSInteger MAX_RETRY = 10;
NSInteger MAX_RETRY_COUNT = 10;
NSInteger RETRY_MULTIPLIER = 2;
NSTimeInterval timeoutSeconds = 432000;
double RETRY_SECONDS = 5.5;

static NSString *const hostAddress = @"http://127.0.0.1:8080";

@implementation RCNRealtimeConfigHttpClient {
    RCNConfigFetch *_configFetch;
    RCNConfigSettings *_settings;
    FIROptions *_options;
    dispatch_queue_t _lockQueue;
    NSString *_namespace;
    __strong id _realTimeDelegate;
    NSNotificationCenter *_notificationCenter;
    NSMutableURLRequest *_request;
    NSURLSession *_session;
    NSURLSessionDataTask *_dataTask;
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
// Creates NS session and requests
-(void) setUpHTTPParameters {
    [self refreshInstallationsTokenWithCompletionHandler:^(FIRRemoteConfigFetchStatus status, NSError * _Nullable error) {
        if (status != FIRRemoteConfigFetchStatusSuccess) {
            NSLog(@"Installation token retrival failed");
        }
    }];
    
    _request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:hostAddress] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeoutSeconds];
    [_request setHTTPMethod:kHTTPMethodGet];
    [_request setValue:@"application/json" forHTTPHeaderField:kContentTypeHeaderName];
    [_request setValue:@"gzip" forHTTPHeaderField:kContentEncodingHeaderName];
    [_request setValue:@"gzip" forHTTPHeaderField:kAcceptEncodingHeaderName];
    [_request setValue:_settings.configInstallationsToken
        forHTTPHeaderField:kInstallationsAuthTokenHeaderName];
    [_request setValue:[[NSBundle mainBundle] bundleIdentifier]
        forHTTPHeaderField:kiOSBundleIdentifierHeaderName];
    
    if (_settings.lastETag) {
      [_request setValue:_settings.lastETag forHTTPHeaderField:kIfNoneMatchETagHeaderName];
    }

    NSURLSessionConfiguration *sessionConfig=[NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setTimeoutIntervalForResource:timeoutSeconds];
    
    _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

// Retry mechanism for HTTP connections
- (void)retryHTTPConnection {
    NSLog(@"Retrying connection request.");
    if (!_inBackground && MAX_RETRY_COUNT > 0) {
        MAX_RETRY_COUNT--;
        
        [self pauseStream];
        [NSTimer scheduledTimerWithTimeInterval:RETRY_SECONDS * RETRY_MULTIPLIER target:self selector:@selector(startStream) userInfo:nil repeats:NO];
    } else {
        NSLog(@"No retries remaining");
    }
}

#pragma mark - NSURLSession Delegates

// Delegate to asynchronously handle every new notification that comes over the wire then auto-fetches and runs callback for each new notification
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    NSLog(@"Received invalidation notification from server.");
    [self->_configFetch fetchConfigWithExpirationDuration: 0
        completionHandler: ^(FIRRemoteConfigFetchStatus status, NSError *error) {
            NSLog(@"Fetching new config");
            if (status == FIRRemoteConfigFetchStatusSuccess) {
                if (self->_realTimeDelegate != NULL && self->_realTimeDelegate != nil) {
                    NSLog(@"Executing callback delegate");
                    [self->_realTimeDelegate handleRealTimeConfigFetch:self];
                }
            } else {
                NSLog(@"Config not fetched");
                NSLog(@"Error %@", error.localizedDescription);
            }
        }
    ];
}

// Delegate that checks the final response of the connection and retries if necessary
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse * _httpURLResponse = (NSHTTPURLResponse*) response;
    if (_httpURLResponse.statusCode != (NSInteger) 200) {
        [self retryHTTPConnection];
    }

    completionHandler(NSURLSessionResponseAllow);
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self retryHTTPConnection];
}

// Delegate that checks the final response of the connection and retries if allowed
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [self retryHTTPConnection];
}

#pragma mark - Foreground Reconnection

// Stream monitoring
- (void)viewDidLoad {
    [super viewDidLoad];

    [self->_notificationCenter addObserver:self selector:@selector(isInForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)isInForeground {
    NSLog(@"Foreground");
    _inBackground = FALSE;
    [self startStream];
}

#pragma mark - Exposed Realtime Methods

// Starts HTTP connection.
- (void)startStream {
    if (self->_dataTask == NULL) {
        NSLog(@"HTTP connection started.");
        [self setUpHTTPParameters];
        self->_dataTask = [_session dataTaskWithRequest:_request];
        [_dataTask resume];
        
        if (_dataTask.state == NSURLSessionTaskStateRunning) {
            NSLog(@"Connection made to backend.");
            MAX_RETRY_COUNT = MAX_RETRY;
        } else {
            [self retryHTTPConnection];
        }
    }
}

// Stops data task.
- (void)pauseStream {
    if (self->_dataTask != NULL) {
        [_dataTask cancel];
        self->_dataTask = NULL;
    }
}

// Sets Delegate callback
- (void)setRealTimeDelegateCallback:(id)realTimeDelegate {
    self->_realTimeDelegate = realTimeDelegate;
}

// Removes Delegate callback
- (void)removeRealTimeDelegateCallback {
    self->_realTimeDelegate = NULL;
}

@end
