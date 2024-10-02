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
#import <Foundation/Foundation.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Api/FIRDatabaseConfig.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FCompoundHash.h"
#import "FirebaseDatabase/Sources/Core/FPersistentConnection.h"
#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Core/FQuerySpec.h"
#import "FirebaseDatabase/Sources/Core/FRangeMerge.h"
#import "FirebaseDatabase/Sources/Core/FSyncTree.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FIRRetryHelper.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/FIndex.h"
#import "FirebaseDatabase/Sources/Login/FIRDatabaseConnectionContextProvider.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseReference.h"
#import "FirebaseDatabase/Sources/Snapshot/FSnapshotUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/FAtomicNumber.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleCallbackStatus.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleOnDisconnect.h"
#if !TARGET_OS_WATCH
#import <SystemConfiguration/SystemConfiguration.h>
#endif // !TARGET_OS_WATCH
#import <dlfcn.h>
#import <netinet/in.h>

@interface FOutstandingQuery : NSObject

@property(nonatomic, strong) FQuerySpec *query;
@property(nonatomic, strong) NSNumber *tagId;
@property(nonatomic, strong) id<FSyncTreeHash> syncTreeHash;
@property(nonatomic, copy) fbt_void_nsstring onComplete;

@end

@implementation FOutstandingQuery

@end

@interface FOutstandingPut : NSObject

@property(nonatomic, strong) NSString *action;
@property(nonatomic, strong) NSDictionary *request;
@property(nonatomic, copy) fbt_void_nsstring_nsstring onCompleteBlock;
@property(nonatomic) BOOL sent;

@end

@implementation FOutstandingPut

@end

@interface FOutstandingGet : NSObject

@property(nonatomic, strong) NSDictionary *request;
@property(nonatomic, copy) fbt_void_nsstring_id_nsstring onCompleteBlock;
@property(nonatomic) BOOL sent;

@end

@implementation FOutstandingGet

@end

typedef enum {
    ConnectionStateDisconnected,
    ConnectionStateGettingToken,
    ConnectionStateConnecting,
    ConnectionStateAuthenticating,
    ConnectionStateConnected
} ConnectionState;

@interface FPersistentConnection () {
    ConnectionState connectionState;
    BOOL firstConnection;
    NSTimeInterval reconnectDelay;
    NSTimeInterval lastConnectionAttemptTime;
    NSTimeInterval lastConnectionEstablishedTime;
#if !TARGET_OS_WATCH
    SCNetworkReachabilityRef reachability;
#endif // !TARGET_OS_WATCH
}

- (int)getNextRequestNumber;
- (void)onDataPushWithAction:(NSString *)action andBody:(NSDictionary *)body;
- (void)handleTimestamp:(NSNumber *)timestamp;
- (void)sendOnDisconnectAction:(NSString *)action
                       forPath:(NSString *)pathString
                      withData:(id)data
                   andCallback:(fbt_void_nsstring_nsstring)callback;

@property(nonatomic, strong) FConnection *realtime;
@property(nonatomic, strong) NSMutableDictionary *listens;
@property(nonatomic, strong) NSMutableDictionary *outstandingPuts;
@property(nonatomic, strong) NSMutableDictionary *outstandingGets;
@property(nonatomic, strong) NSMutableArray *onDisconnectQueue;
@property(nonatomic, strong) FRepoInfo *repoInfo;
@property(nonatomic, strong) FAtomicNumber *putCounter;
@property(nonatomic, strong) FAtomicNumber *getCounter;
@property(nonatomic, strong) FAtomicNumber *requestNumber;
@property(nonatomic, strong) NSMutableDictionary *requestCBHash;
@property(nonatomic, strong) FIRDatabaseConfig *config;
@property(nonatomic) NSUInteger unackedListensCount;
@property(nonatomic, strong) NSMutableArray *putsToAck;
@property(nonatomic, strong) dispatch_queue_t dispatchQueue;
@property(nonatomic, strong) NSString *lastSessionID;
@property(nonatomic, strong) NSMutableSet *interruptReasons;
@property(nonatomic, strong) FIRRetryHelper *retryHelper;
@property(nonatomic, strong) id<FIRDatabaseConnectionContextProvider>
    contextProvider;
@property(nonatomic, strong) NSString *authToken;
@property(nonatomic) BOOL forceTokenRefreshes;
@property(nonatomic) NSUInteger currentFetchTokenAttempt;

@end

@implementation FPersistentConnection

- (id)initWithRepoInfo:(FRepoInfo *)repoInfo
         dispatchQueue:(dispatch_queue_t)dispatchQueue
                config:(FIRDatabaseConfig *)config {
    self = [super init];
    if (self) {
        self->_config = config;
        self->_repoInfo = repoInfo;
        self->_dispatchQueue = dispatchQueue;
        self->_contextProvider = config.contextProvider;
        NSAssert(self->_contextProvider != nil,
                 @"Expected auth token provider");
        self.interruptReasons = [NSMutableSet set];

        self.listens = [[NSMutableDictionary alloc] init];
        self.outstandingPuts = [[NSMutableDictionary alloc] init];
        self.outstandingGets = [[NSMutableDictionary alloc] init];
        self.onDisconnectQueue = [[NSMutableArray alloc] init];
        self.putCounter = [[FAtomicNumber alloc] init];
        self.getCounter = [[FAtomicNumber alloc] init];
        self.requestNumber = [[FAtomicNumber alloc] init];
        self.requestCBHash = [[NSMutableDictionary alloc] init];
        self.unackedListensCount = 0;
        self.putsToAck = [NSMutableArray array];
        connectionState = ConnectionStateDisconnected;
        firstConnection = YES;
        reconnectDelay = kPersistentConnReconnectMinDelay;

        self->_retryHelper = [[FIRRetryHelper alloc]
                initWithDispatchQueue:dispatchQueue
            minRetryDelayAfterFailure:kPersistentConnReconnectMinDelay
                        maxRetryDelay:kPersistentConnReconnectMaxDelay
                        retryExponent:kPersistentConnReconnectMultiplier
                         jitterFactor:0.7];

        // Make sure we don't actually connect until open is called
        [self interruptForReason:kFInterruptReasonWaitingForOpen];
    }
    // nb: The reason establishConnection isn't called here like the JS version
    // is because callers need to set the delegate first. The ctor can be
    // modified to accept the delegate but that deviates from normal ios
    // conventions. After the delegate has been set, the caller is responsible
    // for calling establishConnection:
    return self;
}

