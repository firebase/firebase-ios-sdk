// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace+Private.h"

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/FPRURLFilter.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"
#import "FirebasePerformance/Sources/ISASwizzler/FPRObjectSwizzler.h"

NSString *const kFPRNetworkTracePropertyName = @"fpr_networkTrace";

@interface FPRNetworkTrace ()

@property(nonatomic, readwrite) NSURLRequest *URLRequest;

@property(nonatomic, readwrite, nullable) NSError *responseError;

/** State to know if the trace has started. */
@property(nonatomic) BOOL traceStarted;

/** State to know if the trace has completed. */
@property(nonatomic) BOOL traceCompleted;

/** Background activity tracker to know the background state of the trace. */
@property(nonatomic) FPRTraceBackgroundActivityTracker *backgroundActivityTracker;

/** Custom attribute managed internally. */
@property(nonatomic) NSMutableDictionary<NSString *, NSString *> *customAttributes;

/** @brief Serial queue to manage the updation of session Ids. */
@property(nonatomic, readwrite) dispatch_queue_t sessionIdSerialQueue;

/**
 * Updates the current trace with the current session details.
 * @param sessionDetails Updated session details of the currently active session.
 */
- (void)updateTraceWithCurrentSession:(FPRSessionDetails *)sessionDetails;

@end

@implementation FPRNetworkTrace {
  /**
   * @brief Object containing different states of the network request. Stores the information about
   * the state of a network request (defined in FPRNetworkTraceCheckpointState) and the time at
   * which the event happened.
   */
  NSMutableDictionary<NSString *, NSNumber *> *_states;
}

- (nullable instancetype)initWithURLRequest:(NSURLRequest *)URLRequest {
  if (URLRequest.URL == nil) {
    FPRLogError(kFPRNetworkTraceInvalidInputs, @"Invalid URL. URL is nil.");
    return nil;
  }

  // Fail early instead of creating a trace here.
  // IMPORTANT: Order is important here. This check needs to be done before looking up on remote
  // config. Reference bug: b/141861005.
  if (![[FPRURLFilter sharedInstance] shouldInstrumentURL:URLRequest.URL.absoluteString]) {
    return nil;
  }

  BOOL tracingEnabled = [FPRConfigurations sharedInstance].isDataCollectionEnabled;
  if (!tracingEnabled) {
    FPRLogInfo(kFPRTraceDisabled, @"Trace feature is disabled.");
    return nil;
  }

  BOOL sdkEnabled = [[FPRConfigurations sharedInstance] sdkEnabled];
  if (!sdkEnabled) {
    FPRLogInfo(kFPRTraceDisabled, @"Dropping event since Performance SDK is disabled.");
    return nil;
  }

  NSString *trimmedURLString = [FPRNetworkTrace stringByTrimmingURLString:URLRequest];
  if (!trimmedURLString || trimmedURLString.length <= 0) {
    FPRLogWarning(kFPRNetworkTraceURLLengthExceeds, @"URL length outside limits, returning nil.");
    return nil;
  }

  if (![URLRequest.URL.absoluteString isEqualToString:trimmedURLString]) {
    FPRLogInfo(kFPRNetworkTraceURLLengthTruncation,
               @"URL length exceeds limits, truncating recorded URL - %@.", trimmedURLString);
  }

  self = [super init];
  if (self) {
    _URLRequest = URLRequest;
    _trimmedURLString = trimmedURLString;
    _states = [[NSMutableDictionary<NSString *, NSNumber *> alloc] init];
    _hasValidResponseCode = NO;
    _customAttributes = [[NSMutableDictionary<NSString *, NSString *> alloc] init];
    _syncQueue =
        dispatch_queue_create("com.google.perf.networkTrace.metric", DISPATCH_QUEUE_SERIAL);
    _sessionIdSerialQueue =
        dispatch_queue_create("com.google.perf.sessionIds.networkTrace", DISPATCH_QUEUE_SERIAL);
    _activeSessions = [[NSMutableArray<FPRSessionDetails *> alloc] init];
    if (![FPRNetworkTrace isCompleteAndValidTrimmedURLString:_trimmedURLString
                                                  URLRequest:_URLRequest]) {
      return nil;
    };
  }
  return self;
}

