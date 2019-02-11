// Copyright 2019 Google
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

#import <XCTest/XCTest.h>

#import <os/log.h>

#import <GoogleUtilities/GULLogger.h>
#import <GoogleUtilities/GULOSLogger.h>

NS_ASSUME_NONNULL_BEGIN

// Function that will be called by GULOSLogger instead of os_log_with_type.
void GULTestOSLogWithType(os_log_t log, os_log_type_t type, char *s, ...) {
}

// Expectation that contains the information needed to see if the correct parameters were used in an
// os_log_with_type call.
@interface GULOSLoggerExpectation : XCTestExpectation

@property(nonatomic, nullable) os_log_t log;
@property(nonatomic) os_log_type_t type;
@property(nonatomic) NSString *message;

- (instancetype)initWithLog:(nullable os_log_t)log
                       type:(os_log_type_t)type
                    message:(NSString *)message;
@end

@implementation GULOSLoggerExpectation

- (instancetype)initWithLog:(nullable os_log_t)log
                       type:(os_log_type_t)type
                    message:(NSString *)message {
  self = [super init];
  if (self) {
    _log = log;
    _type = type;
    _message = message;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if ([object isKindOfClass:[self class]]) {
    return NO;
  }
  GULOSLoggerExpectation *other = (GULOSLoggerExpectation *)object;
  return self.log == other.log && self.type == other.type &&
         [self.message isEqualToString:other.message];
}
@end

// List of expectations that may be fulfilled in the current test.
static NSMutableArray<GULOSLoggerExpectation *> *sExpectations;

#pragma mark -

// Redefine class property as readwrite for testing.
@interface GULLogger (ForTesting)
@property(nonatomic, class, readwrite) id<GULLoggerSystem> logger;
@end

// Surface osLog and dispatchQueues for tests.
@interface GULOSLogger (ForTesting)
@property(nonatomic) NSMutableDictionary<NSString *, os_log_t> *categoryLoggers;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(nonatomic, unsafe_unretained) void (*logFunction)(os_log_t, os_log_type_t, char *, ...);
@end

#pragma mark -

@interface GULOSLoggerTest : XCTestCase
@property(nonatomic) GULOSLogger *osLogger;
@end

@implementation GULOSLoggerTest

- (void)setUp {
  self.osLogger = [[GULOSLogger alloc] init];
  self.osLogger.logFunction = &GULTestOSLogWithType;
}

// TODO(bstpierre): Write tests.

@end

NS_ASSUME_NONNULL_END
