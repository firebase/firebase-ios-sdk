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

#import "FIRMessagingConnection.h"

#import "Protos/GtalkCore.pbobjc.h"
#import "Protos/GtalkExtensions.pbobjc.h"

#import "FIRMessaging.h"
#import "FIRMessagingDataMessageManager.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessagingSecureSocket.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessagingVersionUtilities.h"
#import "FIRMessaging_Private.h"

static NSInteger const kIqSelectiveAck = 12;
static NSInteger const kIqStreamAck = 13;
static int const kInvalidStreamId = -1;
// Threshold for number of messages removed that we will ack, for short lived connections
static int const kMessageRemoveAckThresholdCount = 5;

static NSTimeInterval const kHeartbeatInterval = 30.0;
static NSTimeInterval const kConnectionTimeout = 20.0;
static int32_t const kAckingInterval = 10;

static NSString *const kUnackedS2dIdKey = @"FIRMessagingUnackedS2dIdKey";
static NSString *const kAckedS2dIdMapKey = @"FIRMessagingAckedS2dIdMapKey";

static NSString *const kRemoteFromAddress = @"from";

@interface FIRMessagingD2SInfo : NSObject

@property(nonatomic, readwrite, assign) int streamId;
@property(nonatomic, readwrite, strong) NSString *d2sID;
- (instancetype)initWithStreamId:(int)streamId d2sId:(NSString *)d2sID;

@end

@implementation FIRMessagingD2SInfo

- (instancetype)initWithStreamId:(int)streamId d2sId:(NSString *)d2sID {
  self = [super init];
  if (self) {
    _streamId = streamId;
    _d2sID = [d2sID copy];
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if ([object isKindOfClass:[self class]]) {
    FIRMessagingD2SInfo *other = (FIRMessagingD2SInfo *)object;
    return self.streamId == other.streamId && [self.d2sID isEqualToString:other.d2sID];
  }
  return NO;
}

- (NSUInteger)hash {
  return [self.d2sID hash];
}

@end

@interface FIRMessagingConnection ()<FIRMessagingSecureSocketDelegate>

@property(nonatomic, readwrite, weak) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, weak) FIRMessagingDataMessageManager *dataMessageManager;

@property(nonatomic, readwrite, assign) FIRMessagingConnectionState state;
@property(nonatomic, readwrite, copy) NSString *host;
@property(nonatomic, readwrite, assign) NSUInteger port;

@property(nonatomic, readwrite, strong) NSString *authId;
@property(nonatomic, readwrite, strong) NSString *token;

@property(nonatomic, readwrite, strong) FIRMessagingSecureSocket *socket;

@property(nonatomic, readwrite, assign) int64_t lastLoginServerTimestamp;
@property(nonatomic, readwrite, assign) int lastStreamIdAcked;
@property(nonatomic, readwrite, assign) int inStreamId;
@property(nonatomic, readwrite, assign) int outStreamId;

@property(nonatomic, readwrite, strong) NSMutableArray *unackedS2dIds;
@property(nonatomic, readwrite, strong) NSMutableDictionary *ackedS2dMap;
@property(nonatomic, readwrite, strong) NSMutableArray *d2sInfos;
// ttl=0 messages that need to be sent as soon as we establish a connection
@property(nonatomic, readwrite, strong) NSMutableArray *sendOnConnectMessages;

@property(nonatomic, readwrite, strong) NSRunLoop *runLoop;

@end


@implementation FIRMessagingConnection;

- (instancetype)initWithAuthID:(NSString *)authId
                         token:(NSString *)token
                          host:(NSString *)host
                          port:(NSUInteger)port
                       runLoop:(NSRunLoop *)runLoop
                   rmq2Manager:(FIRMessagingRmqManager *)rmq2Manager
                    fcmManager:(FIRMessagingDataMessageManager *)dataMessageManager {
  self = [super init];
  if (self) {
    _authId = [authId copy];
    _token = [token copy];
    _host = [host copy];
    _port = port;
    _runLoop = runLoop;
    _rmq2Manager = rmq2Manager;
    _dataMessageManager = dataMessageManager;

    _d2sInfos = [NSMutableArray array];

    _unackedS2dIds = [NSMutableArray arrayWithArray:[_rmq2Manager unackedS2dRmqIds]];
    _ackedS2dMap = [NSMutableDictionary dictionary];
    _sendOnConnectMessages = [NSMutableArray array];
  }
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"host: %@, port: %lu, stream id in: %d, stream id out: %d",
          self.host,
          _FIRMessaging_UL(self.port),
          self.inStreamId,
          self.outStreamId];
}