- (instancetype)init {
  FPRAssert(NO, @"Not a designated initializer.");
  return nil;
}

- (void)dealloc {
  // Safety net to ensure the notifications are not received anymore.
  FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
  [sessionManager.sessionNotificationCenter removeObserver:self
                                                      name:kFPRSessionIdUpdatedNotification
                                                    object:sessionManager];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"Request: %@", _URLRequest];
}

- (void)sessionChanged:(NSNotification *)notification {
  if (self.traceStarted && !self.traceCompleted) {
    NSDictionary<NSString *, FPRSessionDetails *> *userInfo = notification.userInfo;
    FPRSessionDetails *sessionDetails = [userInfo valueForKey:kFPRSessionIdNotificationKey];
    if (sessionDetails) {
      [self updateTraceWithCurrentSession:sessionDetails];
    }
  }
}

- (void)updateTraceWithCurrentSession:(FPRSessionDetails *)sessionDetails {
  if (sessionDetails != nil) {
    dispatch_sync(self.sessionIdSerialQueue, ^{
      [self.activeSessions addObject:sessionDetails];
    });
  }
}

- (NSArray<FPRSessionDetails *> *)sessions {
  __block NSArray<FPRSessionDetails *> *sessionInfos = nil;
  dispatch_sync(self.sessionIdSerialQueue, ^{
    sessionInfos = [self.activeSessions copy];
  });
  return sessionInfos;
}

- (NSDictionary<NSString *, NSNumber *> *)checkpointStates {
  __block NSDictionary<NSString *, NSNumber *> *copiedStates;
  dispatch_sync(self.syncQueue, ^{
    copiedStates = [_states copy];
  });
  return copiedStates;
}

- (void)checkpointState:(FPRNetworkTraceCheckpointState)state {
  if (!self.traceCompleted && self.traceStarted) {
    NSString *stateKey = @(state).stringValue;
    if (stateKey) {
      dispatch_sync(self.syncQueue, ^{
        NSNumber *existingState = _states[stateKey];

        if (existingState == nil) {
          double intervalSinceEpoch = [[NSDate date] timeIntervalSince1970];
          [_states setObject:@(intervalSinceEpoch) forKey:stateKey];
        }
      });
    } else {
      FPRAssert(NO, @"stateKey wasn't created for checkpoint state %ld", (long)state);
    }
  }
}

- (void)start {
  if (!self.traceCompleted) {
    [[FPRSessionManager sharedInstance] collectAllGaugesOnce];
    self.traceStarted = YES;
    self.backgroundActivityTracker = [[FPRTraceBackgroundActivityTracker alloc] init];
    [self checkpointState:FPRNetworkTraceCheckpointStateInitiated];

    if ([self.URLRequest.HTTPMethod isEqualToString:@"POST"] ||
        [self.URLRequest.HTTPMethod isEqualToString:@"PUT"]) {
      self.requestSize = self.URLRequest.HTTPBody.length;
    }
    FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
    [self updateTraceWithCurrentSession:[sessionManager.sessionDetails copy]];
    [sessionManager.sessionNotificationCenter addObserver:self
                                                 selector:@selector(sessionChanged:)
                                                     name:kFPRSessionIdUpdatedNotification
                                                   object:sessionManager];
  }
}

- (FPRTraceState)backgroundTraceState {
  FPRTraceBackgroundActivityTracker *backgroundActivityTracker = self.backgroundActivityTracker;
  if (backgroundActivityTracker) {
    return backgroundActivityTracker.traceBackgroundState;
  }

  return FPRTraceStateUnknown;
}

- (NSTimeInterval)startTimeSinceEpoch {
  NSString *stateKey =
      [NSString stringWithFormat:@"%lu", (unsigned long)FPRNetworkTraceCheckpointStateInitiated];
  __block NSTimeInterval timeSinceEpoch;
  dispatch_sync(self.syncQueue, ^{
    timeSinceEpoch = [[_states objectForKey:stateKey] doubleValue];
  });
  return timeSinceEpoch;
}

#pragma mark - Overrides

- (void)setResponseCode:(int32_t)responseCode {
  dispatch_sync(self.syncQueue, ^{
    _responseCode = responseCode;
  });
  if (responseCode != 0) {
    _hasValidResponseCode = YES;
  }
}

#pragma mark - FPRNetworkResponseHandler methods

