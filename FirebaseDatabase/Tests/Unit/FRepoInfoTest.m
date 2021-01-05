/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"
@interface FRepoInfoTest : XCTestCase

@end

@implementation FRepoInfoTest

- (void)testGetConnectionUrl {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"test-namespace.example.com"
                                           isSecure:NO
                                      withNamespace:@"tests"];
  XCTAssertEqualObjects(info.connectionURL, @"ws://test-namespace.example.com/.ws?v=5&ns=tests",
                        @"getConnection works");
}

- (void)testGetConnectionUrlWithLastSession {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"tests-namespace.example.com"
                                           isSecure:NO
                                      withNamespace:@"tests"];
  XCTAssertEqualObjects([info connectionURLWithLastSessionID:@"testsession"],
                        @"ws://tests-namespace.example.com/.ws?v=5&ns=tests&ls=testsession",
                        @"getConnectionWithLastSession works");
}
@end
