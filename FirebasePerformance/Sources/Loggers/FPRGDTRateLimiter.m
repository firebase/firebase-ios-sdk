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

#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTRateLimiter+Private.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/Common/FPRPerfDate.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTEvent.h"

#import <GoogleDataTransport/GoogleDataTransport.h>

#import "FirebasePerformance/ProtoSupport/PerfMetric.pbobjc.h"

@interface FPRGDTRateLimiter ()

/**
 * Internal date object for setting the time of transformers, which will be used for setting the
 * time for trace events and network events.
 */
@property(nonatomic) id<FPRDate> date;

@end

@implementation FPRGDTRateLimiter

- (instancetype)initWithDate:(id<FPRDate>)date {
  FPRGDTRateLimiter *transformer = [[self.class alloc] init];
  transformer.date = date;
  transformer.lastTraceEventTime = [date now];
  transformer.lastNetworkEventTime = [date now];
  return transformer;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _date = [[FPRPerfDate alloc] init];

    // Set lastTraceEventTime to default as this would get reset once we receive the first event.
    _lastTraceEventTime = [_date now];
    _lastNetworkEventTime = [_date now];

    _configurations = [FPRConfigurations sharedInstance];

    _allowedTraceEventsCount = [_configurations foregroundEventCount];
    _allowedNetworkEventsCount = [_configurations foregroundNetworkEventCount];
    if ([FPRAppActivityTracker sharedInstance].applicationState == FPRApplicationStateBackground) {
      _allowedTraceEventsCount = [_configurations backgroundEventCount];
      _allowedNetworkEventsCount = [_configurations backgroundNetworkEventCount];
    }
  }
  return self;
}

#pragma mark - Transformer methods
/**
 * Rate limit PerfMetric Events based on rate limiting logic, event that should be
 * dropped will return nil in this transformer.
 *
 * @param logEvent The event to be evaluated by rate limiting logic.
 * @return A transformed event, or nil if the transformation dropped the event.
 */
- (GDTCOREvent *)transform:(nonnull GDTCOREvent *)logEvent {
  if ([logEvent.dataObject isKindOfClass:[FPRGDTEvent class]]) {
    FPRGDTEvent *gdtEvent = (FPRGDTEvent *)logEvent.dataObject;
    FPRMSGPerfMetric *perfMetric = gdtEvent.metric;

    if (perfMetric.hasTraceMetric) {
      FPRMSGTraceMetric *traceMetric = perfMetric.traceMetric;
      // If it is an internal trace event, skip rate limiting.
      if (traceMetric.isAuto) {
        return logEvent;
      }
    }
  }

  CGFloat rate = [self resolvedTraceRate];
  NSInteger eventCount = self.allowedTraceEventsCount;
  NSInteger eventBurstSize = self.traceEventBurstSize;
  NSDate *currentTime = [self.date now];
  NSTimeInterval interval = [currentTime timeIntervalSinceDate:self.lastTraceEventTime];
  if ([self isNetworkEvent:logEvent]) {
    rate = [self resolvedNetworkRate];
    interval = [currentTime timeIntervalSinceDate:self.lastNetworkEventTime];
    eventCount = self.allowedNetworkEventsCount;
    eventBurstSize = self.networkEventburstSize;
  }

  eventCount = [self numberOfAllowedEvents:eventCount
                              timeInterval:interval
                                 burstSize:eventBurstSize
                                 eventRate:rate];

  // Dispatch events only if the allowedEventCount is greater than zero, else drop the event.
  if (eventCount > 0) {
    if ([self isNetworkEvent:logEvent]) {
      self.allowedNetworkEventsCount = --eventCount;
      self.lastNetworkEventTime = currentTime;
    } else {
      self.allowedTraceEventsCount = --eventCount;
      self.lastTraceEventTime = currentTime;
    }
    return logEvent;
  }

  // Find the type of the log event.
  FPRAppActivityTracker *appActivityTracker = [FPRAppActivityTracker sharedInstance];
  NSString *counterName = kFPRAppCounterNameTraceEventsRateLimited;
  if ([self isNetworkEvent:logEvent]) {
    counterName = kFPRAppCounterNameNetworkTraceEventsRateLimited;
  }
  [appActivityTracker.activeTrace incrementMetric:counterName byInt:1];

  return nil;
}

