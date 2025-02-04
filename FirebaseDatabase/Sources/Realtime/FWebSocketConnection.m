/*
 * Copyright 2017 Google
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

// Targeted compilation is ONLY for testing. UIKit is weak-linked in actual
// release build.

#import <Foundation/Foundation.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabase_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"
#import "FirebaseDatabase/Sources/Realtime/FWebSocketConnection.h"
#import "FirebaseDatabase/Sources/Utilities/FStringUtilities.h"

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
#import <UIKit/UIKit.h>

#elif TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>

#elif TARGET_OS_OSX
#import <AppKit/NSApplication.h>
#endif

#import <Network/Network.h>

static NSString *const kAppCheckTokenHeader = @"X-Firebase-AppCheck";
static NSString *const kUserAgentHeader = @"User-Agent";
static NSString *const kGoogleAppIDHeader = @"X-Firebase-GMPID";

@interface FWebSocketConnection () {
    NSMutableString *frame;
    BOOL everConnected;
    BOOL isClosed;
    NSTimer *keepAlive;
}

- (void)shutdown;
- (void)onClosed;
- (void)closeIfNeverConnected;

@property(nonatomic, strong)
    NSURLSessionWebSocketTask *webSocketTask API_AVAILABLE(
        macos(10.15), ios(13.0), watchos(6.0), tvos(13.0));
@property(nonatomic, strong) NSNumber *connectionId;
@property(nonatomic, readwrite) int totalFrames;
@property(nonatomic, readonly) BOOL buffering;
@property(nonatomic, readonly) NSString *userAgent;
@property(nonatomic) dispatch_queue_t dispatchQueue;

- (void)nop:(NSTimer *)timer;

@end

@implementation FWebSocketConnection

@synthesize delegate;
@synthesize connectionId;

- (instancetype)initWith:(FRepoInfo *)repoInfo
                andQueue:(dispatch_queue_t)queue
             googleAppID:(NSString *)googleAppID
           lastSessionID:(NSString *)lastSessionID
           appCheckToken:(nullable NSString *)appCheckToken {
    self = [super init];
    if (self) {
        everConnected = NO;
        isClosed = NO;
        self.connectionId = [FUtilities LUIDGenerator];
        self.totalFrames = 0;
        self.dispatchQueue = queue;
        frame = nil;

        NSString *userAgent = [self userAgent];
        NSString *connectionURL =
            [repoInfo connectionURLWithLastSessionID:lastSessionID];

        FFLog(@"I-RDB083001", @"(wsc:%@) Connecting to: %@ as %@",
              self.connectionId, connectionURL, userAgent);

        NSURLRequest *req = [[self class] createRequestWithURL:connectionURL
                                                     userAgent:userAgent
                                                   googleAppID:googleAppID
                                                 appCheckToken:appCheckToken];

        if (@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, tvOS 13.0,
                       watchOS 6.0, *)) {
            // Regular NSURLSession websocket.
            NSOperationQueue *opQueue = [[NSOperationQueue alloc] init];
            opQueue.underlyingQueue = queue;
            NSURLSession *session = [NSURLSession
                sessionWithConfiguration:[NSURLSessionConfiguration
                                             defaultSessionConfiguration]
                                delegate:self
                           delegateQueue:opQueue];
            NSURLSessionWebSocketTask *task =
                [session webSocketTaskWithRequest:req];
            self.webSocketTask = task;

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION || TARGET_OS_MACCATALYST
            NSString *resignName = UIApplicationWillResignActiveNotification;
#elif TARGET_OS_OSX
            NSString *resignName = NSApplicationWillResignActiveNotification;
#elif TARGET_OS_WATCH
            NSString *resignName = WKApplicationWillResignActiveNotification;
#elif
#error("missing platform")
#endif
            [[NSNotificationCenter defaultCenter]
                addObserverForName:resignName
                            object:nil
                             queue:opQueue
                        usingBlock:^(NSNotification *_Nonnull note) {
                          FFLog(@"I-RDB083015",
                                @"Received notification that application "
                                @"will resign, "
                                @"closing web socket.");
                          [self onClosed];
                        }];
        }
    }
    return self;
}

- (NSString *)userAgent {
    NSString *systemVersion;
    NSString *deviceName;
    BOOL hasUiDeviceClass = NO;

// Targeted compilation is ONLY for testing. UIKit is weak-linked in actual
// release build.
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
    Class uiDeviceClass = NSClassFromString(@"UIDevice");
    if (uiDeviceClass) {
        systemVersion = [uiDeviceClass currentDevice].systemVersion;
        deviceName = [uiDeviceClass currentDevice].model;
        hasUiDeviceClass = YES;
    }
#endif // TARGET_OS_IOS || TARGET_OS_TV || (defined(TARGET_OS_VISION) &&
       // TARGET_OS_VISION)

    if (!hasUiDeviceClass) {
        NSDictionary *systemVersionDictionary = [NSDictionary
            dictionaryWithContentsOfFile:
                @"/System/Library/CoreServices/SystemVersion.plist"];
        systemVersion =
            [systemVersionDictionary objectForKey:@"ProductVersion"];
        deviceName = [systemVersionDictionary objectForKey:@"ProductName"];
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

    // Sanitize '/'s in deviceName and bundleIdentifier for stats
    deviceName = [FStringUtilities sanitizedForUserAgent:deviceName];
    bundleIdentifier =
        [FStringUtilities sanitizedForUserAgent:bundleIdentifier];

    // Firebase/5/<semver>_<build date>_<git hash>/<os version>/{device model /
    // os (Mac OS X, iPhone, etc.}_<bundle id>
    NSString *ua = [NSString
        stringWithFormat:@"Firebase/%@/%@/%@/%@_%@", kWebsocketProtocolVersion,
                         [FIRDatabase buildVersion], systemVersion, deviceName,
                         bundleIdentifier];
    return ua;
}

- (BOOL)buffering {
    return frame != nil;
}

#pragma mark -
#pragma mark Public FWebSocketConnection methods

- (void)open {
    FFLog(@"I-RDB083002", @"(wsc:%@) FWebSocketConnection open.",
          self.connectionId);
    assert(delegate);
    everConnected = NO;
    // TODO Assert url
    if (@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, tvOS 13.0,
                   watchOS 6.0, *)) {
        [self.webSocketTask resume];
        // We need to request data from the web socket in order for it to start
        // sending data.
        [self receiveWebSocketData];
    }
    dispatch_time_t when = dispatch_time(
        DISPATCH_TIME_NOW, kWebsocketConnectTimeout * NSEC_PER_SEC);
    dispatch_after(when, self.dispatchQueue, ^{
      [self closeIfNeverConnected];
    });
}

- (void)close {
    FFLog(@"I-RDB083003", @"(wsc:%@) FWebSocketConnection is being closed.",
          self.connectionId);
    isClosed = YES;
    if (@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, tvOS 13.0,
                   watchOS 6.0, *)) {
        [self.webSocketTask
            cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure
                         reason:nil];
    }
}

- (void)start {
    // Start is a no-op for websockets.
}

- (void)send:(NSDictionary *)dictionary {

    [self resetKeepAlive];

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:kNilOptions
                                                         error:nil];

    NSString *data = [[NSString alloc] initWithData:jsonData
                                           encoding:NSUTF8StringEncoding];

    NSArray *dataSegs = [FUtilities splitString:data
                                    intoMaxSize:kWebsocketMaxFrameSize];

    // First send the header so the server knows how many segments are
    // forthcoming
    if (dataSegs.count > 1) {
        NSString *formattedData =
            [NSString stringWithFormat:@"%u", (unsigned int)dataSegs.count];
        [self sendStringToWebSocket:formattedData];
    }

    // Then, actually send the segments.
    for (NSString *segment in dataSegs) {
        [self sendStringToWebSocket:segment];
    }
}

- (void)nop:(NSTimer *)timer {
    if (!isClosed) {
        FFLog(@"I-RDB083004", @"(wsc:%@) nop", self.connectionId);
        // Note: the backend is expecting a string "0" here, not any special
        // ping/pong from build in websocket APIs.
        [self sendStringToWebSocket:@"0"];
    } else {
        FFLog(@"I-RDB083005",
              @"(wsc:%@) No more websocket; invalidating nop timer.",
              self.connectionId);
        [timer invalidate];
    }
}

- (void)handleNewFrameCount:(int)numFrames {
    self.totalFrames = numFrames;
    frame = [[NSMutableString alloc] initWithString:@""];
    FFLog(@"I-RDB083006", @"(wsc:%@) handleNewFrameCount: %d",
          self.connectionId, self.totalFrames);
}

- (NSString *)extractFrameCount:(NSString *)message {
    if ([message length] <= 4) {
        int frameCount = [message intValue];
        if (frameCount > 0) {
            [self handleNewFrameCount:frameCount];
            return nil;
        }
    }
    [self handleNewFrameCount:1];
    return message;
}

- (void)appendFrame:(NSString *)message {
    [frame appendString:message];
    self.totalFrames = self.totalFrames - 1;

    if (self.totalFrames == 0) {
        // Call delegate and pass an immutable version of the frame
        NSDictionary *json = [NSJSONSerialization
            JSONObjectWithData:[frame dataUsingEncoding:NSUTF8StringEncoding]
                       options:kNilOptions
                         error:nil];
        frame = nil;
        FFLog(@"I-RDB083007",
              @"(wsc:%@) handleIncomingFrame sending complete frame: %d",
              self.connectionId, self.totalFrames);

        @autoreleasepool {
            [self.delegate onMessage:self withMessage:json];
        }
    }
}

- (void)handleIncomingFrame:(NSString *)message {
    [self resetKeepAlive];
    if (self.buffering) {
        [self appendFrame:message];
    } else {
        NSString *remaining = [self extractFrameCount:message];
        if (remaining) {
            [self appendFrame:remaining];
        }
    }
}

#pragma mark -
#pragma mark URLSessionWebSocketDelegate implementation

- (void)URLSession:(NSURLSession *)session
          webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
    didOpenWithProtocol:(NSString *)protocol
    API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0)) {
    [self webSocketDidOpen];
}

- (void)URLSession:(NSURLSession *)session
       webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask
    didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode
              reason:(NSData *)reason
    API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0)) {
    FFLog(@"I-RDB083011", @"(wsc:%@) didCloseWithCode: %ld %@",
          self.connectionId, (long)closeCode, reason);
    [self onClosed];
}

- (void)receiveWebSocketData API_AVAILABLE(macos(10.15), ios(13.0),
                                           watchos(6.0), tvos(13.0)) {
    __weak __auto_type weakSelf = self;
    [self.webSocketTask receiveMessageWithCompletionHandler:^(
                            NSURLSessionWebSocketMessage *_Nullable message,
                            NSError *_Nullable error) {
      __auto_type strongSelf = weakSelf;
      if (strongSelf == nil) {
          return;
      }

      if (message) {
          [strongSelf handleIncomingFrame:message.string];
      } else if (error && !strongSelf->isClosed) {
          FFWarn(@"I-RDB083020",
                 @"Error received from web socket, closing the connection. %@",
                 error);
          [strongSelf shutdown];
          return;
      }

      [strongSelf receiveWebSocketData];
    }];
}

// Common to both SRWebSocketDelegate and URLSessionWebSocketDelegate.

- (void)webSocketDidOpen {
    FFLog(@"I-RDB083008", @"(wsc:%@) webSocketDidOpen", self.connectionId);

    everConnected = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
      self->keepAlive =
          [NSTimer scheduledTimerWithTimeInterval:kWebsocketKeepaliveInterval
                                           target:self
                                         selector:@selector(nop:)
                                         userInfo:nil
                                          repeats:YES];
      FFLog(@"I-RDB083009", @"(wsc:%@) nop timer kicked off",
            self.connectionId);
    });
}

#pragma mark -
#pragma mark Private methods

/** Sends a string through the open web socket. */
- (void)sendStringToWebSocket:(NSString *)string {
    if (@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, tvOS 13.0,
                   watchOS 6.0, *)) {
        // Use built-in URLSessionWebSocket functionality.
        [self.webSocketTask
                  sendMessage:[[NSURLSessionWebSocketMessage alloc]
                                  initWithString:string]
            completionHandler:^(NSError *_Nullable error) {
              if (error) {
                  FFWarn(@"I-RDB083016", @"Error sending web socket data: %@.",
                         error);
                  return;
              }
            }];
    }
}

