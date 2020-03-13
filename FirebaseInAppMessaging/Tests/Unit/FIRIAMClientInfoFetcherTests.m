/*
* Copyright 2020 Google
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
#import <OCMock/OCMock.h>

#import "FIRIAMClientInfoFetcher.h"

#import <FirebaseInstallations/FIRInstallations.h>

@interface FIRIAMClientInfoFetcherTests : XCTestCase

@end

@implementation FIRIAMClientInfoFetcherTests

- (void)setUp {
  [self mockInstanceIDMethodForTokenAndIdentity:@"hey_im_token" tokenError:nil identity:@"hey_im" identityError:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

// Mock instance ID methods.
- (void)mockInstanceIDMethodForTokenAndIdentity:(nullable NSString *)token
                                     tokenError:(nullable NSError *)tokenError
                                       identity:(nullable NSString *)identity
                                  identityError:(nullable NSError *)identityError {
  // Mock the installations retreival method.
  id installationsMock = OCMClassMock([FIRInstallations class]);
  OCMStub([installationsMock
      installationIDWithCompletion:([OCMArg
                                       invokeBlockWithArgs:(identity ? identity : [NSNull null]),
                                                           (identityError ? identityError
                                                                          : [NSNull null]),
                                                           nil])]);
  OCMStub([installationsMock
      authTokenWithCompletion:([OCMArg invokeBlockWithArgs:(identity ? identity : [NSNull null]),
                                                           (identityError ? identityError
                                                                          : [NSNull null]),
                                                           nil])]);
}

@end
