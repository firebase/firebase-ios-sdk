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

#import "Firestore/Source/Remote/FSTDatastore.h"

#import <GRPCClient/GRPCCall+OAuth2.h>
#import <GRPCClient/GRPCCall.h>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Auth/FSTCredentialsProvider.h"
#import "Firestore/Source/Core/FSTDatabaseInfo.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTBufferedWriter.h"
#import "Firestore/Source/Remote/FSTExponentialBackoff.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"
#import "Firestore/Source/Util/FSTLogger.h"

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbrpc.h"

/**
 * Initial backoff time in seconds after an error.
 * Set to 1s according to https://cloud.google.com/apis/design/errors.
 */
static const NSTimeInterval kBackoffInitialDelay = 1;
static const NSTimeInterval kBackoffMaxDelay = 60.0;
static const double kBackoffFactor = 1.5;

#pragma mark - FSTStream

/** The state of a stream. */
typedef NS_ENUM(NSInteger, FSTStreamState) {
  /**
   * The streaming RPC is not running and there's no error condition. Calling `start` will
   * start the stream immediately without backoff. While in this state -isStarted will return NO.
   */
  FSTStreamStateInitial = 0,

  /**
   * The stream is starting, and is waiting for an auth token to attach to the initial request.
   * While in this state, isStarted will return YES but isOpen will return NO.
   */
  FSTStreamStateAuth,

  /**
   * The streaming RPC is up and running. Requests and responses can flow freely. Both
   * isStarted and isOpen will return YES.
   */
  FSTStreamStateOpen,

  /**
   * The stream encountered an error. The next start attempt will back off. While in this state
   * -isStarted will return NO.
   */
  FSTStreamStateError,

  /**
   * An in-between state after an error where the stream is waiting before re-starting. After
   * waiting is complete, the stream will try to open. While in this state -isStarted will
   * return YES but isOpen will return NO.
   */
  FSTStreamStateBackoff,

  /**
   * The stream has been explicitly stopped; no further events will be emitted.
   */
  FSTStreamStateStopped,
};

// We need to declare these classes first so that Datastore can alloc them.

@interface FSTWatchStream ()

/**
 * Initializes the watch stream with its dependencies.
 */
- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                      serializer:(FSTSerializerBeta *)serializer NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
            responseMessageClass:(Class)responseMessageClass NS_UNAVAILABLE;

@end

@interface FSTStream ()

@property(nonatomic, getter=isIdle) BOOL idle;
@property(nonatomic, weak, readwrite, nullable) id delegate;

@end

@interface FSTStream () <GRXWriteable>

@property(nonatomic, strong, readonly) FSTDatabaseInfo *databaseInfo;
@property(nonatomic, strong, readonly) FSTDispatchQueue *workerDispatchQueue;
@property(nonatomic, strong, readonly) id<FSTCredentialsProvider> credentials;
@property(nonatomic, unsafe_unretained, readonly) Class responseMessageClass;
@property(nonatomic, strong, readonly) FSTExponentialBackoff *backoff;

/** A flag tracking whether the stream received a message from the backend. */
@property(nonatomic, assign) BOOL messageReceived;

/**
 * Stream state as exposed to consumers of FSTStream. This differs from GRXWriter's notion of the
 * state of the stream.
 */
@property(nonatomic, assign) FSTStreamState state;

/** The RPC handle. Used for cancellation. */
@property(nonatomic, strong, nullable) GRPCCall *rpc;

/**
 * The send-side of the RPC stream in which to submit requests, but only once the underlying RPC has
 * started.
 */
@property(nonatomic, strong, nullable) FSTBufferedWriter *requestsWriter;

@end

#pragma mark - FSTCallbackFilter

/** Filter class that allows disabling of GRPC callbacks. */
@interface FSTCallbackFilter : NSObject <GRXWriteable>

- (instancetype)initWithStream:(FSTStream *)stream NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(atomic, readwrite) BOOL callbacksEnabled;
@property(nonatomic, strong, readonly) FSTStream *stream;

@end

@implementation FSTCallbackFilter

- (instancetype)initWithStream:(FSTStream *)stream {
  if (self = [super init]) {
    _callbacksEnabled = YES;
    _stream = stream;
  }
  return self;
}

- (void)suppressCallbacks {
  _callbacksEnabled = NO;
}