/**
 * Calculates the number of allowed events given the time interval, rate and burst size. Token rate
 * limiting algorithm implementation.
 *
 * @param allowedEventsCount Allowed events count on top of which new event count will be added.
 * @param timeInterval Time interval for which event count needs to be calculated.
 * @param burstSize Maximum number of events that can be allowed at any moment in time.
 * @param rate Rate at which events should be added.
 * @return Number of allowed events calculated.
 */
- (NSInteger)numberOfAllowedEvents:(NSInteger)allowedEventsCount
                      timeInterval:(NSTimeInterval)timeInterval
                         burstSize:(NSInteger)burstSize
                         eventRate:(CGFloat)rate {
  NSTimeInterval minutesPassed = timeInterval / 60;
  NSInteger newTokens = MAX(0, round(minutesPassed * rate));
  NSInteger calculatedAllowedEventsCount = MIN(allowedEventsCount + newTokens, burstSize);
  return calculatedAllowedEventsCount;
}

#pragma mark - Trace event rate related methods

/**
 * Rate at which the trace events can be accepted for a given log source.
 *
 * @return Event rate for the log source. This is based on the application's background or
 *  foreground state.
 */
- (CGFloat)resolvedTraceRate {
  if (self.overrideRate > 0) {
    return self.overrideRate;
  }

  NSInteger eventCount = [self.configurations foregroundEventCount];
  NSInteger timeLimitInMinutes = [self.configurations foregroundEventTimeLimit];

  if ([FPRAppActivityTracker sharedInstance].applicationState == FPRApplicationStateBackground) {
    eventCount = [self.configurations backgroundEventCount];
    timeLimitInMinutes = [self.configurations backgroundEventTimeLimit];
  }

  CGFloat resolvedRate = eventCount / timeLimitInMinutes;
  self.traceEventBurstSize = eventCount;
  return resolvedRate;
}

/**
 * Rate at which the network events can be accepted for a given log source.
 *
 * @return Network event rate for the log source. This is based on the application's background or
 *  foreground state.
 */
- (CGFloat)resolvedNetworkRate {
  if (self.overrideNetworkRate > 0) {
    return self.overrideNetworkRate;
  }

  NSInteger eventCount = [self.configurations foregroundNetworkEventCount];
  NSInteger timeLimitInMinutes = [self.configurations foregroundNetworkEventTimeLimit];

  if ([FPRAppActivityTracker sharedInstance].applicationState == FPRApplicationStateBackground) {
    eventCount = [self.configurations backgroundNetworkEventCount];
    timeLimitInMinutes = [self.configurations backgroundNetworkEventTimeLimit];
  }

  CGFloat resolvedRate = eventCount / timeLimitInMinutes;
  self.networkEventburstSize = eventCount;
  return resolvedRate;
}

#pragma mark - Util methods

/**
 * Given an event, returns if it is a network event. No, otherwise.
 *
 * @param logEvent The event to transform.
 * @return Yes if the event is a network event. Otherwise, No.
 */
- (BOOL)isNetworkEvent:(GDTCOREvent *)logEvent {
  if ([logEvent.dataObject isKindOfClass:[FPRGDTEvent class]]) {
    FPRGDTEvent *gdtEvent = (FPRGDTEvent *)logEvent.dataObject;
    FPRMSGPerfMetric *perfMetric = gdtEvent.metric;
    if (perfMetric.hasNetworkRequestMetric) {
      return YES;
    }
  }
  return NO;
}

@end
