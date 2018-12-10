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

#import "GDLLogEvent.h"

@interface GDLLogger ()

/** The log mapping identifier that a GDLLogBackend will use to map the extension to proto. */
@property(nonatomic) NSString *logMapID;

/** The log transformers that will operate on logs logged by this logger. */
@property(nonatomic) NSArray<id<GDLLogTransformer>> *logTransformers;

/** The target backend of this logger. */
@property(nonatomic) NSInteger logTarget;

@end

@implementation GDLLogger

- (instancetype)initWithLogMapID:(NSString *)logMapID
                 logTransformers:(nullable NSArray<id<GDLLogTransformer>> *)logTransformers
                       logTarget:(NSInteger)logTarget {
  self = [super init];
  if (self) {
    NSAssert(logMapID.length > 0, @"A log mapping ID cannot be nil or empty");
    NSAssert(logTarget > 0, @"A log target cannot be negative or 0");
    _logMapID = logMapID;
    _logTransformers = logTransformers;
    _logTarget = logTarget;
  }
  return self;
}

- (void)logTelemetryEvent:(GDLLogEvent *)logEvent {
  NSAssert(logEvent, @"You can't log a nil event");

  // TODO(mikehaney24): Implement.
}

- (void)logDataEvent:(GDLLogEvent *)logEvent {
  NSAssert(logEvent, @"You can't log a nil event");

  // TODO(mikehaney24): Implement.
}

- (GDLLogEvent *)newEvent {
  return [[GDLLogEvent alloc] init];
}

@end
