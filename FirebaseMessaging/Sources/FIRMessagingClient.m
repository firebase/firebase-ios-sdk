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

#import "FirebaseMessaging/Sources/FIRMessagingClient.h"

#import "FirebaseMessaging/Sources/Protos/GtalkCore.pbobjc.h"

#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#import <FirebaseMessaging/FIRMessaging.h>
#import "GoogleUtilities/Reachability/Private/GULReachabilityChecker.h"

#import "FirebaseMessaging/Sources/FIRMessagingConnection.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingDataMessageManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingTopicsCommon.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"

static const NSTimeInterval kConnectTimeoutInterval = 40.0;
static const NSTimeInterval kReconnectDelayInSeconds = 2 * 60;  // 2 minutes

static const NSUInteger kMaxRetryExponent = 10;  // 2^10 = 1024 seconds ~= 17 minutes

static NSString *const kFIRMessagingMCSServerHost = @"mtalk.google.com";
static NSUInteger const kFIRMessagingMCSServerPort = 5228;

// register device with checkin
typedef void (^FIRMessagingRegisterDeviceHandler)(NSError *error);

static NSString *FIRMessagingServerHost() {
  static NSString *serverHost = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *customServerHostAndPort = environment[@"FCM_MCS_HOST"];
    NSString *host = [customServerHostAndPort componentsSeparatedByString:@":"].firstObject;
    if (host) {
      serverHost = host;
    } else {
      serverHost = kFIRMessagingMCSServerHost;
    }
  });
  return serverHost;
}

static NSUInteger FIRMessagingServerPort() {
  static NSUInteger serverPort = kFIRMessagingMCSServerPort;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *customServerHostAndPort = environment[@"FCM_MCS_HOST"];
    NSArray<NSString *> *components = [customServerHostAndPort componentsSeparatedByString:@":"];
    NSUInteger port = (NSUInteger)[components.lastObject integerValue];
    if (port != 0) {
      serverPort = port;
    }
  });
  return serverPort;
}

@interface FIRMessagingClient () <FIRMessagingConnectionDelegate>

@property(nonatomic, readwrite, weak) id<FIRMessagingClientDelegate> clientDelegate;
@property(nonatomic, readwrite, strong) FIRMessagingConnection *connection;
@property(nonatomic, readwrite, strong) NSString *senderId;

// FIRMessagingService owns these instances
@property(nonatomic, readwrite, weak) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, weak) GULReachabilityChecker *reachability;

@property(nonatomic, readwrite, assign) int64_t lastConnectedTimestamp;
@property(nonatomic, readwrite, assign) int64_t lastDisconnectedTimestamp;
@property(nonatomic, readwrite, assign) NSUInteger connectRetryCount;

// Should we stay connected to MCS or not. Should be YES throughout the lifetime
// of a MCS connection. If set to NO it signifies that an existing MCS connection
// should be disconnected.
@property(nonatomic, readwrite, assign) BOOL stayConnected;
@property(nonatomic, readwrite, assign) NSTimeInterval connectionTimeoutInterval;

// Used if the MCS connection suddenly breaksdown in the middle and we want to reconnect
// with some permissible delay we schedule a reconnect and set it to YES and when it's
// scheduled this will be set back to NO.
@property(nonatomic, readwrite, assign) BOOL didScheduleReconnect;

// handlers
@property(nonatomic, readwrite, copy) FIRMessagingConnectCompletionHandler connectHandler;

@end

@implementation FIRMessagingClient

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithDelegate:(id<FIRMessagingClientDelegate>)delegate
                    reachability:(GULReachabilityChecker *)reachability
                     rmq2Manager:(FIRMessagingRmqManager *)rmq2Manager {
  self = [super init];
  if (self) {
    _reachability = reachability;
    _clientDelegate = delegate;
    _rmq2Manager = rmq2Manager;
    _connectionTimeoutInterval = kConnectTimeoutInterval;
    // Listen for checkin fetch notifications, as connecting to MCS may have failed due to
    // missing checkin info (while it was being fetched).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkinFetched:)
                                                 name:kFIRMessagingCheckinFetchedNotification
                                               object:nil];
  }
  return self;
}

- (void)teardown {
  if (![NSThread isMainThread]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient000,
                            @"FIRMessagingClient should be called from main thread only.");
  }
  self.stayConnected = NO;

  // Clear all the handlers
  self.connectHandler = nil;

  [self.connection teardown];

  [NSObject cancelPreviousPerformRequestsWithTarget:self];

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - MCS Connection

- (BOOL)isConnected {
  return self.stayConnected && self.connection.state != kFIRMessagingConnectionNotConnected;
}

- (BOOL)isConnectionActive {
  return self.stayConnected && self.connection.state == kFIRMessagingConnectionSignedIn;
}

- (BOOL)shouldStayConnected {
  return self.stayConnected;
}