- (void)writeValue:(id)value {
  if (_callbacksEnabled) {
    [self.stream writeValue:value];
  }
}

- (void)writesFinishedWithError:(NSError *)errorOrNil {
  if (_callbacksEnabled) {
    [self.stream writesFinishedWithError:errorOrNil];
  }
}

@end

#pragma mark - FSTStream

@interface FSTStream ()

@property(nonatomic, strong, readwrite) FSTCallbackFilter *callbackFilter;

@end

@implementation FSTStream

/** The time a stream stays open after it is marked idle. */
static const NSTimeInterval kIdleTimeout = 60.0;

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
            responseMessageClass:(Class)responseMessageClass {
  if (self = [super init]) {
    _databaseInfo = database;
    _workerDispatchQueue = workerDispatchQueue;
    _credentials = credentials;
    _responseMessageClass = responseMessageClass;

    _backoff = [FSTExponentialBackoff exponentialBackoffWithDispatchQueue:workerDispatchQueue
                                                             initialDelay:kBackoffInitialDelay
                                                            backoffFactor:kBackoffFactor
                                                                 maxDelay:kBackoffMaxDelay];
    _state = FSTStreamStateInitial;
  }
  return self;
}

- (BOOL)isStarted {
  [self.workerDispatchQueue verifyIsCurrentQueue];
  FSTStreamState state = self.state;
  return state == FSTStreamStateBackoff || state == FSTStreamStateAuth ||
         state == FSTStreamStateOpen;
}

- (BOOL)isOpen {
  [self.workerDispatchQueue verifyIsCurrentQueue];
  return self.state == FSTStreamStateOpen;
}

- (GRPCCall *)createRPCWithRequestsWriter:(GRXWriter *)requestsWriter {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)startWithDelegate:(id)delegate {
  [self.workerDispatchQueue verifyIsCurrentQueue];

  if (self.state == FSTStreamStateError) {
    [self performBackoffWithDelegate:delegate];
    return;
  }

  FSTLog(@"%@ %p start", NSStringFromClass([self class]), (__bridge void *)self);
  FSTAssert(self.state == FSTStreamStateInitial, @"Already started");

  self.state = FSTStreamStateAuth;
  FSTAssert(_delegate == nil, @"Delegate must be nil");
  _delegate = delegate;

  [self.credentials
      getTokenForcingRefresh:NO
                  completion:^(FSTGetTokenResult *_Nullable result, NSError *_Nullable error) {
                    error = [FSTDatastore firestoreErrorForError:error];
                    [self.workerDispatchQueue dispatchAsyncAllowingSameQueue:^{
                      [self resumeStartWithToken:result error:error];
                    }];
                  }];
}

/** Add an access token to our RPC, after obtaining one from the credentials provider. */
- (void)resumeStartWithToken:(FSTGetTokenResult *)token error:(NSError *)error {
  if (self.state == FSTStreamStateStopped) {
    // Streams can be stopped while waiting for authorization.
    return;
  }

  [self.workerDispatchQueue verifyIsCurrentQueue];
  FSTAssert(self.state == FSTStreamStateAuth, @"State should still be auth (was %ld)",
            (long)self.state);

  // TODO(mikelehen): We should force a refresh if the previous RPC failed due to an expired token,
  // but I'm not sure how to detect that right now. http://b/32762461
  if (error) {
    // RPC has not been started yet, so just invoke higher-level close handler.
    [self handleStreamClose:error];
    return;
  }

  self.requestsWriter = [[FSTBufferedWriter alloc] init];
  _rpc = [self createRPCWithRequestsWriter:self.requestsWriter];
  [FSTDatastore prepareHeadersForRPC:_rpc
                          databaseID:self.databaseInfo.databaseID
                               token:token.token];
  FSTAssert(_callbackFilter == nil, @"GRX Filter must be nil");
  _callbackFilter = [[FSTCallbackFilter alloc] initWithStream:self];
  [_rpc startWithWriteable:_callbackFilter];

  self.state = FSTStreamStateOpen;
  [self notifyStreamOpen];
}

/** Backs off after an error. */
- (void)performBackoffWithDelegate:(id)delegate {
  FSTLog(@"%@ %p backoff", NSStringFromClass([self class]), (__bridge void *)self);
  [self.workerDispatchQueue verifyIsCurrentQueue];

  FSTAssert(self.state == FSTStreamStateError, @"Should only perform backoff in an error case");
  self.state = FSTStreamStateBackoff;

  FSTWeakify(self);
  [self.backoff backoffAndRunBlock:^{
    FSTStrongify(self);
    [self resumeStartFromBackoffWithDelegate:delegate];
  }];
}