- (void)signIn {
  _FIRMessagingDevAssert(self.state == kFIRMessagingConnectionNotConnected, @"Invalid connection state.");
  if (self.state != kFIRMessagingConnectionNotConnected) {
    return;
  }

  // break it up for testing
  [self setupConnectionSocket];
  [self connectToSocket:self.socket];
}

- (void)setupConnectionSocket {
  self.socket = [[FIRMessagingSecureSocket alloc] init];
  self.socket.delegate = self;
}

- (void)connectToSocket:(FIRMessagingSecureSocket *)socket {
  self.state = kFIRMessagingConnectionConnecting;
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection000,
                          @"Start connecting to FIRMessaging service.");
  [socket connectToHost:self.host port:self.port onRunLoop:self.runLoop];
}

- (void)signOut {
  // Clear the list of messages to be sent on connect. This will only
  // have messages in it if an error happened before receiving the LoginResponse.
  [self.sendOnConnectMessages removeAllObjects];

  if (self.state == kFIRMessagingConnectionSignedIn) {
    [self sendClose];
  }
  if (self.state != kFIRMessagingConnectionNotConnected) {
    [self disconnect];
  }
}

- (void)teardown {
  if (self.state != kFIRMessagingConnectionNotConnected) {
    [self disconnect];
  }
}

#pragma mark - FIRMessagingSecureSocketDelegate

- (void)secureSocketDidConnect:(FIRMessagingSecureSocket *)socket {
  self.state = kFIRMessagingConnectionConnected;
  self.lastStreamIdAcked = 0;
  self.inStreamId = 0;
  self.outStreamId = 0;

  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection001,
                          @"Connected to FIRMessaging service.");
  [self resetUnconfirmedAcks];
  [self sendLoginRequest:self.authId token:self.token];
}

- (void)didDisconnectWithSecureSocket:(FIRMessagingSecureSocket *)socket {
  _FIRMessagingDevAssert(self.socket == socket, @"Invalid socket");
  _FIRMessagingDevAssert(self.socket.state == kFIRMessagingSecureSocketClosed, @"Socket already closed");

  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection002,
                          @"Secure socket disconnected from FIRMessaging service.");
  [self disconnect];
  [self.delegate connection:self didCloseForReason:kFIRMessagingConnectionCloseReasonSocketDisconnected];
}

- (void)secureSocket:(FIRMessagingSecureSocket *)socket
      didReceiveData:(NSData *)data
             withTag:(int8_t)tag {
  if (tag < 0) {
    // Invalid proto tag
    return;
  }

  Class klassForTag = FIRMessagingGetClassForTag((FIRMessagingProtoTag)tag);
  if ([klassForTag isSubclassOfClass:[NSNull class]]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeConnection003, @"Invalid tag %d for proto",
                            tag);
    return;
  }

  GPBMessage *proto = [klassForTag parseFromData:data error:NULL];
  if (tag == kFIRMessagingProtoTagLoginResponse && self.state != kFIRMessagingConnectionConnected) {
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeConnection004,
        @"Should not receive generated message when the connection is not connected.");
    return;
  } else if (tag != kFIRMessagingProtoTagLoginResponse && self.state != kFIRMessagingConnectionSignedIn) {
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeConnection005,
        @"Should not receive generated message when the connection is not signed in.");
    return;
  }

  // If traffic is received after a heartbeat it is safe to assume the connection is healthy.
  [self cancelConnectionTimeoutTask];
  [self performSelector:@selector(sendHeartbeatPing)
             withObject:nil
             afterDelay:kHeartbeatInterval];

  [self willProcessProto:proto];
  switch (tag) {
    case kFIRMessagingProtoTagLoginResponse:
      [self didReceiveLoginResponse:(GtalkLoginResponse *)proto];
      break;
    case kFIRMessagingProtoTagDataMessageStanza:
      [self didReceiveDataMessageStanza:(GtalkDataMessageStanza *)proto];
      break;
    case kFIRMessagingProtoTagHeartbeatPing:
      [self didReceiveHeartbeatPing:(GtalkHeartbeatPing *)proto];
      break;
    case kFIRMessagingProtoTagHeartbeatAck:
      [self didReceiveHeartbeatAck:(GtalkHeartbeatAck *)proto];
      break;
    case kFIRMessagingProtoTagClose:
      [self didReceiveClose:(GtalkClose *)proto];
      break;
    case kFIRMessagingProtoTagIqStanza:
      [self handleIqStanza:(GtalkIqStanza *)proto];
      break;
    default:
      [self didReceiveUnhandledProto:proto];
      break;
  }
}

