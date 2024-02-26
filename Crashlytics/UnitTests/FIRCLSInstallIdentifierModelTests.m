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

#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"

#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/FIRCLSUserDefaults/FIRCLSUserDefaults.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

static NSString *const FABInstallationUUIDKey = @"com.crashlytics.iuuid";
static NSString *const FABInstallationADIDKey = @"com.crashlytics.install.adid";
static NSString *const FIRCLSInstallationIIDHashKey = @"com.crashlytics.install.iid";

static NSString *const FIRCLSTestHashOfInstanceID =
    @"ed0cf273a55b731a50c3356e8c5a9887b96e7a1a7b233967bff23676bcea896d";
static NSString *const FIRCLSTestHashOfTestInstanceID =
    @"a5da68191a6ce5247c37b6dc93775891b3c4fc183d9c84f7a1c8670e680b9cd4";

@interface FIRCLSInstallIdentifierModelTests : XCTestCase {
  FIRCLSUserDefaults *_defaults;
}
@end

@implementation FIRCLSInstallIdentifierModelTests

- (void)setUp {
  _defaults = [FIRCLSUserDefaults standardUserDefaults];
  [_defaults removeObjectForKey:FABInstallationUUIDKey];
  [_defaults removeObjectForKey:FABInstallationADIDKey];
  [_defaults removeObjectForKey:FIRCLSInstallationIIDHashKey];
}

- (void)tearDown {
  [_defaults removeObjectForKey:FABInstallationUUIDKey];
  [_defaults removeObjectForKey:FABInstallationADIDKey];
  [_defaults removeObjectForKey:FIRCLSInstallationIIDHashKey];
}

- (void)testCreateUUID {
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];

  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
}

- (void)testCreateUUIDAndRotate {
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];

  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  sleep(1);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  XCTAssertFalse(didRotate);
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(FIRCLSTestHashOfTestInstanceID,
                        [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testCreateUUIDAndErrorGettingInstanceID {
  NSError *fakeError = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{}];
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithError:fakeError];

  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];

  XCTAssertFalse(didRotate);
  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(nil, [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testCreateUUIDNoIID {
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:nil];

  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(nil, [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testIIDBecomesNil {
  // Set up the initial state with a valid iid and uuid.
  [_defaults setObject:@"old_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:@"old_instance_id" forKey:FIRCLSInstallationIIDHashKey];

  // Initialize the model with the a nil IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:nil];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  // Test that the UUID did not change. The FIID can be nil if
  // there's no FIID cached, so we can't say whether to regenerate
  XCTAssertEqualObjects(model.installID, @"old_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
}

- (void)testIIDChanges {
  // Set up the initial state with a valid iid and uuid.
  [_defaults setObject:@"old_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:@"old_instance_id" forKey:FIRCLSInstallationIIDHashKey];

  // Initialize the model with the a new IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"new_instance_id"];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertTrue(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  // Test that the UUID changed.
  XCTAssertNotEqualObjects(model.installID, @"old_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(FIRCLSTestHashOfInstanceID,
                        [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testIIDDoesntChange {
  // Set up the initial state with a valid iid and uuid.
  [_defaults setObject:@"test_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:FIRCLSTestHashOfTestInstanceID forKey:FIRCLSInstallationIIDHashKey];

  // Initialize the model with the a new IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertFalse(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  // Test that the UUID changed.
  XCTAssertEqualObjects(model.installID, @"test_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(FIRCLSTestHashOfTestInstanceID,
                        [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testUUIDSetButNeverIIDNilIID {
  // Set up the initial state with a valid iid and uuid.
  [_defaults setObject:@"old_uuid" forKey:FABInstallationUUIDKey];

  // Initialize the model with the a nil IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:nil];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertFalse(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  // Test that the UUID did not change. The FIID can be nil if
  // there's no FIID cached, so we can't say whether to regenerate
  XCTAssertEqualObjects(model.installID, @"old_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects([_defaults objectForKey:FIRCLSInstallationIIDHashKey], nil);
}

- (void)testUUIDSetButNeverIIDWithIID {
  // Set up the initial state with a valid iid and uuid.
  [_defaults setObject:@"old_uuid" forKey:FABInstallationUUIDKey];

  // Initialize the model with the a nil IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertFalse(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  // Test that the UUID did not change. The FIID can be nil if
  // there's no FIID cached, so we can't say whether to regenerate
  XCTAssertEqualObjects(model.installID, @"old_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects([_defaults objectForKey:FIRCLSInstallationIIDHashKey],
                        FIRCLSTestHashOfTestInstanceID);
}

- (void)testADIDWasSetButNeverIID {
  // Set up the initial state with a valid adid and uuid.
  [_defaults setObject:@"test_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:@"test_adid" forKey:FABInstallationADIDKey];

  // Initialize the model with the a new IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:nil];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertFalse(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);

  // Test that the UUID didn't change.
  XCTAssertEqualObjects(model.installID, @"test_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertNil([_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testADIDWasSetAndIIDBecomesSet {
  // Set up the initial state with a valid adid and uuid.
  [_defaults setObject:@"test_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:@"test_adid" forKey:FABInstallationADIDKey];

  // Initialize the model with the a new IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertFalse(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  // Test that the UUID didn't change.
  XCTAssertEqualObjects(model.installID, @"test_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(FIRCLSTestHashOfTestInstanceID,
                        [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testADIDAndIIDWereSet {
  // Set up the initial state with a valid iid, adid, and uuid.
  [_defaults setObject:@"test_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:@"test_adid" forKey:FABInstallationADIDKey];
  [_defaults setObject:FIRCLSTestHashOfTestInstanceID forKey:FIRCLSInstallationIIDHashKey];

  // Initialize the model with the a new IID.
  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertFalse(didRotate);

  // Test that the UUID didn't change.
  XCTAssertEqualObjects(model.installID, @"test_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(FIRCLSTestHashOfTestInstanceID,
                        [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

- (void)testADIDAndIIDWereSet2 {
  // Set up the initial state with a valid iid, adid, and uuid.
  [_defaults setObject:@"test_uuid" forKey:FABInstallationUUIDKey];
  [_defaults setObject:@"test_adid" forKey:FABInstallationADIDKey];
  [_defaults setObject:FIRCLSTestHashOfTestInstanceID forKey:FIRCLSInstallationIIDHashKey];

  // Initialize the model with the a new IID.
  FIRMockInstallations *iid =
      [[FIRMockInstallations alloc] initWithFID:@"test_changed_instance_id"];
  FIRCLSInstallIdentifierModel *model =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
  XCTAssertNotNil(model.installID);

  BOOL didRotate = [model
      regenerateInstallIDIfNeededWithBlock:^(NSString *_Nonnull fiid, NSString *_Nonnull authToken){
      }];
  XCTAssertTrue(didRotate);

  XCTAssertTrue(iid.authTokenFinished);
  XCTAssertTrue(iid.installationIDFinished);
  // Test that the UUID change.
  XCTAssertNotEqualObjects(model.installID, @"test_uuid");
  XCTAssertEqualObjects([_defaults objectForKey:FABInstallationUUIDKey], model.installID);
  XCTAssertNil([_defaults objectForKey:FABInstallationADIDKey]);
  XCTAssertEqualObjects(@"f1e1e3969cd926d57448fcd02f6fd4e979739a87256a652a1781cfa0510408b3",
                        [_defaults objectForKey:FIRCLSInstallationIIDHashKey]);
}

@end