/** Resumes stream start after backing off. */
- (void)resumeStartFromBackoffWithDelegate:(id)delegate {
  if (self.state == FSTStreamStateStopped) {
    // Streams can be stopped while waiting for backoff to complete.
    return;
  }

  // In order to have performed a backoff the stream must have been in an error state just prior
  // to entering the backoff state. If we weren't stopped we must be in the backoff state.
  FSTAssert(self.state == FSTStreamStateBackoff, @"State should still be backoff (was %ld)",
            (long)self.state);

  // Momentarily set state to FSTStreamStateInitial as `start` expects it.
  self.state = FSTStreamStateInitial;
  [self startWithDelegate:delegate];
  FSTAssert([self isStarted], @"Stream should have started.");
}

/**
 * Can be overridden to perform additional cleanup before the stream is closed. Calling
 * [super tearDown] is not required.
 */
- (void)tearDown {
}

/**
 * Closes the stream and cleans up as necessary:
 *
 * * closes the underlying GRPC stream;
 * * calls the onClose handler with the given 'error';
 * * sets internal stream state to 'finalState';
 * * adjusts the backoff timer based on the error
 *
 * A new stream can be opened by calling `start` unless `finalState` is set to
 * `FSTStreamStateStopped`.
 *
 * @param finalState the intended state of the stream after closing.
 * @param error the NSError the connection was closed with.
 */
- (void)closeWithFinalState:(FSTStreamState)finalState error:(nullable NSError *)error {
  FSTAssert(finalState == FSTStreamStateError || error == nil,
            @"Can't provide an error when not in an error state.");
  FSTAssert(self.delegate,
            @"closeWithFinalState should only be called for a started stream that has an active "
            @"delegate.");

  [self.workerDispatchQueue verifyIsCurrentQueue];
  [self cancelIdleCheck];

  if (finalState != FSTStreamStateError) {
    // If this is an intentional close ensure we don't delay our next connection attempt.
    [self.backoff reset];
  } else if (error != nil && error.code == FIRFirestoreErrorCodeResourceExhausted) {
    FSTLog(@"%@ %p Using maximum backoff delay to prevent overloading the backend.", [self class],
           (__bridge void *)self);
    [self.backoff resetToMax];
  }

  [self tearDown];

  if (self.requestsWriter) {
    // Clean up the underlying RPC. If this close: is in response to an error, don't attempt to
    // call half-close to avoid secondary failures.
    if (finalState != FSTStreamStateError) {
      FSTLog(@"%@ %p Closing stream client-side", [self class], (__bridge void *)self);
      @synchronized(self.requestsWriter) {
        [self.requestsWriter finishWithError:nil];
      }
    }
    _requestsWriter = nil;
  }

  // This state must be assigned before calling `notifyStreamInterrupted` to allow the callback to
  // inhibit backoff or otherwise manipulate the state in its non-started state.
  self.state = finalState;

  [self.callbackFilter suppressCallbacks];
  _callbackFilter = nil;

  // Clean up remaining state.
  _messageReceived = NO;
  _rpc = nil;

  // If the caller explicitly requested a stream stop, don't notify them of a closing stream (it
  // could trigger undesirable recovery logic, etc.).
  if (finalState != FSTStreamStateStopped) {
    [self notifyStreamInterruptedWithError:error];
  }

  // Clear the delegates to avoid any possible bleed through of events from GRPC.
  _delegate = nil;
}

- (void)stop {
  FSTLog(@"%@ %p stop", NSStringFromClass([self class]), (__bridge void *)self);
  if ([self isStarted]) {
    [self closeWithFinalState:FSTStreamStateStopped error:nil];
  }
}

- (void)inhibitBackoff {
  FSTAssert(![self isStarted], @"Can only inhibit backoff after an error (was %ld)",
            (long)self.state);
  [self.workerDispatchQueue verifyIsCurrentQueue];

  // Clear the error condition.
  self.state = FSTStreamStateInitial;
  [self.backoff reset];
}