- (void)retryConnectionImmediately:(BOOL)immediately {
  // Do not connect to an invalid host or an invalid port
  if (!self.stayConnected || !self.connection.host || self.connection.port == 0) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient004,
                            @"FIRMessaging connection will not reconnect to MCS. "
                            @"Stay connected: %d",
                            self.stayConnected);
    return;
  }
  if (self.isConnectionActive) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient005,
                            @"FIRMessaging Connection skip retry, active");
    // already connected and logged in.
    // Heartbeat alarm is set and will force close the connection
    return;
  }
  if (self.isConnected) {
    // already connected and logged in.
    // Heartbeat alarm is set and will force close the connection
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient006,
                            @"FIRMessaging Connection skip retry, connected");
    return;
  }

  if (immediately) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient007,
                            @"Try to connect to MCS immediately");
    [self tryToConnect];
  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient008, @"Try to connect to MCS lazily");
    // Avoid all the other logic that we have in other clients, since this would always happen
    // when the app is in the foreground and since the FIRMessaging connection isn't shared with any
    // other app we can be more aggressive in reconnections
    if (!self.didScheduleReconnect) {
      FIRMessaging_WEAKIFY(self);
      dispatch_after(
          dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kReconnectDelayInSeconds * NSEC_PER_SEC)),
          dispatch_get_main_queue(), ^{
            FIRMessaging_STRONGIFY(self);
            self.didScheduleReconnect = NO;
            [self tryToConnect];
          });

      self.didScheduleReconnect = YES;
    }
  }
}

- (void)connectWithHandler:(FIRMessagingConnectCompletionHandler)handler {
  if (self.isConnected) {
    NSError *error =
        [NSError messagingErrorWithCode:kFIRMessagingErrorCodeAlreadyConnected
                          failureReason:
                              @"FIRMessaging is already connected. Will not try to connect again."];
    handler(error);
    return;
  }
  self.lastDisconnectedTimestamp = FIRMessagingCurrentTimestampInMilliseconds();
  self.connectHandler = handler;
  [self connect];
}

- (void)connect {
  // reset retry counts
  self.connectRetryCount = 0;

  if (self.isConnected) {
    return;
  }

  self.stayConnected = YES;
  if (![[FIRInstanceID instanceID] tryToLoadValidCheckinInfo]) {
    // Checkin info is not available. This may be due to the checkin still being fetched.
    NSString *failureReason = @"Failed to connect to MCS. No deviceID and secret found.";
    if (self.connectHandler) {
      NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeMissingDeviceID
                                         failureReason:failureReason];
      self.connectHandler(error);
    }
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient009, @"%@", failureReason);
    // Return for now. If checkin is, in fact, retrieved, the
    // |kFIRMessagingCheckinFetchedNotification| will be fired.
    return;
  }
  [self setupConnectionAndConnect];
}

- (void)disconnect {
  // user called disconnect
  // We don't want to connect later even if no network is available.
  [self disconnectWithTryToConnectLater:NO];
}

/**
 *  Disconnect the current client connection. Also explicitly stop and connction retries.
 *
 *  @param tryToConnectLater If YES will try to connect later when sending upstream messages
 *                           else if NO do not connect again until user explicitly calls
 *                           connect.
 */
- (void)disconnectWithTryToConnectLater:(BOOL)tryToConnectLater {
  self.stayConnected = tryToConnectLater;
  [self.connection signOut];

  // since we can disconnect while still trying to establish the connection it's required to
  // cancel all performSelectors else the object might be retained
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(tryToConnect)
                                             object:nil];
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(didConnectTimeout)
                                             object:nil];
  self.connectHandler = nil;
}

#pragma mark - Checkin Notification
- (void)checkinFetched:(NSNotification *)notification {
  // A failed checkin may have been the reason for the connection failure. Attempt a connection
  // if the checkin fetched notification is fired.
  if (self.stayConnected && !self.isConnected) {
    [self connect];
  }
}

#pragma mark - Messages

- (void)sendMessage:(GPBMessage *)message {
  [self.connection sendProto:message];
}

- (void)sendOnConnectOrDrop:(GPBMessage *)message {
  [self.connection sendOnConnectOrDrop:message];
}

#pragma mark - FIRMessagingConnectionDelegate

- (void)connection:(FIRMessagingConnection *)fcmConnection
    didCloseForReason:(FIRMessagingConnectionCloseReason)reason {
  self.lastDisconnectedTimestamp = FIRMessagingCurrentTimestampInMilliseconds();

  if (reason == kFIRMessagingConnectionCloseReasonSocketDisconnected) {
    // Cancel the not-yet-triggered timeout task before rescheduling, in case the previous sign in
    // failed, due to a connection error caused by bad network.
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(didConnectTimeout)
                                               object:nil];
  }
  if (self.stayConnected) {
    [self scheduleConnectRetry];
  }
}