- (void)dealloc {
#if !TARGET_OS_WATCH
    if (reachability) {
        // Unschedule the notifications
        SCNetworkReachabilitySetDispatchQueue(reachability, NULL);
        CFRelease(reachability);
    }
#endif // !TARGET_OS_WATCH
}

#pragma mark -
#pragma mark Public methods

- (void)open {
    [self resumeForReason:kFInterruptReasonWaitingForOpen];
}

/**
 * Note that the listens dictionary has a type of Map[String (pathString),
 * Map[FQueryParams, FOutstandingQuery]]
 *
 * This means, for each path we care about, there are sets of queryParams that
 * correspond to an FOutstandingQuery object. There can be multiple sets at a
 * path since we overlap listens for a short time while adding or removing a
 * query from a location in the tree.
 */
- (void)listen:(FQuerySpec *)query
         tagId:(NSNumber *)tagId
          hash:(id<FSyncTreeHash>)hash
    onComplete:(fbt_void_nsstring)onComplete {
    FFLog(@"I-RDB034001", @"Listen called for %@", query);

    NSAssert(self.listens[query] == nil,
             @"listen() called twice for the same query");
    NSAssert(query.isDefault || !query.loadsAllData,
             @"listen called for non-default but complete query");
    FOutstandingQuery *outstanding = [[FOutstandingQuery alloc] init];
    outstanding.query = query;
    outstanding.tagId = tagId;
    outstanding.syncTreeHash = hash;
    outstanding.onComplete = onComplete;
    [self.listens setObject:outstanding forKey:query];
    if ([self connected]) {
        [self sendListen:outstanding];
    }
}

- (void)putData:(id)data
         forPath:(NSString *)pathString
        withHash:(NSString *)hash
    withCallback:(fbt_void_nsstring_nsstring)onComplete {
    [self putInternal:data
            forAction:kFWPRequestActionPut
              forPath:pathString
             withHash:hash
         withCallback:onComplete];
}

- (void)mergeData:(id)data
          forPath:(NSString *)pathString
     withCallback:(fbt_void_nsstring_nsstring)onComplete {
    [self putInternal:data
            forAction:kFWPRequestActionMerge
              forPath:pathString
             withHash:nil
         withCallback:onComplete];
}

- (void)onDisconnectPutData:(id)data
                    forPath:(FPath *)path
               withCallback:(fbt_void_nsstring_nsstring)callback {
    if ([self canSendWrites]) {
        [self sendOnDisconnectAction:kFWPRequestActionDisconnectPut
                             forPath:[path description]
                            withData:data
                         andCallback:callback];
    } else {
        FTupleOnDisconnect *tuple = [[FTupleOnDisconnect alloc] init];
        tuple.pathString = [path description];
        tuple.action = kFWPRequestActionDisconnectPut;
        tuple.data = data;
        tuple.onComplete = callback;
        [self.onDisconnectQueue addObject:tuple];
    }
}

- (void)onDisconnectMergeData:(id)data
                      forPath:(FPath *)path
                 withCallback:(fbt_void_nsstring_nsstring)callback {
    if ([self canSendWrites]) {
        [self sendOnDisconnectAction:kFWPRequestActionDisconnectMerge
                             forPath:[path description]
                            withData:data
                         andCallback:callback];
    } else {
        FTupleOnDisconnect *tuple = [[FTupleOnDisconnect alloc] init];
        tuple.pathString = [path description];
        tuple.action = kFWPRequestActionDisconnectMerge;
        tuple.data = data;
        tuple.onComplete = callback;
        [self.onDisconnectQueue addObject:tuple];
    }
}

- (void)onDisconnectCancelPath:(FPath *)path
                  withCallback:(fbt_void_nsstring_nsstring)callback {
    if ([self canSendWrites]) {
        [self sendOnDisconnectAction:kFWPRequestActionDisconnectCancel
                             forPath:[path description]
                            withData:[NSNull null]
                         andCallback:callback];
    } else {
        FTupleOnDisconnect *tuple = [[FTupleOnDisconnect alloc] init];
        tuple.pathString = [path description];
        tuple.action = kFWPRequestActionDisconnectCancel;
        tuple.data = [NSNull null];
        tuple.onComplete = callback;
        [self.onDisconnectQueue addObject:tuple];
    }
}

- (void)unlisten:(FQuerySpec *)query tagId:(NSNumber *)tagId {
    FPath *path = query.path;
    FFLog(@"I-RDB034002", @"Unlistening for %@", query);

    NSArray *outstanding = [self removeListen:query];
    if (outstanding.count > 0 && [self connected]) {
        [self sendUnlisten:path queryParams:query.params tagId:tagId];
    }
}

- (void)refreshAuthToken:(NSString *)token {
    self.authToken = token;
    if ([self connected]) {
        if (token != nil) {
            [self sendAuthAndRestoreStateAfterComplete:NO];
        } else {
            [self sendUnauth];
        }
    }
}

#pragma mark -
#pragma mark Connection status

- (BOOL)connected {
    return self->connectionState == ConnectionStateAuthenticating ||
           self->connectionState == ConnectionStateConnected;
}