/** Called by the idle timer when the stream should close due to inactivity. */
- (void)handleIdleCloseTimer {
  [self.workerDispatchQueue verifyIsCurrentQueue];
  if (self.state == FSTStreamStateOpen && [self isIdle]) {
    // When timing out an idle stream there's no reason to force the stream into backoff when
    // it restarts so set the stream state to Initial instead of Error.
    [self closeWithFinalState:FSTStreamStateInitial error:nil];
  }
}

- (void)markIdle {
  [self.workerDispatchQueue verifyIsCurrentQueue];
  if (self.state == FSTStreamStateOpen) {
    self.idle = YES;
    [self.workerDispatchQueue dispatchAfterDelay:kIdleTimeout
                                           block:^() {
                                             [self handleIdleCloseTimer];
                                           }];
  }
}

- (void)cancelIdleCheck {
  [self.workerDispatchQueue verifyIsCurrentQueue];
  self.idle = NO;
}

/**
 * Parses a protocol buffer response from the server. If the message fails to parse, generates
 * an error and closes the stream.
 *
 * @param protoClass A protocol buffer message class object, that responds to parseFromData:error:.
 * @param data The bytes in the response as returned from GRPC.
 * @return An instance of the protocol buffer message, parsed from the data if parsing was
 *     successful, or nil otherwise.
 */
- (nullable id)parseProto:(Class)protoClass data:(NSData *)data error:(NSError **)error {
  NSError *parseError;
  id parsed = [protoClass parseFromData:data error:&parseError];
  if (parsed) {
    *error = nil;
    return parsed;
  } else {
    NSDictionary *info = @{
      NSLocalizedDescriptionKey : @"Unable to parse response from the server",
      NSUnderlyingErrorKey : parseError,
      @"Expected class" : protoClass,
      @"Received value" : data,
    };
    *error = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                 code:FIRFirestoreErrorCodeInternal
                             userInfo:info];
    return nil;
  }
}

/**
 * Writes a request proto into the stream.
 */
- (void)writeRequest:(GPBMessage *)request {
  NSData *data = [request data];

  [self cancelIdleCheck];

  FSTBufferedWriter *requestsWriter = self.requestsWriter;
  @synchronized(requestsWriter) {
    [requestsWriter writeValue:data];
  }
}

#pragma mark Template methods for subclasses

/**
 * Called by the stream after the stream has opened.
 *
 * Subclasses should relay to their stream-specific delegate. Calling [super notifyStreamOpen] is
 * not required.
 */
- (void)notifyStreamOpen {
}

/**
 * Called by the stream after the stream has been unexpectedly interrupted, either due to an error
 * or due to idleness.
 *
 * Subclasses should relay to their stream-specific delegate. Calling [super
 * notifyStreamInterrupted] is not required.
 */
- (void)notifyStreamInterruptedWithError:(nullable NSError *)error {
}

/**
 * Called by the stream for each incoming protocol message coming from the server.
 *
 * Subclasses should implement this to deserialize the value and relay to their stream-specific
 * delegate, if appropriate. Calling [super handleStreamMessage] is not required.
 */
- (void)handleStreamMessage:(id)value {
}

/**
 * Called by the stream when the underlying RPC has been closed for whatever reason.
 */
- (void)handleStreamClose:(nullable NSError *)error {
  FSTLog(@"%@ %p close: %@", NSStringFromClass([self class]), (__bridge void *)self, error);

  if (![self isStarted]) {  // The stream could have already been closed by the idle close timer.
    FSTLog(@"%@ Ignoring server close for already closed stream.", NSStringFromClass([self class]));
    return;
  }

  // In theory the stream could close cleanly, however, in our current model we never expect this
  // to happen because if we stop a stream ourselves, this callback will never be called. To
  // prevent cases where we retry without a backoff accidentally, we set the stream to error
  // in all cases.
  [self closeWithFinalState:FSTStreamStateError error:error];
}

#pragma mark GRXWriteable implementation
// The GRXWriteable implementation defines the receive side of the RPC stream.

/**
 * Called by GRPC when it publishes a value. It is called from GRPC's own queue so we immediately
 * redispatch back onto our own worker queue.
 */