/**
 * Note that the close / onClosed / shutdown cycle here is a little different
 * from the javascript client. In order to properly handle deallocation, no
 * close-related action is taken at a higher level until we have received
 * notification from the websocket itself that it is closed. Otherwise, we end
 * up deallocating this class and the FConnection class before the websocket has
 * a change to call some of its delegate methods. So, since close is the
 * external close handler, we just set a flag saying not to call our own
 * delegate method and close the websocket. That will trigger a callback into
 * this class that can then do things like clean up the keepalive timer.
 */

- (void)closeIfNeverConnected {
    if (!everConnected) {
        FFLog(@"I-RDB083012", @"(wsc:%@) Websocket timed out on connect",
              self.connectionId);
        if (@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, tvOS 13.0,
                       watchOS 6.0, *)) {
            [self.webSocketTask
                cancelWithCloseCode:
                    NSURLSessionWebSocketCloseCodeNoStatusReceived
                             reason:nil];
        }
    }
}

- (void)shutdown {
    isClosed = YES;

    // Call delegate methods
    [self.delegate onDisconnect:self wasEverConnected:everConnected];
}

- (void)onClosed {
    if (!isClosed) {
        FFLog(@"I-RDB083013", @"Websocket is closing itself");
        [self shutdown];
    }
    if (@available(iOS 13.0, macOS 10.15, macCatalyst 13.1, tvOS 13.0,
                   watchOS 6.0, *)) {
        self.webSocketTask = nil;
    }
    if (keepAlive.isValid) {
        [keepAlive invalidate];
    }
}

- (void)resetKeepAlive {
    NSDate *newTime =
        [NSDate dateWithTimeIntervalSinceNow:kWebsocketKeepaliveInterval];
    // Calling setFireDate is actually kinda' expensive, so wait at least 5
    // seconds before updating it.
    if ([newTime timeIntervalSinceDate:keepAlive.fireDate] > 5) {
        FFLog(@"I-RDB083014", @"(wsc:%@) resetting keepalive, to %@ ; old: %@",
              self.connectionId, newTime, [keepAlive fireDate]);
        [keepAlive setFireDate:newTime];
    }
}

+ (NSURLRequest *)createRequestWithURL:(NSString *)connectionURL
                             userAgent:(NSString *)userAgent
                           googleAppID:(NSString *)googleAppID
                         appCheckToken:(nullable NSString *)appCheckToken {

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
        initWithURL:[[NSURL alloc] initWithString:connectionURL]];

    [request setValue:appCheckToken forHTTPHeaderField:kAppCheckTokenHeader];
    [request setValue:userAgent forHTTPHeaderField:kUserAgentHeader];
    [request setValue:googleAppID forHTTPHeaderField:kGoogleAppIDHeader];

    return [request copy];
}

@end