- (void)didCompleteRequestWithResponse:(NSURLResponse *)response error:(NSError *)error {
  if (!self.traceCompleted && self.traceStarted) {
    // Extract needed fields for the trace object.
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
      self.responseCode = (int32_t)HTTPResponse.statusCode;
    }
    self.responseError = error;
    // Safely copy MIMEType to prevent use after free
    NSString *mime = [response.MIMEType copy];
    self.responseContentType = (mime.length ? mime : nil);
    [self checkpointState:FPRNetworkTraceCheckpointStateResponseCompleted];

    // Send the network trace for logging.
    [[FPRSessionManager sharedInstance] collectAllGaugesOnce];
    [[FPRClient sharedInstance] logNetworkTrace:self];

    self.traceCompleted = YES;
  }

  FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
  [sessionManager.sessionNotificationCenter removeObserver:self
                                                      name:kFPRSessionIdUpdatedNotification
                                                    object:sessionManager];
}

- (void)didUploadFileWithURL:(NSURL *)URL {
  NSNumber *value = nil;
  NSError *error = nil;

  if ([URL getResourceValue:&value forKey:NSURLFileSizeKey error:&error]) {
    if (error) {
      FPRLogNotice(kFPRNetworkTraceFileError, @"Unable to determine the size of file.");
    } else {
      self.requestSize = value.unsignedIntegerValue;
    }
  }
}

- (void)didReceiveData:(NSData *)data {
  dispatch_sync(self.syncQueue, ^{
    self.responseSize = data.length;
  });
}

- (void)didReceiveFileURL:(NSURL *)URL {
  NSNumber *value = nil;
  NSError *error = nil;

  if ([URL getResourceValue:&value forKey:NSURLFileSizeKey error:&error]) {
    if (error) {
      FPRLogNotice(kFPRNetworkTraceFileError, @"Unable to determine the size of file.");
    } else {
      dispatch_sync(self.syncQueue, ^{
        self.responseSize = value.unsignedIntegerValue;
      });
    }
  }
}

- (NSTimeInterval)timeIntervalBetweenCheckpointState:(FPRNetworkTraceCheckpointState)startState
                                            andState:(FPRNetworkTraceCheckpointState)endState {
  __block NSNumber *startStateTime;
  __block NSNumber *endStateTime;
  dispatch_sync(self.syncQueue, ^{
    startStateTime = [_states objectForKey:[@(startState) stringValue]];
    endStateTime = [_states objectForKey:[@(endState) stringValue]];
  });
  // Fail fast. If any of the times do not exist, return 0.
  if (startStateTime == nil || endStateTime == nil) {
    return 0;
  }

  NSTimeInterval timeDiff = (endStateTime.doubleValue - startStateTime.doubleValue);
  return timeDiff;
}

/** Trims and validates the URL string of a given NSURLRequest.
 *
 *  @param URLRequest The NSURLRequest containing the URL string to trim.
 *  @return The trimmed string.
 */
+ (NSString *)stringByTrimmingURLString:(NSURLRequest *)URLRequest {
  NSURLComponents *components = [NSURLComponents componentsWithURL:URLRequest.URL
                                           resolvingAgainstBaseURL:NO];
  components.query = nil;
  components.fragment = nil;
  components.user = nil;
  components.password = nil;
  NSURL *trimmedURL = [components URL];
  NSString *truncatedURLString = FPRTruncatedURLString(trimmedURL.absoluteString);

  NSURL *truncatedURL = [NSURL URLWithString:truncatedURLString];
  if (!truncatedURL || truncatedURL.host == nil) {
    return nil;
  }
  return truncatedURLString;
}

/** Validates the trace object by checking that it's http or https, and not a denied URL.
 *
 *  @param trimmedURLString A trimmed URL string from the URLRequest.
 *  @param URLRequest The NSURLRequest that this trace will operate on.
 *  @return YES if the trace object is valid, NO otherwise.
 */
