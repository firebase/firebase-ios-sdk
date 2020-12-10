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

#import "FirebasePerformance/Sources/Public/FIRTrace.h"

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

@interface FIRTrace ()

@property(nonatomic, copy, readwrite) NSString *name;

/** Custom attributes managed internally. */
@property(nonatomic) NSMutableDictionary<NSString *, NSString *> *customAttributes;

/** Serial queue to manage mutation of attributes. */
@property(nonatomic, readwrite) dispatch_queue_t customAttributesSerialQueue;

@property(nonatomic, readwrite) NSDate *startTime;

@property(nonatomic, readwrite) NSDate *stopTime;

/** Background activity tracker to know the background state of the trace. */
@property(nonatomic) FPRTraceBackgroundActivityTracker *backgroundActivityTracker;

/** Property that denotes if the trace is a stage. */
@property(nonatomic) BOOL isStage;

/** Stops an active stage that is currently active. */
- (void)stopActiveStage;

/** Updates the current trace with the session id. */
- (void)updateTraceWithSessionId;

@end

@implementation FIRTrace

- (instancetype)initWithName:(NSString *)name {
  NSString *validatedName = FPRReservableName(name);

  FIRTrace *trace = [self initTraceWithName:validatedName];
  trace.internal = NO;
  return trace;
}

- (instancetype)initInternalTraceWithName:(NSString *)name {
  FIRTrace *trace = [self initTraceWithName:name];
  trace.internal = YES;
  return trace;
}

- (instancetype)initTraceWithName:(NSString *)name {
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

  FPRAssert(name != nil, @"Name cannot be nil");
  FPRAssert(name.length > 0, @"Name cannot be an empty string");

  if (name == nil || name.length == 0) {
    FPRLogError(kFPRTraceNoName, @"Failed to initialize because of a nil or zero length name.");
    return nil;
  }

  self = [super init];
  if (self) {
    _name = [name copy];
    _stages = [[NSMutableArray<FIRTrace *> alloc] init];
    _counterList = [[FPRCounterList alloc] init];
    _customAttributes = [[NSMutableDictionary<NSString *, NSString *> alloc] init];
    _customAttributesSerialQueue =
        dispatch_queue_create("com.google.perf.customAttributes.trace", DISPATCH_QUEUE_SERIAL);
    _sessionIdSerialQueue =
        dispatch_queue_create("com.google.perf.sessionIds.trace", DISPATCH_QUEUE_SERIAL);
    _activeSessions = [[NSMutableArray<FPRSessionDetails *> alloc] init];
    _isStage = NO;
    _fprClient = [FPRClient sharedInstance];
  }

  return self;
}

- (instancetype)init {
  FPRAssert(NO, @"Not a valid initializer.");
  return nil;
}

- (void)dealloc {
  // Track the number of traces that have started and not stopped.
  if (!self.isStage && [self isTraceStarted] && ![self isTraceStopped]) {
    FIRTrace *activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
    [activeTrace incrementMetric:kFPRAppCounterNameTraceNotStopped byInt:1];
    FPRLogError(kFPRTraceStartedNotStopped, @"Trace name %@ started, not stopped", self.name);
  }

  FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
  [sessionManager.sessionNotificationCenter removeObserver:self
                                                      name:kFPRSessionIdUpdatedNotification
                                                    object:sessionManager];
}

#pragma mark - Public instance methods

- (void)start {
  if (![self isTraceStarted]) {
    if (!self.isStage) {
      [[FPRGaugeManager sharedInstance] collectAllGauges];
    }
    self.startTime = [NSDate date];
    self.backgroundActivityTracker = [[FPRTraceBackgroundActivityTracker alloc] init];
    FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
    if (!self.isStage) {
      [self updateTraceWithSessionId];
      [sessionManager.sessionNotificationCenter addObserver:self
                                                   selector:@selector(updateTraceWithSessionId)
                                                       name:kFPRSessionIdUpdatedNotification
                                                     object:sessionManager];
    }
  } else {
    FPRLogError(kFPRTraceAlreadyStopped,
                @"Failed to start trace %@ because it has already been started and stopped.",
                self.name);
  }
}