- (void)writeValue:(id)value __used {
  // TODO(mcg): remove the double-dispatch once GRPCCall at head is released.
  // Once released we can set the responseDispatchQueue property on the GRPCCall and then this
  // method can call handleStreamMessage directly.
  FSTWeakify(self);
  [self.workerDispatchQueue dispatchAsync:^{
    FSTStrongify(self);
    if (![self isStarted]) {
      FSTLog(@"%@ Ignoring stream message from inactive stream.", NSStringFromClass([self class]));
    }

    if (!self.messageReceived) {
      self.messageReceived = YES;
      if ([FIRFirestore isLoggingEnabled]) {
        FSTLog(@"%@ %p headers (whitelisted): %@", NSStringFromClass([self class]),
               (__bridge void *)self,
               [FSTDatastore extractWhiteListedHeaders:self.rpc.responseHeaders]);
      }
    }
    NSError *error;
    id proto = [self parseProto:self.responseMessageClass data:value error:&error];
    if (proto) {
      [self handleStreamMessage:proto];
    } else {
      [_rpc finishWithError:error];
    }
  }];
}

/**
 * Called by GRPC when it closed the stream with an error representing the final state of the
 * stream.
 *
 * Do not call directly, since it dispatches via the worker queue. Call handleStreamClose to
 * directly inform stream-specific logic, or call stop to tear down the stream.
 */
- (void)writesFinishedWithError:(nullable NSError *)error __used {
  error = [FSTDatastore firestoreErrorForError:error];
  FSTWeakify(self);
  [self.workerDispatchQueue dispatchAsync:^{
    FSTStrongify(self);
    if (!self || self.state == FSTStreamStateStopped) {
      return;
    }
    [self handleStreamClose:error];
  }];
}

@end

#pragma mark - FSTWatchStream

@interface FSTWatchStream ()

@property(nonatomic, strong, readonly) FSTSerializerBeta *serializer;

@end

@implementation FSTWatchStream

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                      serializer:(FSTSerializerBeta *)serializer {
  self = [super initWithDatabase:database
             workerDispatchQueue:workerDispatchQueue
                     credentials:credentials
            responseMessageClass:[GCFSListenResponse class]];
  if (self) {
    _serializer = serializer;
  }
  return self;
}

- (GRPCCall *)createRPCWithRequestsWriter:(GRXWriter *)requestsWriter {
  return [[GRPCCall alloc] initWithHost:self.databaseInfo.host
                                   path:@"/google.firestore.v1beta1.Firestore/Listen"
                         requestsWriter:requestsWriter];
}

- (void)notifyStreamOpen {
  [self.delegate watchStreamDidOpen];
}

- (void)notifyStreamInterruptedWithError:(nullable NSError *)error {
  id<FSTWatchStreamDelegate> delegate = self.delegate;
  self.delegate = nil;
  [delegate watchStreamWasInterruptedWithError:error];
}

- (void)watchQuery:(FSTQueryData *)query {
  FSTAssert([self isOpen], @"Not yet open");
  [self.workerDispatchQueue verifyIsCurrentQueue];

  GCFSListenRequest *request = [GCFSListenRequest message];
  request.database = [_serializer encodedDatabaseID];
  request.addTarget = [_serializer encodedTarget:query];
  request.labels = [_serializer encodedListenRequestLabelsForQueryData:query];

  FSTLog(@"FSTWatchStream %p watch: %@", (__bridge void *)self, request);
  [self writeRequest:request];
}

- (void)unwatchTargetID:(FSTTargetID)targetID {
  FSTAssert([self isOpen], @"Not yet open");
  [self.workerDispatchQueue verifyIsCurrentQueue];

  GCFSListenRequest *request = [GCFSListenRequest message];
  request.database = [_serializer encodedDatabaseID];
  request.removeTarget = targetID;

  FSTLog(@"FSTWatchStream %p unwatch: %@", (__bridge void *)self, request);
  [self writeRequest:request];
}

/**
 * Receives an inbound message from GRPC, deserializes, and then passes that on to the delegate's
 * watchStreamDidChange:snapshotVersion: callback.
 */
- (void)handleStreamMessage:(GCFSListenResponse *)proto {
  FSTLog(@"FSTWatchStream %p response: %@", (__bridge void *)self, proto);
  [self.workerDispatchQueue verifyIsCurrentQueue];

  // A successful response means the stream is healthy.
  [self.backoff reset];

  FSTWatchChange *change = [_serializer decodedWatchChange:proto];
  FSTSnapshotVersion *snap = [_serializer versionFromListenResponse:proto];
  [self.delegate watchStreamDidChange:change snapshotVersion:snap];
}

