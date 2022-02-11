//
//  RCNRealtimeConfigHTTPClient.m
//  FirebaseRemoteConfig
//
//  Created by Quan Pham on 2/8/22.
//

#import <Foundation/Foundation.h>
#import "RCNConfigFetch.h"
#import "RCNRealtimeConfigHttpClient.h"

static NSString *const hostAddress = @"http://127.0.0.1:8080";
NSInteger MAX_RETRY = 10;
NSInteger MAX_RETRY_COUNT = 10;
NSInteger RETRY_MULTIPLIER = 2;
NSTimeInterval timeoutInterval = 432000;
double RETRY_BASE = 5.5;

@implementation RCNRealtimeConfigHttpClient {
    RCNConfigFetch *_configFetch;
    __strong id _realTimeDelegate;
    NSNotificationCenter *_notificationCenter;
    NSMutableURLRequest *_request;
    NSURLSession *_session;
    NSURLSessionDataTask *_dataTask;
    BOOL _inBackground;
}

-(void) setUpHTTPParameters {
    _request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:hostAddress]];
    [_request setHTTPMethod:@"GET"];
    [_request setValue:@"text/eventstream" forHTTPHeaderField:@"Content-Type"];
    [_request setTimeoutInterval: timeoutInterval];

    NSURLSessionConfiguration *sessionConfig=[NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setTimeoutIntervalForRequest:timeoutInterval];
    [sessionConfig setTimeoutIntervalForResource:timeoutInterval];
    
    _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

- (instancetype) initWithClass: (RCNConfigFetch *)configFetch {
    self = [super init];

    if (self) {
        NSLog(@"Initiating");
        _configFetch = configFetch;
        _notificationCenter = [NSNotificationCenter defaultCenter];
        _inBackground = FALSE;
        [self setUpHTTPParameters];
    }
    
    return self;
}

- (dispatch_queue_t)dispatchQueue {
  return dispatch_get_main_queue();
}

- (void)startStream {
    if (self->_dataTask == NULL) {
        NSLog(@"HTTP connection started.");
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

- (void)pauseStream {
    if (self->_dataTask != NULL) {
        [_dataTask cancel];
        self->_dataTask = NULL;
    }
}

- (void)retryHTTPConnection {
    NSLog(@"Retrying connection request.");
    if (!_inBackground && MAX_RETRY_COUNT > 0) {
        MAX_RETRY_COUNT--;
        
        [self pauseStream];
        [self setUpHTTPParameters];
        [NSTimer scheduledTimerWithTimeInterval:RETRY_BASE * RETRY_MULTIPLIER target:self selector:@selector(startStream) userInfo:nil repeats:NO];
    } else {
        NSLog(@"No retries remaining");
    }
}

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

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse * _httpURLResponse = (NSHTTPURLResponse*) response;
    if (_httpURLResponse.statusCode != (NSInteger) 200) {
        [self retryHTTPConnection];
    }

    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self retryHTTPConnection];
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [self retryHTTPConnection];
}

- (void)setRealTimeDelegateCallback:(id)realTimeDelegate {
    self->_realTimeDelegate = realTimeDelegate;
}

- (void)removeRealTimeDelegateCallback {
    self->_realTimeDelegate = NULL;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self->_notificationCenter addObserver:self selector:@selector(isInBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [self->_notificationCenter addObserver:self selector:@selector(isInForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)isInBackground {
    NSLog(@"Background");
    _inBackground = TRUE;
    [self pauseStream];
}

- (void)isInForeground {
    NSLog(@"Foreground");
    _inBackground = FALSE;
    [self startStream];
}

- (void)didCloseWithTrailingMetadata:(NSDictionary *)trailingMetadata error:(NSError *)error {
    if (error) {
        // Handle error
        NSLog(@"Stream Closed");
        NSLog(@"Error %@", error.localizedDescription);
    }
}

@end
