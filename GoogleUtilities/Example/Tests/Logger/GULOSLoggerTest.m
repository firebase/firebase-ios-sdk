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

void __gul_test_os_log_with_type(os_log_t log, os_log_type_t type, char* s, ...) {
  // TODO(bstpierre): Verify that the params are as expected.
}

// Redefine class property as readwrite for testing.
@interface GULLogger (ForTesting)
@property(nonatomic, class, readwrite) id<GULLoggerSystem> logger;
@end

// Surface osLog and dispatchQueues for tests.
@interface GULOSLogger (ForTesting)
@property(nonatomic) NSMutableDictionary<NSString *, os_log_t> *categoryLoggers;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(nonatomic) void (*logFunction)(os_log_t, os_log_type_t, char*, ...);
@end

@interface GULOSLoggerTest : XCTestCase
@property(nonatomic) GULOSLogger *osLogger;
@end

@implementation GULOSLoggerTest

- (void)setUp {
  self.osLogger = [[GULOSLogger alloc] init];
  self.osLogger.logFunction = &__gul_test_os_log_with_type;
}

- (void)tearDown {
  self.osLogger = nil;
}

// TODO(bstpierre): Write tests.

@end
