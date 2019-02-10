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

#import <GoogleUtilities/GULLogger.h>
#import <GoogleUtilities/GULOSLogger.h>

#import <os/log.h>

// Redefine class property as readwrite for testing.
@interface GULLogger (ForTesting)
@property(nonatomic, class, readwrite) id<GULLoggerSystem> logger;
@end

// Surface osLog and dispatchQueues for tests.
@interface GULOSLogger (ForTesting)
@property(nonatomic) NSMutableDictionary<NSString *, os_log_t> *categoryLoggers;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@end

@interface GULOSLoggerTest : XCTestCase
@end

@implementation GULOSLoggerTest
// TODO(bstpierre): Tests
@end
