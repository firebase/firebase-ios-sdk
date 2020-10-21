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

#import "Functions/FirebaseFunctions/FIRFunctions+Internal.h"
#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRFunctions.h"

@interface FIRFunctionsTests : XCTestCase {
  FIRFunctions *_functions;
  FIRFunctions *_functionsCustomDomain;
}
@end

@implementation FIRFunctionsTests

- (void)setUp {
  [super setUp];

  _functions = [[FIRFunctions alloc] initWithProjectID:@"my-project"
                                                region:@"my-region"
                                          customDomain:nil
                                                  auth:nil
                                             messaging:nil];

  _functionsCustomDomain = [[FIRFunctions alloc] initWithProjectID:@"my-project"
                                                            region:@"my-region"
                                                      customDomain:@"https://mydomain.com"
                                                              auth:nil
                                                         messaging:nil];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testURLWithName {
  NSString *url = [_functions URLWithName:@"my-endpoint"];
  XCTAssertEqualObjects(@"https://my-region-my-project.cloudfunctions.net/my-endpoint", url);
}

- (void)testRegionWithEmulator {
  [_functions useFunctionsEmulatorOrigin:@"http://localhost:5005"];
  NSString *url = [_functions URLWithName:@"my-endpoint"];
  XCTAssertEqualObjects(@"http://localhost:5005/my-project/my-region/my-endpoint", url);
}

- (void)testCustomDomain {
  NSString *url = [_functionsCustomDomain URLWithName:@"my-endpoint"];
  XCTAssertEqualObjects(@"https://mydomain.com/my-endpoint", url);
}

- (void)testCustomDomainWithEmulator {
  [_functionsCustomDomain useFunctionsEmulatorOrigin:@"http://localhost:5005"];
  NSString *url = [_functionsCustomDomain URLWithName:@"my-endpoint"];
  XCTAssertEqualObjects(@"http://localhost:5005/my-project/my-region/my-endpoint", url);
}

@end