// Called from secure socket once we have send the proto with given rmqId over the wire
// since we are mostly concerned with user facing messages which certainly have a rmqId
// we can retrieve them from the Rmq if necessary to look at stuff but for now we just
// log it.
- (void)secureSocket:(FIRMessagingSecureSocket *)socket
 didSendProtoWithTag:(int8_t)tag
               rmqId:(NSString *)rmqId {
  // log the message
  [self logMessage:rmqId messageType:tag isOut:YES];
}

#pragma mark - FIRMessagingTestConnection

- (void)sendProto:(GPBMessage *)proto {
  FIRMessagingProtoTag tag = FIRMessagingGetTagForProto(proto);
  if (tag == kFIRMessagingProtoTagLoginRequest && self.state != kFIRMessagingConnectionConnected) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection006,
                            @"Cannot send generated message when the connection is not connected.");
    return;
  } else if (tag != kFIRMessagingProtoTagLoginRequest && self.state != kFIRMessagingConnectionSignedIn) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection007,
                            @"Cannot send generated message when the connection is not signed in.");
    return;
  }

  _FIRMessagingDevAssert(self.socket != nil, @"Socket shouldn't be nil");
  if (self.socket == nil) {
    return;
  }

  [self willSendProto:proto];

  [self.socket sendData:proto.data withTag:tag rmqId:FIRMessagingGetRmq2Id(proto)];
}

- (void)sendOnConnectOrDrop:(GPBMessage *)message {
  if (self.state == kFIRMessagingConnectionSignedIn) {
    // If a connection has already been established, send normally
    [self sendProto:message];
  } else {
    // Otherwise add them to the list of messages to send after login
    [self.sendOnConnectMessages addObject:message];
  }
}

+ (GtalkLoginRequest *)loginRequestWithToken:(NSString *)token authID:(NSString *)authID {
  GtalkLoginRequest *login = [[GtalkLoginRequest alloc] init];
  login.accountId = 1000000;
  login.authService = GtalkLoginRequest_AuthService_AndroidId;
  login.authToken = token;
  login.id_p = [NSString stringWithFormat:@"%@-%@", @"ios", FIRMessagingCurrentLibraryVersion()];
  login.domain = @"mcs.android.com";
  login.deviceId = [NSString stringWithFormat:@"android-%llx", authID.longLongValue];
  login.networkType = [self currentNetworkType];
  login.resource = authID;
  login.user = authID;
  login.useRmq2 = YES;
  login.lastRmqId = 1; // Sending not enabled yet so this stays as 1.
  return login;
}

+ (int32_t)currentNetworkType {
  // http://developer.android.com/reference/android/net/ConnectivityManager.html
  int32_t fcmNetworkType;
  FIRMessagingNetworkStatus type = [[FIRMessaging messaging] networkType];
  switch (type) {
    case kFIRMessagingReachabilityReachableViaWiFi:
      fcmNetworkType = 1;
      break;

    case kFIRMessagingReachabilityReachableViaWWAN:
      fcmNetworkType = 0;
      break;

    default:
      fcmNetworkType = -1;
      break;
  }
  return fcmNetworkType;
}

- (void)sendLoginRequest:(NSString *)authId
                   token:(NSString *)token {
  GtalkLoginRequest *login = [[self class] loginRequestWithToken:token authID:authId];

  // clear the messages sent during last connection
  if ([self.d2sInfos count]) {
    [self.d2sInfos removeAllObjects];
  }

  if (self.unackedS2dIds.count > 0) {
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeConnection008,
        @"There are unacked persistent Ids in the login request: %@",
        [self.unackedS2dIds.description stringByReplacingOccurrencesOfString:@"%"
                                                                  withString:@"%%"]);
  }
  // Send out acks.
  for (NSString *unackedPersistentS2dId in self.unackedS2dIds) {
    [login.receivedPersistentIdArray addObject:unackedPersistentS2dId];
  }

  GtalkSetting *setting = [[GtalkSetting alloc] init];
  setting.name = @"new_vc";
  setting.value = @"1";
  [login.settingArray addObject:setting];

  [self sendProto:login];
}