- (BOOL)canSendWrites {
    return self->connectionState == ConnectionStateConnected;
}

- (BOOL)canSendReads {
    return self->connectionState == ConnectionStateConnected;
}

#pragma mark -
#pragma mark FConnection delegate methods

- (void)onReady:(FConnection *)fconnection
         atTime:(NSNumber *)timestamp
      sessionID:(NSString *)sessionID {
    FFLog(@"I-RDB034003", @"On ready");
    lastConnectionEstablishedTime = [[NSDate date] timeIntervalSince1970];
    [self handleTimestamp:timestamp];

    if (firstConnection) {
        [self sendConnectStats];
    }

    [self restoreAuth];
    firstConnection = NO;
    self.lastSessionID = sessionID;
    dispatch_async(self.dispatchQueue, ^{
      [self.delegate onConnect:self];
    });
}

- (void)onDataMessage:(FConnection *)fconnection
          withMessage:(NSDictionary *)message {
    if (message[kFWPRequestNumber] != nil) {
        // this is a response to a request we sent
        NSNumber *rn = [NSNumber
            numberWithInt:[[message objectForKey:kFWPRequestNumber] intValue]];
        if ([self.requestCBHash objectForKey:rn]) {
            void (^callback)(NSDictionary *) =
                [self.requestCBHash objectForKey:rn];
            [self.requestCBHash removeObjectForKey:rn];

            if (callback) {
                // dispatch_async(self.dispatchQueue, ^{
                callback([message objectForKey:kFWPResponseForRNData]);
                //});
            }
        }
    } else if (message[kFWPRequestError] != nil) {
        NSString *error = [message objectForKey:kFWPRequestError];
        @throw [[NSException alloc] initWithName:@"FirebaseDatabaseServerError"
                                          reason:error
                                        userInfo:nil];
    } else if (message[kFWPAsyncServerAction] != nil) {
        // this is a server push of some sort
        NSString *action = [message objectForKey:kFWPAsyncServerAction];
        NSDictionary *body = [message objectForKey:kFWPAsyncServerPayloadBody];
        [self onDataPushWithAction:action andBody:body];
    }
}

- (void)onDisconnect:(FConnection *)fconnection
          withReason:(FDisconnectReason)reason {
    FFLog(@"I-RDB034004", @"Got on disconnect due to %s",
          (reason == DISCONNECT_REASON_SERVER_RESET) ? "server_reset"
                                                     : "other");
    connectionState = ConnectionStateDisconnected;
    // Drop the realtime connection
    self.realtime = nil;
    [self cancelSentTransactions];
    [self.requestCBHash removeAllObjects];
    self.unackedListensCount = 0;
    if ([self shouldReconnect]) {
        NSTimeInterval timeSinceLastConnectSucceeded =
            [[NSDate date] timeIntervalSince1970] -
            lastConnectionEstablishedTime;
        BOOL lastConnectionWasSuccessful;
        if (lastConnectionEstablishedTime > 0) {
            lastConnectionWasSuccessful =
                timeSinceLastConnectSucceeded >
                kPersistentConnSuccessfulConnectionEstablishedDelay;
        } else {
            lastConnectionWasSuccessful = NO;
        }

        if (reason == DISCONNECT_REASON_SERVER_RESET ||
            lastConnectionWasSuccessful) {
            [self.retryHelper signalSuccess];
        }
        [self tryScheduleReconnect];
    }
    lastConnectionEstablishedTime = 0;
    [self.delegate onDisconnect:self];
}

- (void)onKill:(FConnection *)fconnection withReason:(NSString *)reason {
    FFWarn(@"I-RDB034005",
           @"Firebase Database connection was forcefully killed by the server. "
           @" Will not attempt reconnect. Reason: %@",
           reason);
    [self interruptForReason:kFInterruptReasonServerKill];
}

#pragma mark -
#pragma mark Connection handling methods

- (void)interruptForReason:(NSString *)reason {
    FFLog(@"I-RDB034006", @"Connection interrupted for: %@", reason);

    [self.interruptReasons addObject:reason];
    if (self.realtime) {
        // Will call onDisconnect and set the connection state to Disconnected
        [self.realtime close];
        self.realtime = nil;
    } else {
        [self.retryHelper cancel];
        self->connectionState = ConnectionStateDisconnected;
    }
    // Reset timeouts
    [self.retryHelper signalSuccess];
}

- (void)resumeForReason:(NSString *)reason {
    FFLog(@"I-RDB034007", @"Connection no longer interrupted for: %@", reason);
    [self.interruptReasons removeObject:reason];

    if ([self shouldReconnect] &&
        connectionState == ConnectionStateDisconnected) {
        [self tryScheduleReconnect];
    }
}

- (BOOL)shouldReconnect {
    return self.interruptReasons.count == 0;
}

- (BOOL)isInterruptedForReason:(NSString *)reason {
    return [self.interruptReasons containsObject:reason];
}

#pragma mark -
#pragma mark Private methods

