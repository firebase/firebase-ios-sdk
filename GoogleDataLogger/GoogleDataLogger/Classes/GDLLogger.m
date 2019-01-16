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

#import "GDLLogger.h"
#import "GDLLogger_Private.h"

#import "GDLAssert.h"
#import "GDLLogEvent.h"
#import "GDLLogEvent_Private.h"
#import "GDLLogWriter.h"

@implementation GDLLogger

- (instancetype)initWithLogMapID:(NSString *)logMapID
                 logTransformers:(nullable NSArray<id<GDLLogTransformer>> *)logTransformers
                       logTarget:(NSInteger)logTarget {
  self = [super init];
  if (self) {
    GDLAssert(logMapID.length > 0, @"A log mapping ID cannot be nil or empty");
    GDLAssert(logTarget > 0, @"A log target cannot be negative or 0");
    _logMapID = logMapID;
    _logTransformers = logTransformers;
    _logTarget = logTarget;
    _logWriterInstance = [GDLLogWriter sharedInstance];
  }
  return self;
}

- (void)logTelemetryEvent:(GDLLogEvent *)logEvent {
  // TODO: Determine if logging an event before registration is allowed.
  GDLAssert(logEvent, @"You can't log a nil event");
  GDLLogEvent *copiedLog = [logEvent copy];
  copiedLog.qosTier = GDLLogQoSTelemetry;
  copiedLog.clockSnapshot = [GDLClock snapshot];
  [self.logWriterInstance writeLog:copiedLog afterApplyingTransformers:_logTransformers];
}

- (void)logDataEvent:(GDLLogEvent *)logEvent {
  // TODO: Determine if logging an event before registration is allowed.
  GDLAssert(logEvent, @"You can't log a nil event");
  GDLAssert(logEvent.qosTier != GDLLogQoSTelemetry, @"Use -logTelemetryEvent, please.");
  GDLLogEvent *copiedLog = [logEvent copy];
  copiedLog.clockSnapshot = [GDLClock snapshot];
  [self.logWriterInstance writeLog:copiedLog afterApplyingTransformers:_logTransformers];
}

- (GDLLogEvent *)newEvent {
  return [[GDLLogEvent alloc] initWithLogMapID:_logMapID logTarget:_logTarget];
}

@end