- (void)sendHeartbeatAck {
  [self sendProto:[[GtalkHeartbeatAck alloc] init]];
}

- (void)sendHeartbeatPing {
  // cancel the previous heartbeat request.
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(sendHeartbeatPing)
                                             object:nil];
  [self scheduleConnectionTimeoutTask];
  [self sendProto:[[GtalkHeartbeatPing alloc] init]];
}

+ (GtalkIqStanza *)createStreamAck {
  GtalkIqStanza *iq = [[GtalkIqStanza alloc] init];
  iq.type = GtalkIqStanza_IqType_Set;
  iq.id_p = @"";
  GtalkExtension *ext = [[GtalkExtension alloc] init];
  ext.id_p = kIqStreamAck;
  ext.data_p = @"";
  iq.extension = ext;
  return iq;
}

- (void)sendStreamAck {
  GtalkIqStanza *iq = [[self class] createStreamAck];
  [self sendProto:iq];
}

- (void)sendClose {
  [self sendProto:[[GtalkClose alloc] init]];
}

- (void)handleIqStanza:(GtalkIqStanza *)iq {
  if (iq.hasExtension) {
    if (iq.extension.id_p == kIqStreamAck) {
      [self didReceiveStreamAck:iq];
      return;
    }
    if (iq.extension.id_p == kIqSelectiveAck) {
      [self didReceiveSelectiveAck:iq];
      return;
    }
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection009, @"Unknown ack extension id %d.",
                            iq.extension.id_p);
  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection010, @"Ip stanza without extension.");
  }
  [self didReceiveUnhandledProto:iq];
}

- (void)didReceiveLoginResponse:(GtalkLoginResponse *)loginResponse {
  if (loginResponse.hasError) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection011,
                            @"Login error with type: %@, message: %@.", loginResponse.error.type,
                            loginResponse.error.message);
    return;
  }
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection012, @"Logged onto MCS service.");
  // We sent the persisted list of unack'd messages with login so we can assume they have been ack'd
  // by the server.
  _FIRMessagingDevAssert(self.unackedS2dIds.count == 0, @"No ids present");
  _FIRMessagingDevAssert(self.outStreamId == 1, @"Login should be the first stream id");

  self.state = kFIRMessagingConnectionSignedIn;
  self.lastLoginServerTimestamp = loginResponse.serverTimestamp;
  [self.delegate didLoginWithConnection:self];
  [self sendHeartbeatPing];

  // Add all the TTL=0 messages on connect
  for (GPBMessage *message in self.sendOnConnectMessages) {
    [self sendProto:message];
  }
  [self.sendOnConnectMessages removeAllObjects];
}

- (void)didReceiveHeartbeatPing:(GtalkHeartbeatPing *)heartbeatPing {
  [self sendHeartbeatAck];
}

- (void)didReceiveHeartbeatAck:(GtalkHeartbeatAck *)heartbeatAck {
#if FIRMessaging_PROBER
  self.lastHeartbeatPingTimestamp = FIRMessagingCurrentTimestampInSeconds();
#endif
}

- (void)didReceiveDataMessageStanza:(GtalkDataMessageStanza *)dataMessageStanza {
  // TODO: Maybe add support raw data later
  [self.delegate connectionDidRecieveMessage:dataMessageStanza];
}

- (void)didReceiveUnhandledProto:(GPBMessage *)proto {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection013, @"Received unhandled proto");
}

- (void)didReceiveStreamAck:(GtalkIqStanza *)iq {
  // Server received some stuff from us we don't really need to do anything special
}

- (void)didReceiveSelectiveAck:(GtalkIqStanza *)iq {
  GtalkExtension *extension = iq.extension;
  if (extension) {
    int extensionId = extension.id_p;
    if (extensionId == kIqSelectiveAck) {

      NSString *dataString = extension.data_p;
      GtalkSelectiveAck *selectiveAck = [[GtalkSelectiveAck alloc] init];
      [selectiveAck mergeFromData:[dataString dataUsingEncoding:NSUTF8StringEncoding]
                extensionRegistry:nil];

      NSArray <NSString *>*acks = [selectiveAck idArray];

      // we've received ACK's
      [self.delegate connectionDidReceiveAckForRmqIds:acks];

      // resend unacked messages
      [self.dataMessageManager resendMessagesWithConnection:self];
    }
  }
}

