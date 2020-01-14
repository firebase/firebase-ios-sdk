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

#import "SEGContentManager.h"
#import "SEGDatabaseManager.h"
#import "SEGNetworkManager.h"

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseInstanceID/FIRInstanceID.h>
#import <OCMock/OCMock.h>

@interface SEGContentManager (ForTest)
- (instancetype)initWithDatabaseManager:databaseManager networkManager:networkManager;
@end

@interface FIRInstanceIDResult (ForTest)
@property(nonatomic, readwrite) NSString *instanceID;
@property(nonatomic, readwrite) NSString *token;
@end

@interface FIRInstanceID (ForTest)
+ (instancetype)instanceIDForTests;
@end

@interface SEGContentManagerTests : XCTestCase {
  SEGContentManager *_contentManager;
}
@end

@implementation SEGContentManagerTests

- (void)setUp {
  // Setup FIRApp.
  XCTAssertNoThrow([FIRApp configureWithOptions:[self FIRAppOptions]]);
  // TODO (mandard): Investigate replacing the partial mock with a class mock.
  FIRInstanceID *instanceIDMock = OCMPartialMock([FIRInstanceID instanceIDForTests]);
  FIRInstanceIDResult *result = [[FIRInstanceIDResult alloc] init];
  result.instanceID = @"test-instance-id";
  result.token = @"test-instance-id-token";
  OCMStub([instanceIDMock
      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:result, [NSNull null], nil])]);

  // Mock the network manager.
  FIROptions *options = [[FIROptions alloc] init];
  options.projectID = @"test-project-id";
  options.APIKey = @"test-api-key";
  SEGNetworkManager *networkManagerMock = OCMClassMock([SEGNetworkManager class]);
  OCMStub([networkManagerMock
      makeAssociationRequestToBackendWithData:[OCMArg any]
                                        token:[OCMArg any]
                                   completion:([OCMArg
                                                  invokeBlockWithArgs:@YES, [NSNull null], nil])]);

  // Initialize the content manager.
  _contentManager =
      [[SEGContentManager alloc] initWithDatabaseManager:[SEGDatabaseManager sharedInstance]
                                          networkManager:networkManagerMock];
}
- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
}

// Associate a fake custom installation id and fake firebase installation id.
- (void)testAssociateCustomInstallationIdentifierSuccessfully {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"associateCustomInstallation for contentmanager"];
  [_contentManager
      associateCustomInstallationIdentiferNamed:@"my-custom-id"
                                    firebaseApp:@"my-firebase-app-id"
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
  options.APIKey = @"correct_api_key";
  options.projectID = @"abc-xyz-123";
  return options;
}
@end