@end

#pragma mark - FSTWriteStream

@interface FSTWriteStream ()

@property(nonatomic, strong, readonly) FSTSerializerBeta *serializer;

@end

@implementation FSTWriteStream

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                      serializer:(FSTSerializerBeta *)serializer {
  self = [super initWithDatabase:database
             workerDispatchQueue:workerDispatchQueue
                     credentials:credentials
            responseMessageClass:[GCFSWriteResponse class]];
  if (self) {
    _serializer = serializer;
  }
  return self;
}

- (GRPCCall *)createRPCWithRequestsWriter:(GRXWriter *)requestsWriter {
  return [[GRPCCall alloc] initWithHost:self.databaseInfo.host
                                   path:@"/google.firestore.v1beta1.Firestore/Write"
                         requestsWriter:requestsWriter];
}

- (void)startWithDelegate:(id)delegate {
  self.handshakeComplete = NO;
  [super startWithDelegate:delegate];
}

- (void)notifyStreamOpen {
  [self.delegate writeStreamDidOpen];
}

- (void)notifyStreamInterruptedWithError:(nullable NSError *)error {
  id<FSTWriteStreamDelegate> delegate = self.delegate;
  self.delegate = nil;
  [delegate writeStreamWasInterruptedWithError:error];
}

- (void)tearDown {
  if ([self isHandshakeComplete]) {
    // Send an empty write request to the backend to indicate imminent stream closure. This allows
    // the backend to clean up resources.
    [self writeMutations:@[]];
  }
}

- (void)writeHandshake {
  // The initial request cannot contain mutations, but must contain a projectID.
  FSTAssert([self isOpen], @"Not yet open");
  FSTAssert(!self.handshakeComplete, @"Handshake sent out of turn");
  [self.workerDispatchQueue verifyIsCurrentQueue];

  GCFSWriteRequest *request = [GCFSWriteRequest message];
  request.database = [_serializer encodedDatabaseID];
  // TODO(dimond): Support stream resumption. We intentionally do not set the stream token on the
  // handshake, ignoring any stream token we might have.

  FSTLog(@"FSTWriteStream %p initial request: %@", (__bridge void *)self, request);
  [self writeRequest:request];
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations {
  FSTAssert([self isOpen], @"Not yet open");
  FSTAssert(self.handshakeComplete, @"Mutations sent out of turn");
  [self.workerDispatchQueue verifyIsCurrentQueue];

  NSMutableArray<GCFSWrite *> *protos = [NSMutableArray arrayWithCapacity:mutations.count];
  for (FSTMutation *mutation in mutations) {
    [protos addObject:[_serializer encodedMutation:mutation]];
  };

  GCFSWriteRequest *request = [GCFSWriteRequest message];
  request.writesArray = protos;
  request.streamToken = self.lastStreamToken;

  FSTLog(@"FSTWriteStream %p mutation request: %@", (__bridge void *)self, request);
  [self writeRequest:request];
}

/**
 * Implements GRXWriteable to receive an inbound message from GRPC, deserialize, and then pass
 * that on to the mutationResultsHandler.
 */
- (void)handleStreamMessage:(GCFSWriteResponse *)response {
  FSTLog(@"FSTWriteStream %p response: %@", (__bridge void *)self, response);
  [self.workerDispatchQueue verifyIsCurrentQueue];

  // Always capture the last stream token.
  self.lastStreamToken = response.streamToken;

  if (!self.isHandshakeComplete) {
    // The first response is the handshake response
    self.handshakeComplete = YES;

    [self.delegate writeStreamDidCompleteHandshake];
  } else {
    // A successful first write response means the stream is healthy.
    // Note that we could consider a successful handshake healthy, however, the write itself
    // might be causing an error we want to back off from.
    [self.backoff reset];

    FSTSnapshotVersion *commitVersion = [_serializer decodedVersion:response.commitTime];
    NSMutableArray<GCFSWriteResult *> *protos = response.writeResultsArray;
    NSMutableArray<FSTMutationResult *> *results = [NSMutableArray arrayWithCapacity:protos.count];
    for (GCFSWriteResult *proto in protos) {
      [results addObject:[_serializer decodedMutationResult:proto]];
    };

    [self.delegate writeStreamDidReceiveResponseWithVersion:commitVersion mutationResults:results];
  }
}

@end