- (void)tryScheduleReconnect {
    if ([self shouldReconnect]) {
        NSAssert(self->connectionState == ConnectionStateDisconnected,
                 @"Not in disconnected state: %d", self->connectionState);
        BOOL forceRefresh = self.forceTokenRefreshes;
        self.forceTokenRefreshes = NO;
        FFLog(@"I-RDB034008", @"Scheduling connection attempt");
        [self.retryHelper retry:^{
          FFLog(@"I-RDB034009", @"Trying to fetch auth token");
          NSAssert(self->connectionState == ConnectionStateDisconnected,
                   @"Not in disconnected state: %d", self->connectionState);
          self->connectionState = ConnectionStateGettingToken;
          self.currentFetchTokenAttempt++;
          NSUInteger thisFetchTokenAttempt = self.currentFetchTokenAttempt;
          [self.contextProvider
              fetchContextForcingRefresh:forceRefresh
                            withCallback:^(
                                FIRDatabaseConnectionContext *context,
                                NSError *error) {
                              if (thisFetchTokenAttempt ==
                                  self.currentFetchTokenAttempt) {
                                  if (error != nil) {
                                      self->connectionState =
                                          ConnectionStateDisconnected;
                                      FFLog(@"I-RDB034010",
                                            @"Error fetching token: %@", error);
                                      [self tryScheduleReconnect];
                                  } else {
                                      // Someone could have interrupted us while
                                      // fetching the token, marking the
                                      // connection as Disconnected
                                      if (self->connectionState ==
                                          ConnectionStateGettingToken) {
                                          FFLog(@"I-RDB034011",
                                                @"Successfully fetched token, "
                                                @"opening connection");
                                          [self
                                              openNetworkConnectionWithContext:
                                                  context];
                                      } else {
                                          NSAssert(
                                              self->connectionState ==
                                                  ConnectionStateDisconnected,
                                              @"Expected connection state "
                                              @"disconnected, but got %d",
                                              self->connectionState);
                                          FFLog(@"I-RDB034012",
                                                @"Not opening connection after "
                                                @"token refresh, because "
                                                @"connection was set to "
                                                @"disconnected.");
                                      }
                                  }
                              } else {
                                  FFLog(@"I-RDB034013",
                                        @"Ignoring fetch token result, because "
                                        @"this was not the latest attempt.");
                              }
                            }];
        }];
    }
}

- (void)openNetworkConnectionWithContext:
    (FIRDatabaseConnectionContext *)context {
    NSAssert(self->connectionState == ConnectionStateGettingToken,
             @"Trying to open network connection while in wrong state: %d",
             self->connectionState);
    // TODO: Save entire context?
    self.authToken = context.authToken;

    self->connectionState = ConnectionStateConnecting;
    self.realtime = [[FConnection alloc] initWith:self.repoInfo
                                 andDispatchQueue:self.dispatchQueue
                                      googleAppID:self.config.googleAppID
                                    lastSessionID:self.lastSessionID
                                    appCheckToken:context.appCheckToken];
    self.realtime.delegate = self;
    [self.realtime open];
}

- (void)sendAuthAndRestoreStateAfterComplete:(BOOL)restoreStateAfterComplete {
    NSAssert([self connected], @"Must be connected to send auth");
    NSAssert(self.authToken != nil,
             @"Can't send auth if there is no credential");

    NSDictionary *requestData = @{kFWPRequestCredential : self.authToken};
    [self sendAction:kFWPRequestActionAuth
                body:requestData
           sensitive:YES
            callback:^(NSDictionary *data) {
              self->connectionState = ConnectionStateConnected;
              NSString *status =
                  [data objectForKey:kFWPResponseForActionStatus];
              id responseData = [data objectForKey:kFWPResponseForActionData];
              if (responseData == nil) {
                  responseData = @"error";
              }

              BOOL statusOk =
                  [status isEqualToString:kFWPResponseForActionStatusOk];
              if (statusOk) {
                  if (restoreStateAfterComplete) {
                      [self restoreState];
                  }
              } else {
                  self.authToken = nil;
                  self.forceTokenRefreshes = YES;
                  if ([status isEqualToString:@"expired_token"]) {
                      FFLog(@"I-RDB034017", @"Authentication failed: %@ (%@)",
                            status, responseData);
                  } else {
                      FFWarn(@"I-RDB034018", @"Authentication failed: %@ (%@)",
                             status, responseData);
                  }
                  [self.realtime close];
              }
            }];
}

- (void)sendUnauth {
    [self sendAction:kFWPRequestActionUnauth
                body:@{}
           sensitive:NO
            callback:nil];
}

- (void)onAuthRevokedWithStatus:(NSString *)status
                      andReason:(NSString *)reason {
    // This might be for an earlier token than we just recently sent. But since
    // we need to close the connection anyways, we can set it to null here and
    // we will refresh the token later on reconnect
    if ([status isEqualToString:@"expired_token"]) {
        FFLog(@"I-RDB034019", @"Auth token revoked: %@ (%@)", status, reason);
    } else {
        FFWarn(@"I-RDB034020", @"Auth token revoked: %@ (%@)", status, reason);
    }
    self.authToken = nil;
    self.forceTokenRefreshes = YES;
    // Try reconnecting on auth revocation
    [self.realtime close];
}

- (void)onListenRevoked:(FPath *)path {
    NSArray *queries = [self removeAllListensAtPath:path];
    for (FOutstandingQuery *query in queries) {
        query.onComplete(@"permission_denied");
    }
}

- (void)sendOnDisconnectAction:(NSString *)action
                       forPath:(NSString *)pathString
                      withData:(id)data
                   andCallback:(fbt_void_nsstring_nsstring)callback {

    NSDictionary *request =
        @{kFWPRequestPath : pathString, kFWPRequestData : data};
    FFLog(@"I-RDB034021", @"onDisconnect %@: %@", action, request);

    [self sendAction:action
                body:request
           sensitive:NO
            callback:^(NSDictionary *data) {
              NSString *status =
                  [data objectForKey:kFWPResponseForActionStatus];
              NSString *errorReason =
                  [data objectForKey:kFWPResponseForActionData];
              callback(status, errorReason);
            }];
}