- (void)didReceiveClose:(GtalkClose *)close {
  [self disconnect];
}

- (void)willProcessProto:(GPBMessage *)proto {
  self.inStreamId++;

  if ([proto isKindOfClass:GtalkDataMessageStanza.class]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection014,
                            @"RMQ: Receiving %@ with rmq_id: %@ incoming stream Id: %d",
                            proto.class, FIRMessagingGetRmq2Id(proto), self.inStreamId);
  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection015,
                            @"RMQ: Receiving %@ with incoming stream Id: %d.", proto.class,
                            self.inStreamId);
  }
  int streamId = FIRMessagingGetLastStreamId(proto);
  if (streamId != kInvalidStreamId) {
    // confirm the D2S messages that were sent by us
    [self confirmAckedD2sIdsWithStreamId:streamId];

    // We can now confirm that our ack was received by the server and start our unack'd list fresh
    // with the proto we just received.
    [self confirmAckedS2dIdsWithStreamId:streamId];
  }
  NSString *rmq2Id = FIRMessagingGetRmq2Id(proto);
  if (rmq2Id != nil) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection016,
                            @"RMQ: Add unacked persistent Id: %@.",
                            [rmq2Id stringByReplacingOccurrencesOfString:@"%" withString:@"%%"]);
    [self.unackedS2dIds addObject:rmq2Id];
    [self.rmq2Manager saveS2dMessageWithRmqId:rmq2Id]; // RMQ save
  }
  BOOL explicitAck = ([proto isKindOfClass:[GtalkDataMessageStanza class]] &&
                      [(GtalkDataMessageStanza *)proto immediateAck]);
  // If we have not sent anything and the ack threshold has been reached then explicitly send one
  // to notify the server that we have received messages.
  if (self.inStreamId - self.lastStreamIdAcked >= kAckingInterval || explicitAck) {
    [self sendStreamAck];
  }
}

- (void)willSendProto:(GPBMessage *)proto {
  self.outStreamId++;

  NSString *rmq2Id = FIRMessagingGetRmq2Id(proto);
  if ([rmq2Id length]) {
    FIRMessagingD2SInfo *d2sInfo = [[FIRMessagingD2SInfo alloc] initWithStreamId:self.outStreamId d2sId:rmq2Id];
    [self.d2sInfos addObject:d2sInfo];
  }

  // each time we send a d2s message, it acks previously received
  // s2d messages via the last (s2d) stream id received.

  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection017,
                          @"RMQ: Sending %@ with outgoing stream Id: %d.", proto.class,
                          self.outStreamId);
  // We have received messages since last time we sent something - send ack info to server.
  if (self.inStreamId > self.lastStreamIdAcked) {
    FIRMessagingSetLastStreamId(proto, self.inStreamId);
    self.lastStreamIdAcked = self.inStreamId;
  }

  if (self.unackedS2dIds.count > 0) {
    // Move all 'unack'd' messages to the ack'd map so they can be removed once the
    // ack is confirmed.
    NSArray *ackedS2dIds = [NSArray arrayWithArray:self.unackedS2dIds];
    FIRMessagingLoggerDebug(
        kFIRMessagingMessageCodeConnection018, @"RMQ: Mark persistent Ids as acked: %@.",
        [ackedS2dIds.description stringByReplacingOccurrencesOfString:@"%" withString:@"%%"]);
    [self.unackedS2dIds removeAllObjects];
    self.ackedS2dMap[[@(self.outStreamId) stringValue]] = ackedS2dIds;
  }
}

#pragma mark - Private

/**
 * This processes the s2d message received in reference to the d2s messages
 * that we have sent before.
 */
- (void)confirmAckedD2sIdsWithStreamId:(int)lastReceivedStreamId {
  NSMutableArray *d2sIdsAcked = [NSMutableArray array];
  for (FIRMessagingD2SInfo *d2sInfo in self.d2sInfos) {
    if (lastReceivedStreamId < d2sInfo.streamId) {
      break;
    }
    [d2sIdsAcked addObject:d2sInfo];
  }

  NSMutableArray *rmqIds = [NSMutableArray arrayWithCapacity:[d2sIdsAcked count]];
  // remove ACK'ed messages
  for (FIRMessagingD2SInfo *d2sInfo in d2sIdsAcked) {
    if ([d2sInfo.d2sID length]) {
      [rmqIds addObject:d2sInfo.d2sID];
    }
    [self.d2sInfos removeObject:d2sInfo];
  }
  [self.delegate connectionDidReceiveAckForRmqIds:rmqIds];
  int count = [self.delegate connectionDidReceiveAckForRmqIds:rmqIds];
  if (kMessageRemoveAckThresholdCount > 0 && count >= kMessageRemoveAckThresholdCount) {
    // For short lived connections, if a large number of messages are removed, send an
    // ack straight away so the server knows that this message was received.
    [self sendStreamAck];
  }
}

