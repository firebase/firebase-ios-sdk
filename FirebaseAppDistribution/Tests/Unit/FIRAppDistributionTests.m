// Copyright 2020 Google
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FIRAppDistribution+Private.h"
#import "FIRAppDistribution.h"

#import "FIROptions.h"

// MARK - Mock FIRApp
// TODO: Create FIRAppFake.h and FIRAppFake.m

@interface FIRAppFake : NSObject

@property(nonatomic, strong) FIROptions *options;

@end

@implementation FIRAppFake : NSObject

- (instancetype)initWithAppID:(NSString *)appID {
  self = [super init];
  if (self) {
    _options = [[FIROptions alloc] initWithGoogleAppID:appID GCMSenderID:@"sender"];
  }
  return self;
}

@end

// MARK - Mock authorization test
// TODO: Create FIRAppDistributionAuthMock.h and FIRAppDistributionAuthMock.m

@interface FIRAppDistributionAuthMock : NSObject <FIRAppDistributionAuthProtocol>

@property(nonatomic, strong) NSURL *discoverServiceIssuerURL;
@property(nonatomic, strong) OIDServiceConfiguration *discoverServiceConfig;
@property(nonatomic, strong) NSError *discoverServiceError;

@end

@implementation FIRAppDistributionAuthMock

- (void)discoverService:(NSURL *)issuerURL completion:(OIDDiscoveryCallback)completion {
  self.discoverServiceIssuerURL = issuerURL;
  completion(self.discoverServiceConfig, self.discoverServiceError);
}

@end

@interface FIRAppDistributionSampleTests : XCTestCase

@property(nonatomic, strong) FIRAppDistribution *appDistribution;
@property(nonatomic, strong) FIRAppDistributionAuthMock *appDistributionAuth;
@property(nonatomic, strong) FIRAppFake *app;

@end

@implementation FIRAppDistributionSampleTests

- (void)setUp {
  [super setUp];

  NSDictionary<NSString *, NSString *> *dict = [[NSDictionary<NSString *, NSString *> alloc] init];
  self.appDistributionAuth = [[FIRAppDistributionAuthMock alloc] init];
  self.app = [[FIRAppFake alloc] initWithAppID:@"someGMPAppID"];
  id fakeApp = self.app;

  self.appDistribution = [[FIRAppDistribution alloc] initWithApp:fakeApp
                                                         appInfo:dict
                                                     authHandler:self.appDistributionAuth];
}

- (void)testGetSingleton {
  XCTAssertNotNil(self.appDistribution);
}

- (void)testSignInDiscoveryError {
  NSError *discoveryError = [[NSError alloc] initWithDomain:@"discoveryDomain" code:3 userInfo:nil];
  self.appDistributionAuth.discoverServiceError = discoveryError;

  XCTestExpectation *expectation = [self expectationWithDescription:@"signInTesterWithCompletion"];

  [self.appDistribution signInTesterWithCompletion:^(NSError *error) {
    XCTAssertEqual(discoveryError, error);
    XCTAssertNil(self.appDistribution.authState);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:3];
}

@end
