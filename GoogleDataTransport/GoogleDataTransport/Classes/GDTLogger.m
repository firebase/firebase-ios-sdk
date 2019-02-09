/*
 * Copyright 2018 Google
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

#import "GDTLogger.h"
#import "GDTLogger_Private.h"

#import "GDTAssert.h"
#import "GDTLogEvent.h"
#import "GDTLogEvent_Private.h"
#import "GDTLogWriter.h"

@implementation GDTLogger

- (instancetype)initWithLogMapID:(NSString *)logMapID
                 logTransformers:(nullable NSArray<id<GDTLogTransformer>> *)logTransformers
                       logTarget:(NSInteger)logTarget {
  self = [super init];
  if (self) {
    GDTAssert(logMapID.length > 0, @"A log mapping ID cannot be nil or empty");
    GDTAssert(logTarget > 0, @"A log target cannot be negative or 0");
    _logMapID = logMapID;
    _logTransformers = logTransformers;
    _logTarget = logTarget;
    _logWriterInstance = [GDTLogWriter sharedInstance];
  }
  return self;
}

- (void)logTelemetryEvent:(GDTLogEvent *)logEvent {
  // TODO: Determine if logging an event before registration is allowed.
  GDTAssert(logEvent, @"You can't log a nil event");
  GDTLogEvent *copiedLog = [logEvent copy];
  copiedLog.qosTier = GDTLogQoSTelemetry;
  copiedLog.clockSnapshot = [GDTClock snapshot];
  [self.logWriterInstance writeLog:copiedLog afterApplyingTransformers:_logTransformers];
}

- (void)logDataEvent:(GDTLogEvent *)logEvent {
  // TODO: Determine if logging an event before registration is allowed.
  GDTAssert(logEvent, @"You can't log a nil event");
  GDTAssert(logEvent.qosTier != GDTLogQoSTelemetry, @"Use -logTelemetryEvent, please.");
  GDTLogEvent *copiedLog = [logEvent copy];
  copiedLog.clockSnapshot = [GDTClock snapshot];
  [self.logWriterInstance writeLog:copiedLog afterApplyingTransformers:_logTransformers];
}

- (GDTLogEvent *)newEvent {
  return [[GDTLogEvent alloc] initWithLogMapID:_logMapID logTarget:_logTarget];
}

@end