- (void)sendPut:(NSNumber *)index {
    NSAssert([self canSendWrites],
             @"sendPut called when not able to send writes");
    FOutstandingPut *put = self.outstandingPuts[index];
    assert(put != nil);
    fbt_void_nsstring_nsstring onComplete = put.onCompleteBlock;

    // Do not async this block; copying the block insinde sendAction: doesn't
    // happen in time (or something) so coredumps
    put.sent = YES;
    [self sendAction:put.action
                body:put.request
           sensitive:NO
            callback:^(NSDictionary *data) {
              FOutstandingPut *currentPut = self.outstandingPuts[index];
              if (currentPut == put) {
                  [self.outstandingPuts removeObjectForKey:index];

                  if (onComplete != nil) {
                      NSString *status =
                          [data objectForKey:kFWPResponseForActionStatus];
                      NSString *errorReason =
                          [data objectForKey:kFWPResponseForActionData];
                      if (self.unackedListensCount == 0) {
                          onComplete(status, errorReason);
                      } else {
                          FTupleCallbackStatus *putToAck =
                              [[FTupleCallbackStatus alloc] init];
                          putToAck.block = onComplete;
                          putToAck.status = status;
                          putToAck.errorReason = errorReason;
                          [self.putsToAck addObject:putToAck];
                      }
                  }
              } else {
                  FFLog(@"I-RDB034022",
                        @"Ignoring on complete for put %@ because it was "
                        @"already removed",
                        index);
              }
            }];
}

- (void)sendGet:(NSNumber *)index {
    NSAssert([self canSendReads],
             @"sendGet called when not able to send reads");
    FOutstandingGet *get = self.outstandingGets[index];
    NSAssert(get != nil, @"sendGet found no outstanding get at index %@",
             index);
    if ([get sent]) {
        return;
    }
    get.sent = YES;
    [self sendAction:kFWPRequestActionGet
                body:get.request
           sensitive:NO
            callback:^(NSDictionary *data) {
              FOutstandingGet *currentGet = self.outstandingGets[index];
              if (currentGet == get) {
                  [self.outstandingGets removeObjectForKey:index];
                  NSString *status =
                      [data objectForKey:kFWPResponseForActionStatus];
                  id resultData = [data objectForKey:kFWPResponseForActionData];
                  if (resultData == (id)[NSNull null]) {
                      resultData = nil;
                  }
                  if ([status isEqualToString:kFWPResponseForActionStatusOk]) {
                      get.onCompleteBlock(status, resultData, nil);
                      return;
                  }
                  get.onCompleteBlock(status, nil, resultData);
              } else {
                  FFLog(@"I-RDB034045",
                        @"Ignoring on complete for get %@ because it was "
                        @"already removed",
                        index);
              }
            }];
}

- (void)sendUnlisten:(FPath *)path
         queryParams:(FQueryParams *)queryParams
               tagId:(NSNumber *)tagId {
    FFLog(@"I-RDB034023", @"Unlisten on %@ for %@", path, queryParams);

    NSMutableDictionary *request = [NSMutableDictionary
        dictionaryWithObjectsAndKeys:[path toString], kFWPRequestPath, nil];
    if (tagId != nil) {
        [request setObject:queryParams.wireProtocolParams
                    forKey:kFWPRequestQueries];
        [request setObject:tagId forKey:kFWPRequestTag];
    }

    [self sendAction:kFWPRequestActionTaggedUnlisten
                body:request
           sensitive:NO
            callback:nil];
}

- (void)putInternal:(id)data
          forAction:(NSString *)action
            forPath:(NSString *)pathString
           withHash:(NSString *)hash
       withCallback:(fbt_void_nsstring_nsstring)onComplete {

    NSMutableDictionary *request = [NSMutableDictionary
        dictionaryWithObjectsAndKeys:pathString, kFWPRequestPath, data,
                                     kFWPRequestData, nil];
    if (hash) {
        [request setObject:hash forKey:kFWPRequestHash];
    }

    FOutstandingPut *put = [[FOutstandingPut alloc] init];
    put.action = action;
    put.request = request;
    put.onCompleteBlock = onComplete;
    put.sent = NO;

    NSNumber *index = [self.putCounter getAndIncrement];
    self.outstandingPuts[index] = put;

    if ([self canSendWrites]) {
        FFLog(@"I-RDB034024", @"Was connected, and added as index: %@", index);
        [self sendPut:index];
    } else {
        FFLog(@"I-RDB034025",
              @"Wasn't connected or writes paused, so added to outstanding "
              @"puts only. Path: %@",
              pathString);
    }
}

- (void)getDataAtPath:(NSString *)pathString
           withParams:(NSDictionary *)queryWireProtocolParams
         withCallback:(fbt_void_nsstring_id_nsstring)onComplete {
    NSMutableDictionary *request = [NSMutableDictionary
        dictionaryWithObjectsAndKeys:pathString, kFWPRequestPath,
                                     queryWireProtocolParams,
                                     kFWPRequestQueries, nil];
    FOutstandingGet *get = [[FOutstandingGet alloc] init];
    get.request = request;
    get.onCompleteBlock = onComplete;
    get.sent = NO;

    NSNumber *index = [self.getCounter getAndIncrement];
    self.outstandingGets[index] = get;

    if (![self connected]) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          kPersistentConnectionGetConnectTimeout),
            self.dispatchQueue, ^{
              FOutstandingGet *currGet = self.outstandingGets[index];
              if ([currGet sent] || currGet == nil) {
                  return;
              }
              FFLog(@"I-RDB034045",
                    @"get %@ timed out waiting for a connection", index);
              currGet.sent = YES;
              currGet.onCompleteBlock(kFWPResponseForActionStatusFailed, nil,
                                      kPersistentConnectionOffline);
              [self.outstandingGets removeObjectForKey:index];
            });
        return;
    }

    if ([self canSendReads]) {
        FFLog(@"I-RDB034024", @"Sending get: %@", index);
        [self sendGet:index];
    }
}

