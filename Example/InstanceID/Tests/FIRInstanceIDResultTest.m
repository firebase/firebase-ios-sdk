/*
 * Copyright 2019 Google
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

#import <XCTest/XCTest.h>

#import <FirebaseInstanceID/FIRInstanceID.h>
#import <OCMock/OCMock.h>

#import "Firebase/InstanceID/NSError+FIRInstanceID.h"

static NSString *const kFakeIID = @"fE1e1PZJFSQ";
static NSString *const kFakeToken =
    @"fE1e1PZJFSQ:APA91bFAOjp1ahBWn9rTlbjArwBEm_"
    @"yUTTzK6dhIvLqzqqCSabaa4TQVM0pGTmF6r7tmMHPe6VYiGMHuCwJFgj5v97xl78sUNMLwuPPhoci8z_"
    @"QGlCrTbxCFGzEUfvA3fGpGgIVQU2W6";

@interface FIRInstanceID (ExposedForTest)
- (NSString *)cachedTokenIfAvailable;
- (void)defaultTokenWithHandler:(FIRInstanceIDTokenHandler)handler;
- (instancetype)initPrivately;
- (void)start;
@end

@interface FIRInstanceIDResultTest : XCTestCase {
  FIRInstanceID *_instanceID;
  id _mockInstanceID;
}

@end

@implementation FIRInstanceIDResultTest

- (void)setUp {
  [super setUp];
  _mockInstanceID = OCMClassMock([FIRInstanceID class]);
}

- (void)tearDown {
  [_mockInstanceID stopMocking];
  _mockInstanceID = nil;
  [super tearDown];
}

- (void)testResultWithFailedIID {
  // mocking getting iid failed with error.
  OCMStub([_mockInstanceID
      getIDWithHandler:([OCMArg invokeBlockWithArgs:[NSNull null],
                                                    [NSError errorWithFIRInstanceIDErrorCode:100],
                                                    nil])]);

  [_instanceID
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 100);
      }];
}

- (void)testResultWithCacheToken {
  // mocking getting iid succeed and a cache token exists.
  OCMStub([_mockInstanceID
      getIDWithHandler:([OCMArg invokeBlockWithArgs:kFakeIID, [NSNull null], nil])]);
  OCMStub([_mockInstanceID cachedTokenIfAvailable]).andReturn(kFakeToken);
  [_instanceID
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.instanceID, kFakeIID);
        XCTAssertEqualObjects(result.token, kFakeToken);
      }];
}

- (void)testResultWithNewToken {
  // mocking getting iid succeed and a new token is generated.
  OCMStub([_mockInstanceID
      getIDWithHandler:([OCMArg invokeBlockWithArgs:kFakeIID, [NSNull null], nil])]);
  OCMStub([_mockInstanceID cachedTokenIfAvailable]).andReturn(nil);
  OCMStub([_mockInstanceID
      defaultTokenWithHandler:([OCMArg invokeBlockWithArgs:kFakeToken, [NSNull null], nil])]);
  [_instanceID
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result.instanceID, kFakeIID);
        XCTAssertEqualObjects(result.token, kFakeToken);
      }];
}

- (void)testResultWithFailedFetchingToken {
  // mock getting iid succeed and token fails
  OCMStub([_mockInstanceID
      getIDWithHandler:([OCMArg invokeBlockWithArgs:kFakeIID, [NSNull null], nil])]);
  OCMStub([_mockInstanceID cachedTokenIfAvailable]).andReturn(nil);
  OCMStub([_mockInstanceID
      defaultTokenWithHandler:([OCMArg
                                  invokeBlockWithArgs:[NSNull null],
                                                      [NSError errorWithFIRInstanceIDErrorCode:200],
                                                      nil])]);

  [_instanceID
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqual(error.code, 200);
      }];
}

- (void)testResultCanBeCoplied {
  // mocking getting iid succeed and a cache token exists.
  OCMStub([_mockInstanceID
      getIDWithHandler:([OCMArg invokeBlockWithArgs:kFakeIID, [NSNull null], nil])]);
  OCMStub([_mockInstanceID cachedTokenIfAvailable]).andReturn(kFakeToken);
  [_instanceID
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        FIRInstanceIDResult *resultCopy = [result copy];
        XCTAssertEqualObjects(resultCopy.instanceID, kFakeIID);
        XCTAssertEqualObjects(resultCopy.token, kFakeToken);
      }];
}

@end
