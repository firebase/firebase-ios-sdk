// Copyright 2017 Google
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

#import "FIRFunctions+Internal.h"
#import "FIRFunctions.h"

@interface FIRFunctionsTests : XCTestCase
@end

@implementation FIRFunctionsTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testURLWithName {
  FIRFunctions *functions = [[FIRFunctions alloc] initWithProjectID:@"my-project"
                                                             region:@"my-region"
                                                               auth:nil];
  NSString *url = [functions URLWithName:@"my-endpoint"];
  XCTAssertEqualObjects(@"https://my-region-my-project.cloudfunctions.net/my-endpoint", url);
}

@end