- (void)sendListen:(FOutstandingQuery *)listenSpec {
    FQuerySpec *query = listenSpec.query;
    FFLog(@"I-RDB034026", @"Listen for %@", query);
    NSMutableDictionary *request =
        [NSMutableDictionary dictionaryWithObject:[query.path toString]
                                           forKey:kFWPRequestPath];

    // Only bother to send query if it's non-default
    if (listenSpec.tagId != nil) {
        [request setObject:[query.params wireProtocolParams]
                    forKey:kFWPRequestQueries];
        [request setObject:listenSpec.tagId forKey:kFWPRequestTag];
    }

    [request setObject:[listenSpec.syncTreeHash simpleHash]
                forKey:kFWPRequestHash];
    if ([listenSpec.syncTreeHash includeCompoundHash]) {
        FCompoundHash *compoundHash = [listenSpec.syncTreeHash compoundHash];
        NSMutableArray *posts = [NSMutableArray array];
        for (FPath *path in compoundHash.posts) {
            [posts addObject:path.wireFormat];
        }
        request[kFWPRequestCompoundHash] = @{
            kFWPRequestCompoundHashHashes : compoundHash.hashes,
            kFWPRequestCompoundHashPaths : posts
        };
    }

    fbt_void_nsdictionary onResponse = ^(NSDictionary *response) {
      FFLog(@"I-RDB034027", @"Listen response %@", response);
      // warn in any case, even if the listener was removed
      [self warnOnListenWarningsForQuery:query
                                 payload:response[kFWPResponseForActionData]];

      FOutstandingQuery *currentListenSpec = self.listens[query];

      // only trigger actions if the listen hasn't been removed (and maybe
      // readded)
      if (currentListenSpec == listenSpec) {
          NSString *status = [response objectForKey:kFWPRequestStatus];
          if (![status isEqualToString:@"ok"]) {
              [self removeListen:query];
          }

          if (listenSpec.onComplete) {
              listenSpec.onComplete(status);
          }
      }

      self.unackedListensCount--;
      NSAssert(self.unackedListensCount >= 0,
               @"unackedListensCount decremented to be negative.");
      if (self.unackedListensCount == 0) {
          [self ackPuts];
      }
    };

    [self sendAction:kFWPRequestActionTaggedListen
                body:request
           sensitive:NO
            callback:onResponse];

    self.unackedListensCount++;
}

- (void)warnOnListenWarningsForQuery:(FQuerySpec *)query payload:(id)payload {
    if (payload != nil && [payload isKindOfClass:[NSDictionary class]]) {
        NSDictionary *payloadDict = payload;
        id warnings = payloadDict[kFWPResponseDataWarnings];
        if (warnings != nil && [warnings isKindOfClass:[NSArray class]]) {
            NSArray *warningsArr = warnings;
            if ([warningsArr containsObject:@"no_index"]) {
                NSString *indexSpec = [NSString
                    stringWithFormat:@"\".indexOn\": \"%@\"",
                                     [query.params.index queryDefinition]];
                NSString *indexPath = [query.path description];
                FFWarn(@"I-RDB034028",
                       @"Using an unspecified index. Your data will be "
                       @"downloaded and filtered on the client. "
                        "Consider adding %@ at %@ to your security rules for "
                        "better performance",
                       indexSpec, indexPath);
            }
        }
    }
}

- (int)getNextRequestNumber {
    return [[self.requestNumber getAndIncrement] intValue];
}

- (void)sendAction:(NSString *)action
              body:(NSDictionary *)message
         sensitive:(BOOL)sensitive
          callback:(void (^)(NSDictionary *data))onMessage {
    // Hold onto the onMessage callback for this request before firing it off
    NSNumber *rn = [NSNumber numberWithInt:[self getNextRequestNumber]];
    NSDictionary *msg = [NSDictionary
        dictionaryWithObjectsAndKeys:rn, kFWPRequestNumber, action,
                                     kFWPRequestAction, message,
                                     kFWPRequestPayloadBody, nil];

    [self.realtime sendRequest:msg sensitive:sensitive];

    if (onMessage) {
        // Debug message without a callback; bump the rn, but don't hold onto
        // the cb
        [self.requestCBHash setObject:[onMessage copy] forKey:rn];
    }
}

- (void)cancelSentTransactions {
    NSMutableDictionary<NSNumber *, FOutstandingPut *>
        *cancelledOutstandingPuts = [[NSMutableDictionary alloc] init];

    for (NSNumber *index in self.outstandingPuts) {
        FOutstandingPut *put = self.outstandingPuts[index];
        if (put.request[kFWPRequestHash] && put.sent) {
            // This is a sent transaction put.
            cancelledOutstandingPuts[index] = put;
        }
    }

    [cancelledOutstandingPuts
        enumerateKeysAndObjectsUsingBlock:^(
            NSNumber *index, FOutstandingPut *outstandingPut, BOOL *stop) {
          // `onCompleteBlock:` may invoke `rerunTransactionsForPath:` and
          // enqueue new writes. We defer calling it until we have finished
          // enumerating all existing writes.
          outstandingPut.onCompleteBlock(
              kFTransactionDisconnect,
              @"Client was disconnected while running a transaction");
          [self.outstandingPuts removeObjectForKey:index];
        }];
}