/**
 * Called when a stream ACK or a selective ACK are received - this indicates the message has
 * been received by MCS.
 */
- (void)didReceiveAckForRmqIds:(NSArray *)rmqIds {
  // TODO: let the user know that the following messages were received by the server
}

- (void)confirmAckedS2dIdsWithStreamId:(int)lastReceivedStreamId {
  // If the server hasn't received the streamId yet.
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection019,
                          @"RMQ: Server last received stream Id: %d.", lastReceivedStreamId);
  if (lastReceivedStreamId < self.outStreamId) {
    // TODO: This could be a good indicator that we need to re-send something (acks)?
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection020,
                            @"RMQ: There are unsent messages that should be send...\n"
                             "server received: %d\nlast stream id sent: %d",
                            lastReceivedStreamId, self.outStreamId);
  }

  NSSet *ackedStreamIds =
    [self.ackedS2dMap keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop) {
      NSString *streamId = key;
      return streamId.intValue <= lastReceivedStreamId;
    }];
  NSMutableArray *s2dIdsToDelete = [NSMutableArray array];

  for (NSString *streamId in ackedStreamIds) {
    NSArray *ackedS2dIds = self.ackedS2dMap[streamId];
    if (ackedS2dIds.count > 0) {
      FIRMessagingLoggerDebug(
          kFIRMessagingMessageCodeConnection021,
          @"RMQ: Mark persistent Ids as confirmed by stream id %@: %@.", streamId,
          [ackedS2dIds.description stringByReplacingOccurrencesOfString:@"%" withString:@"%%"]);
      [self.ackedS2dMap removeObjectForKey:streamId];
    }

    [s2dIdsToDelete addObjectsFromArray:ackedS2dIds];
  }

  // clean up s2d ids that the server knows we've received.
  // we let the server know via a s2d last stream id received in a
  // d2s message. the server lets us know it has received our d2s
  // message via a d2s last stream id received in a s2d message.
  [self.rmq2Manager removeS2dIds:s2dIdsToDelete];
}

- (void)resetUnconfirmedAcks {
  [self.ackedS2dMap enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [self.unackedS2dIds addObjectsFromArray:obj];
  }];
  [self.ackedS2dMap removeAllObjects];
}

- (void)disconnect {
  _FIRMessagingDevAssert(self.state != kFIRMessagingConnectionNotConnected, @"Connection already not connected");
  // cancel pending timeout tasks.
  [self cancelConnectionTimeoutTask];
  // cancel pending heartbeat.
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(sendHeartbeatPing)
                                             object:nil];
  // Unset the delegate. FIRMessagingConnection will not receive further events from the socket from now on.
  self.socket.delegate = nil;
  [self.socket disconnect];
  self.state = kFIRMessagingConnectionNotConnected;
}

- (void)connectionTimedOut {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection022,
                          @"Connection to FIRMessaging service timed out.");
  [self disconnect];
  [self.delegate connection:self didCloseForReason:kFIRMessagingConnectionCloseReasonTimeout];
}

- (void)scheduleConnectionTimeoutTask {
  // cancel the previous heartbeat timeout event and schedule a new one.
  [self cancelConnectionTimeoutTask];
  [self performSelector:@selector(connectionTimedOut)
             withObject:nil
             afterDelay:[self connectionTimeoutInterval]];
}

- (void)cancelConnectionTimeoutTask {
  // cancel pending timeout tasks.
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(connectionTimedOut)
                                             object:nil];
}

- (void)logMessage:(NSString *)description messageType:(int)messageType isOut:(BOOL)isOut {
  messageType = isOut ? -messageType : messageType;
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeConnection023,
                          @"Send msg: %@ type: %d inStreamId: %d outStreamId: %d", description,
                          messageType, self.inStreamId, self.outStreamId);
}

- (NSTimeInterval)connectionTimeoutInterval {
  return kConnectionTimeout;
}

@end