- (void)startWithStartTime:(NSDate *)startTime {
  [self start];
  if (startTime) {
    self.startTime = startTime;
  }
}

- (void)stop {
  [self stopActiveStage];

  if ([self isTraceActive]) {
    self.stopTime = [NSDate date];
    [self.fprClient logTrace:self];
    if (!self.isStage) {
      [[FPRGaugeManager sharedInstance] collectAllGauges];
    }
  } else {
    FPRLogError(kFPRTraceNotStarted,
                @"Failed to stop the trace %@ because it has not been started.", self.name);
  }

  FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
  [sessionManager.sessionNotificationCenter removeObserver:self
                                                      name:kFPRSessionIdUpdatedNotification
                                                    object:sessionManager];
}

- (void)cancel {
  [self stopActiveStage];

  if ([self isTraceActive]) {
    self.stopTime = [NSDate date];
  } else {
    FPRLogError(kFPRTraceNotStarted,
                @"Failed to stop the trace %@ because it has not been started.", self.name);
  }
}

- (NSTimeInterval)totalTraceTimeInterval {
  return [self.stopTime timeIntervalSinceDate:self.startTime];
}

- (NSTimeInterval)startTimeSinceEpoch {
  return [self.startTime timeIntervalSince1970];
}

- (BOOL)isCompleteAndValid {
  // Check if the trace time interval is valid.
  if (self.totalTraceTimeInterval <= 0) {
    return NO;
  }

  // Check if the counter list is valid.
  if (![self.counterList isValid]) {
    return NO;
  }

  // Check if the stages are valid.
  __block BOOL validTrace = YES;
  [self.stages enumerateObjectsUsingBlock:^(FIRTrace *stage, NSUInteger idx, BOOL *stop) {
    validTrace = [stage isCompleteAndValid];
    if (!validTrace) {
      *stop = YES;
    }
  }];

  return validTrace;
}

- (FPRTraceState)backgroundTraceState {
  FPRTraceBackgroundActivityTracker *backgroundActivityTracker = self.backgroundActivityTracker;
  if (backgroundActivityTracker) {
    return backgroundActivityTracker.traceBackgroundState;
  }

  return FPRTraceStateUnknown;
}

- (NSArray<FPRSessionDetails *> *)sessions {
  __block NSArray<FPRSessionDetails *> *sessionInfos = nil;
  dispatch_sync(self.sessionIdSerialQueue, ^{
    sessionInfos = [self.activeSessions copy];
  });
  return sessionInfos;
}

#pragma mark - Stage related methods

- (void)startStageNamed:(NSString *)stageName startTime:(NSDate *)startTime {
  if ([self isTraceActive]) {
    [self stopActiveStage];

    if (self.isInternal) {
      self.activeStage = [[FIRTrace alloc] initInternalTraceWithName:stageName];
      [self.activeStage startWithStartTime:startTime];
    } else {
      NSString *validatedStageName = FPRReservableName(stageName);
      if (validatedStageName.length > 0) {
        self.activeStage = [[FIRTrace alloc] initWithName:validatedStageName];
        [self.activeStage startWithStartTime:startTime];
      } else {
        FPRLogError(kFPRTraceEmptyName, @"The stage name cannot be empty.");
      }
    }

    self.activeStage.isStage = YES;
    // Do not track background activity tracker for stages.
    self.activeStage.backgroundActivityTracker = nil;
  } else {
    FPRLogError(kFPRTraceNotStarted,
                @"Failed to create stage %@ because the trace has not been started.", stageName);
  }
}

- (void)startStageNamed:(NSString *)stageName {
  [self startStageNamed:stageName startTime:nil];
}

- (void)stopActiveStage {
  if (self.activeStage) {
    [self.activeStage cancel];
    [self.stages addObject:self.activeStage];
    self.activeStage = nil;
  }
}

#pragma mark - Counter related methods

- (NSDictionary *)counters {
  return [self.counterList counters];
}

- (NSUInteger)numberOfCounters {
  return [self.counterList numberOfCounters];
}

#pragma mark - Metrics related methods

- (int64_t)valueForIntMetric:(nonnull NSString *)metricName {
  return [self.counterList valueForIntMetric:metricName];
}