- (void)onDataPushWithAction:(NSString *)action andBody:(NSDictionary *)body {
    FFLog(@"I-RDB034029", @"handleServerMessage: %@, %@", action, body);
    id<FPersistentConnectionDelegate> delegate = self.delegate;
    if ([action isEqualToString:kFWPAsyncServerDataUpdate] ||
        [action isEqualToString:kFWPAsyncServerDataMerge]) {
        BOOL isMerge = [action isEqualToString:kFWPAsyncServerDataMerge];

        if ([body objectForKey:kFWPAsyncServerDataUpdateBodyPath] &&
            [body objectForKey:kFWPAsyncServerDataUpdateBodyData]) {
            NSString *path =
                [body objectForKey:kFWPAsyncServerDataUpdateBodyPath];
            id payloadData =
                [body objectForKey:kFWPAsyncServerDataUpdateBodyData];
            if (isMerge && [payloadData isKindOfClass:[NSDictionary class]] &&
                [payloadData count] == 0) {
                // ignore empty merge
            } else {
                [delegate
                    onDataUpdate:self
                         forPath:path
                         message:payloadData
                         isMerge:isMerge
                           tagId:[body objectForKey:
                                           kFWPAsyncServerDataUpdateBodyTag]];
            }
        } else {
            FFLog(
                @"I-RDB034030",
                @"Malformed data response from server missing path or data: %@",
                body);
        }
    } else if ([action isEqualToString:kFWPAsyncServerDataRangeMerge]) {
        NSString *path = body[kFWPAsyncServerDataUpdateBodyPath];
        NSArray *ranges = body[kFWPAsyncServerDataUpdateBodyData];
        NSNumber *tag = body[kFWPAsyncServerDataUpdateBodyTag];
        NSMutableArray *rangeMerges = [NSMutableArray array];
        for (NSDictionary *range in ranges) {
            NSString *startString = range[kFWPAsyncServerDataUpdateStartPath];
            NSString *endString = range[kFWPAsyncServerDataUpdateEndPath];
            id updateData = range[kFWPAsyncServerDataUpdateRangeMerge];
            id<FNode> updates = [FSnapshotUtilities nodeFrom:updateData];
            FPath *start = (startString != nil)
                               ? [[FPath alloc] initWith:startString]
                               : nil;
            FPath *end =
                (endString != nil) ? [[FPath alloc] initWith:endString] : nil;
            FRangeMerge *merge = [[FRangeMerge alloc] initWithStart:start
                                                                end:end
                                                            updates:updates];
            [rangeMerges addObject:merge];
        }
        [delegate onRangeMerge:rangeMerges forPath:path tagId:tag];
    } else if ([action isEqualToString:kFWPAsyncServerAuthRevoked]) {
        NSString *status = [body objectForKey:kFWPResponseForActionStatus];
        NSString *reason = [body objectForKey:kFWPResponseForActionData];
        [self onAuthRevokedWithStatus:status andReason:reason];
    } else if ([action isEqualToString:kFWPASyncServerListenCancelled]) {
        NSString *pathString =
            [body objectForKey:kFWPAsyncServerDataUpdateBodyPath];
        [self onListenRevoked:[[FPath alloc] initWith:pathString]];
    } else if ([action isEqualToString:kFWPAsyncServerSecurityDebug]) {
        NSString *msg = [body objectForKey:@"msg"];
        if (msg != nil) {
            NSArray *msgs = [msg componentsSeparatedByString:@"\n"];
            for (NSString *m in msgs) {
                FFWarn(@"I-RDB034031", @"%@", m);
            }
        }
    } else {
        // TODO: revoke listens, auth, security debug
        FFLog(@"I-RDB034032", @"Unsupported action from server: %@", action);
    }
}

- (void)restoreAuth {
    FFLog(@"I-RDB034033", @"Calling restore state");

    NSAssert(self->connectionState == ConnectionStateConnecting,
             @"Wanted to restore auth, but was in wrong state: %d",
             self->connectionState);
    if (self.authToken == nil) {
        FFLog(@"I-RDB034034", @"Not restoring auth because token is nil");
        self->connectionState = ConnectionStateConnected;
        [self restoreState];
    } else {
        FFLog(@"I-RDB034035", @"Restoring auth");
        self->connectionState = ConnectionStateAuthenticating;
        [self sendAuthAndRestoreStateAfterComplete:YES];
    }
}

- (void)restoreState {
    NSAssert(self->connectionState == ConnectionStateConnected,
             @"Should be connected if we're restoring state, but we are: %d",
             self->connectionState);

    [self.listens enumerateKeysAndObjectsUsingBlock:^(
                      FQuerySpec *query, FOutstandingQuery *outstandingListen,
                      BOOL *stop) {
      FFLog(@"I-RDB034036", @"Restoring listen for %@", query);
      [self sendListen:outstandingListen];
    }];

    NSArray *putKeys = [[self.outstandingPuts allKeys]
        sortedArrayUsingSelector:@selector(compare:)];
    for (int i = 0; i < [putKeys count]; i++) {
        if ([self.outstandingPuts objectForKey:[putKeys objectAtIndex:i]] !=
            nil) {
            FFLog(@"I-RDB034037", @"Restoring put: %d", i);
            [self sendPut:[putKeys objectAtIndex:i]];
        } else {
            FFLog(@"I-RDB034038", @"Restoring put: skipped nil: %d", i);
        }
    }

    NSArray *getKeys = [[self.outstandingGets allKeys]
        sortedArrayUsingSelector:@selector(compare:)];
    for (int i = 0; i < [getKeys count]; i++) {
        if ([self.outstandingGets objectForKey:[getKeys objectAtIndex:i]] !=
            nil) {
            FFLog(@"I-RDB034037", @"Restoring get: %d", i);
            [self sendGet:[getKeys objectAtIndex:i]];
        } else {
            FFLog(@"I-RDB034038", @"Restoring get: skipped nil: %d", i);
        }
    }

    for (FTupleOnDisconnect *tuple in self.onDisconnectQueue) {
        [self sendOnDisconnectAction:tuple.action
                             forPath:tuple.pathString
                            withData:tuple.data
                         andCallback:tuple.onComplete];
    }
    [self.onDisconnectQueue removeAllObjects];
}

