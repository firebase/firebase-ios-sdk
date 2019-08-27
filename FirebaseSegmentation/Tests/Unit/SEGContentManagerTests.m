//
//  SEGContentManagerTests.m
//  FirebaseSegmentation-Unit-unit
//
//  Created by Mandar Deolalikar on 7/31/19.
//

#import <XCTest/XCTest.h>

#import "SEGContentManager.h"
#import "SEGNetworkManager.h"

#import <FirebaseInstanceID/FIRInstanceID.h>
#import <OCMock/OCMock.h>

@interface SEGContentManager (ForTest)
- (instancetype)initWithFIROptions:(FIROptions *)options;
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
  _contentManager = [[SEGContentManager alloc] initWithFIROptions:options];
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

@end