- (void)setIntValue:(int64_t)value forMetric:(nonnull NSString *)metricName {
  if ([self isTraceActive]) {
    NSString *validatedMetricName = self.isInternal ? metricName : FPRReservableName(metricName);
    if (validatedMetricName.length > 0) {
      [self.counterList setIntValue:value forMetric:validatedMetricName];
      [self.activeStage setIntValue:value forMetric:validatedMetricName];
    } else {
      FPRLogError(kFPRTraceInvalidName, @"The metric name is invalid.");
    }
  } else {
    FPRLogError(kFPRTraceNotStarted,
                @"Failed to set value for metric %@ because trace %@ has not been started.",
                metricName, self.name);
  }
}

- (void)incrementMetric:(nonnull NSString *)metricName byInt:(int64_t)incrementValue {
  if ([self isTraceActive]) {
    NSString *validatedMetricName = self.isInternal ? metricName : FPRReservableName(metricName);
    if (validatedMetricName.length > 0) {
      [self.counterList incrementMetric:validatedMetricName byInt:incrementValue];
      [self.activeStage incrementMetric:validatedMetricName byInt:incrementValue];
      FPRLogDebug(kFPRClientMetricLogged, @"Incrementing metric %@ to %lld on trace %@",
                  validatedMetricName, [self valueForIntMetric:metricName], self.name);
    } else {
      FPRLogError(kFPRTraceInvalidName, @"The metric name is invalid.");
    }
  } else {
    FPRLogError(kFPRTraceNotStarted,
                @"Failed to increment the trace metric %@ because trace %@ has not been started.",
                metricName, self.name);
  }
}

- (void)deleteMetric:(nonnull NSString *)metricName {
  if ([self isTraceActive]) {
    [self.counterList deleteMetric:metricName];
    [self.activeStage deleteMetric:metricName];
  }
}

#pragma mark - Custom attributes related methods

- (NSDictionary<NSString *, NSString *> *)attributes {
  return [self.customAttributes copy];
}

- (void)setValue:(NSString *)value forAttribute:(nonnull NSString *)attribute {
  BOOL canAddAttribute = YES;
  if ([self isTraceStopped]) {
    FPRLogError(kFPRTraceAlreadyStopped,
                @"Failed to set attribute %@ because trace %@ has already stopped.", attribute,
                self.name);
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

  if (self.customAttributes.allKeys.count >= kFPRMaxTraceCustomAttributesCount) {
    FPRLogError(kFPRMaxAttributesReached,
                @"Only %d attributes allowed. Already reached maximum attribute count.",
                kFPRMaxTraceCustomAttributesCount);
    canAddAttribute = NO;
  }

  if (canAddAttribute) {
    // Ensure concurrency during update of attributes.
    dispatch_sync(self.customAttributesSerialQueue, ^{
      self.customAttributes[validatedName] = validatedValue;
    });
  }
  FPRLogDebug(kFPRClientMetricLogged, @"Setting attribute %@ to %@ on trace %@", validatedName,
              validatedValue, self.name);
}

- (NSString *)valueForAttribute:(NSString *)attribute {
  // TODO(b/175053654): Should this be happening on the serial queue for thread safety?
  return self.customAttributes[attribute];
}

- (void)removeAttribute:(NSString *)attribute {
  if ([self isTraceStopped]) {
    FPRLogError(kFPRTraceNotStarted,
                @"Failed to remove attribute %@ because trace %@ has already stopped.", attribute,
                self.name);
    return;
  }

  [self.customAttributes removeObjectForKey:attribute];
}

#pragma mark - Utility methods

- (void)updateTraceWithSessionId {
  if ([self isTraceActive]) {
    dispatch_async(self.sessionIdSerialQueue, ^{
      FPRSessionManager *sessionManager = [FPRSessionManager sharedInstance];
      FPRSessionDetails *sessionDetails = sessionManager.sessionDetails;
      if (sessionDetails) {
        [self.activeSessions addObject:sessionDetails];
      }
    });
  }
}

- (BOOL)isTraceStarted {
  return self.startTime != nil;
}

- (BOOL)isTraceStopped {
  return (self.startTime != nil && self.stopTime != nil);
}

- (BOOL)isTraceActive {
  return (self.startTime != nil && self.stopTime == nil);
}

@end