- (void)didLoginWithConnection:(FIRMessagingConnection *)fcmConnection {
  // Cancel the not-yet-triggered timeout task.
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(didConnectTimeout)
                                             object:nil];
  self.connectRetryCount = 0;
  self.lastConnectedTimestamp = FIRMessagingCurrentTimestampInMilliseconds();

  [self.dataMessageManager setDeviceAuthID:[FIRInstanceID instanceID].deviceAuthID
                               secretToken:[FIRInstanceID instanceID].secretToken];
  if (self.connectHandler) {
    self.connectHandler(nil);
    // notified the third party app with the registrationId.
    // we don't want them to know about the connection status and how it changes
    // so remove this handler
    self.connectHandler = nil;
  }
}

- (void)connectionDidRecieveMessage:(GtalkDataMessageStanza *)message {
  NSDictionary *parsedMessage = [self.dataMessageManager processPacket:message];
  if ([parsedMessage count]) {
    [self.dataMessageManager didReceiveParsedMessage:parsedMessage];
  }
}

- (void)connectionDidReceiveAckForRmqIds:(NSArray *)rmqIds {
  NSSet *rmqIDSet = [NSSet setWithArray:rmqIds];
  NSMutableArray *messagesSent = [NSMutableArray arrayWithCapacity:rmqIds.count];
  [self.rmq2Manager scanWithRmqMessageHandler:^(NSDictionary *messages) {
    for (NSString *rmqID in messages) {
      GPBMessage *proto = messages[rmqID];
      GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)proto;
      if ([rmqIDSet containsObject:rmqID]) {
        [messagesSent addObject:stanza];
      }
    }
  }];
  for (GtalkDataMessageStanza *message in messagesSent) {
    [self.dataMessageManager didSendDataMessageStanza:message];
  }
  [self.rmq2Manager removeRmqMessagesWithRmqIds:rmqIds];
}

#pragma mark - Private

- (void)setupConnectionAndConnect {
  [self setupConnection];
  [self tryToConnect];
}

- (void)setupConnection {
  NSString *host = FIRMessagingServerHost();
  NSUInteger port = FIRMessagingServerPort();
  if (self.connection != nil) {
    // if there is an old connection, explicitly sign it off.
    [self.connection signOut];
    self.connection.delegate = nil;
  }
  self.connection =
      [[FIRMessagingConnection alloc] initWithAuthID:[FIRInstanceID instanceID].deviceAuthID
                                               token:[FIRInstanceID instanceID].secretToken
                                                host:host
                                                port:port
                                             runLoop:[NSRunLoop mainRunLoop]
                                         rmq2Manager:self.rmq2Manager
                                          fcmManager:self.dataMessageManager];
  self.connection.delegate = self;
}

- (void)tryToConnect {
  if (!self.stayConnected) {
    return;
  }

  // Cancel any other pending signin requests.
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(tryToConnect)
                                             object:nil];
  NSString *deviceAuthID = [FIRInstanceID instanceID].deviceAuthID;
  NSString *secretToken = [FIRInstanceID instanceID].secretToken;
  if (deviceAuthID.length == 0 || secretToken.length == 0 || !self.connection) {
    FIRMessagingLoggerWarn(
        kFIRMessagingMessageCodeClientInvalidState,
        @"Invalid state to connect, deviceAuthID: %@, secretToken: %@, connection state: %ld",
        deviceAuthID, secretToken, (long)self.connection.state);
    return;
  }
  // Do not re-sign in if there is already a connection in progress.
  if (self.connection.state != kFIRMessagingConnectionNotConnected) {
    return;
  }

  self.connectRetryCount = MIN(kMaxRetryExponent, self.connectRetryCount + 1);
  [self performSelector:@selector(didConnectTimeout)
             withObject:nil
             afterDelay:self.connectionTimeoutInterval];
  [self.connection signIn];
}

- (void)didConnectTimeout {
  if (self.connection.state == kFIRMessagingConnectionSignedIn) {
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeClientInvalidStateTimeout,
                           @"Invalid state for connection timeout.");
  }
  if (self.stayConnected) {
    [self.connection signOut];
    [self scheduleConnectRetry];
  }
}

#pragma mark - Schedulers

- (void)scheduleConnectRetry {
  GULReachabilityStatus status = self.reachability.reachabilityStatus;
  BOOL isReachable = (status == kGULReachabilityViaWifi || status == kGULReachabilityViaCellular);
  if (!isReachable) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient010,
                            @"Internet not reachable when signing into MCS during a retry");

    FIRMessagingConnectCompletionHandler handler = [self.connectHandler copy];
    // disconnect before issuing a callback
    [self disconnectWithTryToConnectLater:YES];
    NSError *error =
        [NSError messagingErrorWithCode:kFIRMessagingErrorCodeNetwork
                          failureReason:@"No internet available, cannot connect to FIRMessaging"];
    if (handler) {
      handler(error);
      self.connectHandler = nil;
    }
    return;
  }

  NSUInteger retryInterval = [self nextRetryInterval];

  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient011,
                          @"Failed to sign in to MCS, retry in %lu seconds",
                          _FIRMessaging_UL(retryInterval));
  [self performSelector:@selector(tryToConnect) withObject:nil afterDelay:retryInterval];
}

- (NSUInteger)nextRetryInterval {
  return 1u << self.connectRetryCount;
}

@end
