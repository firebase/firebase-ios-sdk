/*
 * Copyright 2021 Google LLC
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

#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAPIService.h"

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"

@interface FIRAppAttestAPIServiceTests : XCTestCase
@property(nonatomic) id<FIRAppCheckAPIServiceProtocol> APIService;
@property(nonatomic) NSString *projectID;
@property(nonatomic) NSString *appID;

@property(nonatomic) FIRAppAttestAPIService *service;
@end

@implementation FIRAppAttestAPIServiceTests

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testGetRandomChallengeWhenValidAPIResponse {
}

- (void)testGetRandomChallengeWhenInvalidAPIResponse {
}

- (void)testGetRandomChallengeWhenAPIResponseInvalidFormat {
}

- (void)testGetRandomChallengeWhenResponseMissingFields {
}

@end