- (NSArray *)removeListen:(FQuerySpec *)query {
    NSAssert(query.isDefault || !query.loadsAllData,
             @"removeListen called for non-default but complete query");

    FOutstandingQuery *outstanding = self.listens[query];
    if (!outstanding) {
        FFLog(@"I-RDB034039",
              @"Trying to remove listener for query %@ but no listener exists",
              query);
        return @[];
    } else {
        [self.listens removeObjectForKey:query];
        return @[ outstanding ];
    }
}

- (NSArray *)removeAllListensAtPath:(FPath *)path {
    FFLog(@"I-RDB034040", @"Removing all listens at path %@", path);
    NSMutableArray *removed = [NSMutableArray array];
    NSMutableArray *toRemove = [NSMutableArray array];
    [self.listens
        enumerateKeysAndObjectsUsingBlock:^(
            FQuerySpec *spec, FOutstandingQuery *outstanding, BOOL *stop) {
          if ([spec.path isEqual:path]) {
              [removed addObject:outstanding];
              [toRemove addObject:spec];
          }
        }];
    [self.listens removeObjectsForKeys:toRemove];
    return removed;
}

- (void)purgeOutstandingWrites {
    // We might have unacked puts in our queue that we need to ack now before we
    // send out any cancels...
    [self ackPuts];
    // Cancel in order
    NSArray *keys = [[self.outstandingPuts allKeys]
        sortedArrayUsingSelector:@selector(compare:)];
    for (NSNumber *key in keys) {
        FOutstandingPut *put = self.outstandingPuts[key];
        if (put.onCompleteBlock != nil) {
            put.onCompleteBlock(kFErrorWriteCanceled, nil);
        }
    }
    for (FTupleOnDisconnect *onDisconnect in self.onDisconnectQueue) {
        if (onDisconnect.onComplete != nil) {
            onDisconnect.onComplete(kFErrorWriteCanceled, nil);
        }
    }
    [self.outstandingPuts removeAllObjects];
    [self.onDisconnectQueue removeAllObjects];
}

- (void)ackPuts {
    for (FTupleCallbackStatus *put in self.putsToAck) {
        put.block(put.status, put.errorReason);
    }
    [self.putsToAck removeAllObjects];
}

- (void)handleTimestamp:(NSNumber *)timestamp {
    FFLog(@"I-RDB034041", @"Handling timestamp: %@", timestamp);
    double timestampDeltaMs = [timestamp doubleValue] -
                              ([[NSDate date] timeIntervalSince1970] * 1000);
    [self.delegate onServerInfoUpdate:self
                              updates:@{
                                  kDotInfoServerTimeOffset : [NSNumber
                                      numberWithDouble:timestampDeltaMs]
                              }];
}

- (void)sendStats:(NSDictionary *)stats {
    if ([stats count] > 0) {
        NSDictionary *request = @{kFWPRequestCounters : stats};
        [self sendAction:kFWPRequestActionStats
                    body:request
               sensitive:NO
                callback:^(NSDictionary *data) {
                  NSString *status =
                      [data objectForKey:kFWPResponseForActionStatus];
                  NSString *errorReason =
                      [data objectForKey:kFWPResponseForActionData];
                  BOOL statusOk =
                      [status isEqualToString:kFWPResponseForActionStatusOk];
                  if (!statusOk) {
                      FFLog(@"I-RDB034042", @"Failed to send stats: %@",
                            errorReason);
                  }
                }];
    } else {
        FFLog(@"I-RDB034043", @"Not sending stats because stats are empty");
    }
}

- (void)sendConnectStats {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
    if (self.config.persistenceEnabled) {
        stats[@"persistence.ios.enabled"] = @1;
    }
#elif TARGET_OS_OSX
    if (self.config.persistenceEnabled) {
        stats[@"persistence.osx.enabled"] = @1;
    }
#elif TARGET_OS_WATCH
    if (self.config.persistenceEnabled) {
        stats[@"persistence.watchos.enabled"] = @1;
    }
#endif
    NSString *sdkVersion =
        [[FIRDatabase sdkVersion] stringByReplacingOccurrencesOfString:@"."
                                                            withString:@"-"];
    NSString *sdkStatName =
        [NSString stringWithFormat:@"sdk.objc.%@", sdkVersion];
    stats[sdkStatName] = @1;
    FFLog(@"I-RDB034044", @"Sending first connection stats");
    [self sendStats:stats];
}

- (NSDictionary *)dumpListens {
    return self.listens;
}

#pragma mark - App Check Token update

// TODO: Add tests!
- (void)refreshAppCheckToken:(NSString *)token {
    if (![self connected]) {
        // A fresh FAC token will be sent as a part of initial handshake.
        return;
    }

    if (token.length == 0) {
        // No token to send.
        return;
    }

    // Send updated FAC token to the open connection.
    [self sendAppCheckToken:token];
}

- (void)sendAppCheckToken:(NSString *)token {
    NSDictionary *requestData = @{kFWPRequestAppCheckToken : token};
    [self sendAction:kFWPRequestActionAppCheck
                body:requestData
           sensitive:YES
            callback:^(NSDictionary *data) {
              NSString *status =
                  [data objectForKey:kFWPResponseForActionStatus];
              id responseData = [data objectForKey:kFWPResponseForActionData];
              if (responseData == nil) {
                  responseData = @"Response data was empty.";
              }

              BOOL statusOk =
                  [status isEqualToString:kFWPResponseForActionStatusOk];
              if (!statusOk) {
                  self.authToken = nil;
                  self.forceTokenRefreshes = YES;
                  if ([status isEqualToString:@"invalid_token"]) {
                      FFLog(@"I-RDB034045", @"App check failed: %@ (%@)",
                            status, responseData);
                  } else {
                      FFWarn(@"I-RDB034046", @"App check failed: %@ (%@)",
                             status, responseData);
                  }
                  [self.realtime close];
              }
            }];
}

@end