+ (BOOL)isCompleteAndValidTrimmedURLString:(NSString *)trimmedURLString
                                URLRequest:(NSURLRequest *)URLRequest {
  if (![[FPRURLFilter sharedInstance] shouldInstrumentURL:trimmedURLString]) {
    return NO;
  }

  // Check the URL begins with http or https.
  NSURLComponents *components = [NSURLComponents componentsWithURL:URLRequest.URL
                                           resolvingAgainstBaseURL:NO];
  NSString *scheme = components.scheme;
  if (!scheme || !([scheme caseInsensitiveCompare:@"HTTP"] == NSOrderedSame ||
                   [scheme caseInsensitiveCompare:@"HTTPS"] == NSOrderedSame)) {
    FPRLogError(kFPRNetworkTraceInvalidInputs, @"Invalid URL - %@, returning nil.", URLRequest.URL);
    return NO;
  }

  return YES;
}

#pragma mark - Custom attributes related methods

- (NSDictionary<NSString *, NSString *> *)attributes {
  return [self.customAttributes copy];
}

- (void)setValue:(NSString *)value forAttribute:(nonnull NSString *)attribute {
  BOOL canAddAttribute = YES;
  if (self.traceCompleted) {
    FPRLogError(kFPRTraceAlreadyStopped,
                @"Failed to set attribute %@ because network request %@ has already stopped.",
                attribute, self.URLRequest.URL);
    canAddAttribute = NO;
  }

  NSString *validatedName = FPRReservableAttributeName(attribute);
  NSString *validatedValue = FPRValidatedAttributeValue(value);

  if (validatedName == nil) {
    FPRLogError(kFPRAttributeNoName,
                @"Failed to initialize because of a nil or zero length attribute name.");
    canAddAttribute = NO;
  }

  if (validatedValue == nil) {
    FPRLogError(kFPRAttributeNoValue,
                @"Failed to initialize because of a nil or zero length attribute value.");
    canAddAttribute = NO;
  }

  if (self.customAttributes.allKeys.count >= kFPRMaxGlobalCustomAttributesCount) {
    FPRLogError(kFPRMaxAttributesReached,
                @"Only %d attributes allowed. Already reached maximum attribute count.",
                kFPRMaxGlobalCustomAttributesCount);
    canAddAttribute = NO;
  }

  if (canAddAttribute) {
    // Ensure concurrency during update of attributes.
    dispatch_sync(self.syncQueue, ^{
      self.customAttributes[validatedName] = validatedValue;
      FPRLogDebug(kFPRClientMetricLogged, @"Setting attribute %@ to %@ on network request %@",
                  validatedName, validatedValue, self.URLRequest.URL);
    });
  }
}

- (NSString *)valueForAttribute:(NSString *)attribute {
  // TODO(b/175053654): Should this be happening on the serial queue for thread safety?
  return self.customAttributes[attribute];
}

- (void)removeAttribute:(NSString *)attribute {
  if (self.traceCompleted) {
    FPRLogError(kFPRTraceAlreadyStopped,
                @"Failed to remove attribute %@ because network request %@ has already stopped.",
                attribute, self.URLRequest.URL);
    return;
  }

  [self.customAttributes removeObjectForKey:attribute];
}

#pragma mark - Class methods related to object association.

+ (void)addNetworkTrace:(FPRNetworkTrace *)networkTrace toObject:(id)object {
  if (object != nil && networkTrace != nil) {
    [FPRObjectSwizzler
        setAssociatedObject:object
                        key:(__bridge const void *_Nonnull)kFPRNetworkTracePropertyName
                      value:networkTrace
                association:GUL_ASSOCIATION_RETAIN_NONATOMIC];
  }
}

+ (FPRNetworkTrace *)networkTraceFromObject:(id)object {
  FPRNetworkTrace *networkTrace = nil;
  if (object != nil) {
    id traceObject = [FPRObjectSwizzler
        getAssociatedObject:object
                        key:(__bridge const void *_Nonnull)kFPRNetworkTracePropertyName];
    if ([traceObject isKindOfClass:[FPRNetworkTrace class]]) {
      networkTrace = (FPRNetworkTrace *)traceObject;
    }
  }

  return networkTrace;
}

+ (void)removeNetworkTraceFromObject:(id)object {
  if (object != nil) {
    [FPRObjectSwizzler
        setAssociatedObject:object
                        key:(__bridge const void *_Nonnull)kFPRNetworkTracePropertyName
                      value:nil
                association:GUL_ASSOCIATION_RETAIN_NONATOMIC];
  }
}

- (BOOL)isValid {
  return _hasValidResponseCode;
}

@end
