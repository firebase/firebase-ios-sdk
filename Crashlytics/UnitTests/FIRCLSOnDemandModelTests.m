// Copyright 2022 Google LLC
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

#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockOnDemandModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"

@interface FIRCLSOnDemandModelTests : XCTestCase

@property(nonatomic, retain) FIRCLSMockOnDemandModel *onDemandModel;

@end

@implementation FIRCLSOnDemandModelTests

- (void)setUp {
  [super setUp];
  _onDemandModel = [[FIRCLSMockOnDemandModel alloc] initWithOnDemandUploadRate:15
                                                                  baseExponent:5
                                                                  stepDuration:10];
}

- (void)tearDown {
  self.onDemandModel = nil;

  [super tearDown];
}

- (void)testCompliesWithDataCollectionOff {
}

- (void)testExceptionNotRecordedIfNoQuota {
}

- (void)testQueueFull {
}

@end
