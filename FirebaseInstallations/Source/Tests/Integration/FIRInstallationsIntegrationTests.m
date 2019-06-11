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

#import <FirebaseCore/FIRAppInternal.h>

#import <FirebaseInstallations/FIRInstallations.h>

@interface FIRInstallationsIntegrationTests : XCTestCase
@property(nonatomic) FIRInstallations *installations;
@end

@implementation FIRInstallationsIntegrationTests

- (void)setUp {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [FIRApp configure];
  });

  self.installations = [FIRInstallations installationsWithApp:[FIRApp defaultApp]];
}

- (void)tearDown {
}

- (void)testGetFID {
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"FID"];

  __block NSString *retreivedID;
  [self.installations installationIDWithCompletion:^(NSString * _Nullable identifier, NSError * _Nullable error) {
    XCTAssertNotNil(identifier);
    XCTAssertNil(error);
    XCTAssertEqual(identifier.length, 22);

    retreivedID = identifier;

    [expectation1 fulfill];
  }];

  [self waitForExpectations:@[ expectation1 ] timeout:2];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"FID"];

  [self.installations installationIDWithCompletion:^(NSString * _Nullable identifier, NSError * _Nullable error) {
    XCTAssertNotNil(identifier);
    XCTAssertNil(error);
    XCTAssertEqual(identifier.length, 22);

    XCTAssertEqualObjects(identifier, retreivedID);

    [expectation2 fulfill];
  }];

  [self waitForExpectations:@[ expectation2 ] timeout:2];
}


@end
