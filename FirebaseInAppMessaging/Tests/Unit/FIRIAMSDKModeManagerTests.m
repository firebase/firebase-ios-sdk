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

#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMSDKModeManager.h"

@interface FIRIAMSDKModeManagerTests : XCTestCase
@property(nonatomic) GULUserDefaults *mockUserDefaults;
@property(nonatomic) id<FIRIAMTestingModeListener> mockTestingModeListener;
@end

@implementation FIRIAMSDKModeManagerTests

- (void)setUp {
  [super setUp];
  self.mockUserDefaults = OCMClassMock(GULUserDefaults.class);
  self.mockTestingModeListener = OCMStrictProtocolMock(@protocol(FIRIAMTestingModeListener));
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testFirstRunFromInstall_ok {
  // mode entry not existing from a fresh install
  OCMStub([self.mockUserDefaults objectForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForSDKMode]])
      .andReturn(nil);
  FIRIAMSDKModeManager *sdkManager =
      [[FIRIAMSDKModeManager alloc] initWithUserDefaults:self.mockUserDefaults
                                     testingModeListener:self.mockTestingModeListener];

  XCTAssertEqual(FIRIAMSDKModeNewlyInstalled, [sdkManager currentMode]);

  // verify that we setting the mode into use defaults
  OCMVerify([self.mockUserDefaults
      setObject:[OCMArg isEqual:[NSNumber numberWithInt:FIRIAMSDKModeNewlyInstalled]]
         forKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForSDKMode]]);

  // verify that we are initializing fetch count as 0 by writing into user defaults
  OCMVerify([self.mockUserDefaults
      setInteger:0
          forKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForServerFetchCount]]);
}

- (void)testGoingIntoRegularFromNewlyInstalledMode {
  // mode entry not existing from a fresh install
  OCMStub([self.mockUserDefaults objectForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForSDKMode]])
      .andReturn(nil);
  FIRIAMSDKModeManager *sdkManager =
      [[FIRIAMSDKModeManager alloc] initWithUserDefaults:self.mockUserDefaults
                                     testingModeListener:self.mockTestingModeListener];
  XCTAssertEqual(FIRIAMSDKModeNewlyInstalled, [sdkManager currentMode]);

  // now we register up to kFIRIAMMaxFetchInNewlyInstalledMode - 1 fetches and it still stay
  // in Newly Installed mode
  for (int i = 0; i < kFIRIAMMaxFetchInNewlyInstalledMode - 1; i++) {
    [sdkManager registerOneMoreFetch];
  }
  XCTAssertEqual(FIRIAMSDKModeNewlyInstalled, [sdkManager currentMode]);

  // now one more fetch would turn it into regular mode
  [sdkManager registerOneMoreFetch];
  XCTAssertEqual(FIRIAMSDKModeRegular, [sdkManager currentMode]);
}

- (void)testIncrementCountForFetchRegistrationFromNewlyInstalledMode {
  // put sdk into regular mode
  OCMStub([self.mockUserDefaults objectForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForSDKMode]])
      .andReturn([NSNumber numberWithInt:FIRIAMSDKModeNewlyInstalled]);

  int currentFetchCount = 3;
  OCMStub([self.mockUserDefaults
              integerForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForServerFetchCount]])
      .andReturn(currentFetchCount);
  FIRIAMSDKModeManager *sdkManager =
      [[FIRIAMSDKModeManager alloc] initWithUserDefaults:self.mockUserDefaults
                                     testingModeListener:self.mockTestingModeListener];

  // now we do new fetch registration
  [sdkManager registerOneMoreFetch];

  // verify that we are writing currentFetchCount+1 into user defaults
  OCMVerify([self.mockUserDefaults
      setInteger:currentFetchCount + 1
          forKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForServerFetchCount]]);
}

- (void)testNoUpdateForFetchRegistrationFromRegularMode {
  // put sdk into regular mode
  OCMStub([self.mockUserDefaults objectForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForSDKMode]])
      .andReturn([NSNumber numberWithInt:FIRIAMSDKModeRegular]);

  int currentFetchCount = 3;
  OCMStub([self.mockUserDefaults
              integerForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForServerFetchCount]])
      .andReturn(currentFetchCount);
  FIRIAMSDKModeManager *sdkManager =
      [[FIRIAMSDKModeManager alloc] initWithUserDefaults:self.mockUserDefaults
                                     testingModeListener:self.mockTestingModeListener];

  // now we do new fetch registration, but no more fetch count or mode updates in user defaults
  [sdkManager registerOneMoreFetch];
  XCTAssertEqual(FIRIAMSDKModeRegular, [sdkManager currentMode]);
  OCMReject([self.mockUserDefaults setInteger:currentFetchCount + 1 forKey:[OCMArg any]]);
}

- (void)testGoingIntoTestingDeviceMode {
  // mode entry not existing from a fresh install
  OCMStub([self.mockUserDefaults objectForKey:[OCMArg isEqual:kFIRIAMUserDefaultKeyForSDKMode]])
      .andReturn(nil);
  OCMExpect([self.mockTestingModeListener testingModeSwitchedOn]);
  FIRIAMSDKModeManager *sdkManager =
      [[FIRIAMSDKModeManager alloc] initWithUserDefaults:self.mockUserDefaults
                                     testingModeListener:self.mockTestingModeListener];

  [sdkManager becomeTestingInstance];
  XCTAssertEqual(FIRIAMSDKModeTesting, [sdkManager currentMode]);
  OCMVerify([self.mockTestingModeListener testingModeSwitchedOn]);
}
@end
