#import <XCTest/XCTest.h>

#import "FIRRemoteConfig+FIRApp.h"
#import "FIRRemoteConfig_Internal.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIRAppInternal.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/Private/FIROptionsInternal.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Tests/FIRTestCase.h"
#import "third_party/objective_c/ocmock/v3/Source/OCMock/OCMock.h"

@interface RCNRemoteConfig_FIRAppTest : FIRTestCase

@end

@implementation RCNRemoteConfig_FIRAppTest

- (void)setUp {
  [super setUp];
  [FIRApp resetApps];
}

- (void)testConfigureConfigWithValidInput {
  XCTAssertNoThrow([FIRApp configure]);
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertEqualObjects(rc.GMPProjectID, kGoogleAppID);
  XCTAssertEqualObjects(rc.senderID, kGCMSenderID);
}

- (void)testConfigureConfigWithEmptyGoogleAppID {
  NSDictionary *optionsDictionary = @{ kFIRGoogleAppID : @"" };
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kFIRDefaultAppName options:options];
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertThrows([rc configureConfig:app]);
}

- (void)testConfigureConfigWithNilGoogleAppID {
  NSDictionary *optionsDictionary = @{};
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kFIRDefaultAppName options:options];
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertThrows([rc configureConfig:app]);
}

- (void)testConfigureConfigWithEmptySenderID {
  NSDictionary *optionsDictionary = @{ kFIRGoogleAppID : kGoogleAppID, kFIRGCMSenderID : @"" };
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kFIRDefaultAppName options:options];
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertThrows([rc configureConfig:app]);
}

- (void)testConfigureConfigWithNilSenderID {
  NSDictionary *optionsDictionary = @{kFIRGoogleAppID : kGoogleAppID};
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  FIRApp *app = [[FIRApp alloc] initInstanceWithName:kFIRDefaultAppName options:options];
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertThrows([rc configureConfig:app]);
}

- (void)testConfigureConfigNotIntallingSenderID {
  id settingsMock = OCMClassMock([RCNConfigSettings class]);
  OCMStub([settingsMock instancesRespondToSelector:@selector(senderID)]).andReturn(NO);

  XCTAssertNoThrow([FIRApp configure]);
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertEqualObjects(rc.GMPProjectID, kGoogleAppID);
  XCTAssertEqualObjects(rc.senderID, nil);

  [settingsMock stopMocking];
}

- (void)testConfigureWithOptions {
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:966600170131:ios:a750b5ff97fbf47d"
                                  GCMSenderID:@"966600170131"];
  XCTAssertNoThrow([FIRApp configureWithOptions:options]);
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertEqualObjects(rc.GMPProjectID, @"1:966600170131:ios:a750b5ff97fbf47d");
  XCTAssertEqualObjects(rc.senderID, @"966600170131");
}

- (void)testConfigureWithMultipleProjects {
  XCTAssertNoThrow([FIRApp configure]);
  FIRRemoteConfig *rc = [FIRRemoteConfig remoteConfig];
  XCTAssertEqualObjects(rc.GMPProjectID, kGoogleAppID);
  XCTAssertEqualObjects(rc.senderID, kGCMSenderID);

  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:966600170131:ios:a750b5ff97fbf47d"
                                  GCMSenderID:@"966600170131"];
  [FIRApp configureWithName:@"nonDefault" options:options];

  XCTAssertEqualObjects(rc.GMPProjectID, kGoogleAppID);
  XCTAssertEqualObjects(rc.senderID, kGCMSenderID);
}

@end
