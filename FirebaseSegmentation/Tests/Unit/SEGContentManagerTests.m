// Copyright 2019 Google
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

#import "FirebaseSegmentation/Sources/SEGContentManager.h"
#import "FirebaseSegmentation/Sources/SEGDatabaseManager.h"
#import "FirebaseSegmentation/Sources/SEGNetworkManager.h"

#import <OCMock/OCMock.h>
#import "FirebaseCore/Sources/Public/FirebaseCore/FirebaseCore.h"
#import "FirebaseInstallations/Source/Library/InstallationsIDController/FIRInstallationsIDController.h"
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FirebaseInstallations.h"

@interface SEGContentManager (ForTest)
- (instancetype)initWithDatabaseManager:databaseManager networkManager:networkManager;
@end

@interface FIRInstallations (Tests)
@property(nonatomic, readwrite, strong) FIROptions *appOptions;
@property(nonatomic, readwrite, strong) NSString *appName;

- (instancetype)initWithAppOptions:(FIROptions *)appOptions
                           appName:(NSString *)appName
         installationsIDController:(FIRInstallationsIDController *)installationsIDController
                 prefetchAuthToken:(BOOL)prefetchAuthToken;
@end

@interface FIRInstallationsAuthTokenResult (ForTest)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationTime;
@end

@interface SEGContentManagerTests : XCTestCase
@property(nonatomic) SEGContentManager *contentManager;
@property(nonatomic) id networkManagerMock;
@property(nonatomic) id mockIDController;
@property(nonatomic) FIROptions *appOptions;
@property(readonly) NSString *firebaseAppName;
@property(strong, readonly, nonatomic) id mockInstallations;

@end

@implementation SEGContentManagerTests

- (void)setUp {
  // Setup FIRApp.
  _firebaseAppName = @"my-firebase-app-id";
  XCTAssertNoThrow([FIRApp configureWithName:self.firebaseAppName options:[self FIRAppOptions]]);

  // Installations Mock
  NSString *FID = @"fid-is-better-than-iid";
  _mockInstallations = OCMClassMock([FIRInstallations class]);
  OCMStub([_mockInstallations installationsWithApp:[FIRApp appNamed:self.firebaseAppName]])
      .andReturn(_mockInstallations);
  FIRInstallationsAuthTokenResult *FISToken =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fake-fis-token" expirationDate:nil];
  OCMStub([_mockInstallations
      installationIDWithCompletion:([OCMArg invokeBlockWithArgs:FID, [NSNull null], nil])]);
  OCMStub([_mockInstallations
      authTokenWithCompletion:([OCMArg invokeBlockWithArgs:FISToken, [NSNull null], nil])]);

  // Mock the network manager.
  self.networkManagerMock = OCMClassMock([SEGNetworkManager class]);
  OCMStub([self.networkManagerMock
      makeAssociationRequestToBackendWithData:[OCMArg any]
                                        token:[OCMArg any]
                                   completion:([OCMArg
                                                  invokeBlockWithArgs:@YES, [NSNull null], nil])]);

  // Initialize the content manager.
  self.contentManager =
      [[SEGContentManager alloc] initWithDatabaseManager:[SEGDatabaseManager sharedInstance]
                                          networkManager:self.networkManagerMock];
}

- (void)tearDown {
  [self.networkManagerMock stopMocking];
  self.networkManagerMock = nil;
  self.contentManager = nil;
  self.mockIDController = nil;
}

// Associate a fake custom installation id and fake firebase installation id.
// TODO(mandard): check for result and add more tests.
- (void)testAssociateCustomInstallationIdentifierSuccessfully {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"associateCustomInstallation for contentmanager"];
  [_contentManager
      associateCustomInstallationIdentiferNamed:@"my-custom-id"
                                    firebaseApp:self.firebaseAppName
                                     completion:^(BOOL success, NSDictionary *result) {
                                       XCTAssertTrue(success,
                                                     @"Could not associate custom installation ID");
                                       [expectation fulfill];
                                     }];
  [self waitForExpectationsWithTimeout:10 handler:nil];
}

#pragma mark private

- (FIROptions *)FIRAppOptions {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"correct_gcm_sender_id"];
  options.APIKey = @"AIzaSaaaaaaaaaaaaaaaaaaaaaaaaaaa1111111";
  options.projectID = @"abc-xyz-123";
  return options;
}
@end
