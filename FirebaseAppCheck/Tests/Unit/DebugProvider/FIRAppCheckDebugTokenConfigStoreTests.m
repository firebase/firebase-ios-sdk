/*
 * Copyright 2026 Google LLC
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

#import <TargetConditionals.h>

// The host config store can only be read from the iOS Simulator; elsewhere the lookup is
// compiled out, so there is nothing to test.
#if TARGET_OS_SIMULATOR

#import <XCTest/XCTest.h>

#import "FirebaseAppCheck/Sources/DebugProvider/FIRAppCheckDebugTokenConfigStore.h"

static NSString *const kAppID = @"1:248211933065:ios:91feeddd848ff1a48f0358";
static NSString *const kOtherAppID = @"1:248211933065:android:0123456789abcdef012345";
static NSString *const kToken = @"29d93e77-7bea-4f2a-b6ed-c1d1db892666";

@interface FIRAppCheckDebugTokenConfigStoreTests : XCTestCase

/// A temporary directory standing in for the host user's home directory.
@property(nonatomic) NSURL *hostHomeURL;
@property(nonatomic) NSDictionary<NSString *, NSString *> *environment;

@end

@implementation FIRAppCheckDebugTokenConfigStoreTests

- (void)setUp {
  [super setUp];
  NSString *directoryName = [NSString
      stringWithFormat:@"%@-%@", NSStringFromClass([self class]), [NSUUID UUID].UUIDString];
  self.hostHomeURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()
                                 isDirectory:YES] URLByAppendingPathComponent:directoryName
                                                                  isDirectory:YES];
  NSError *error;
  XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:self.hostHomeURL
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:&error],
                @"%@", error);
  self.environment = @{@"SIMULATOR_HOST_HOME" : self.hostHomeURL.path};
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtURL:self.hostHomeURL error:nil];
  [super tearDown];
}

#pragma mark - Helpers

- (void)writeConfigStoreContents:(NSString *)contents {
  NSURL *fileURL =
      [self.hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath];
  NSError *error;
  XCTAssertTrue(
      [[NSFileManager defaultManager] createDirectoryAtURL:fileURL.URLByDeletingLastPathComponent
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&error],
      @"%@", error);
  XCTAssertTrue([contents writeToURL:fileURL
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:&error],
                @"%@", error);
}

- (void)writeConfigStoreTokens:(NSDictionary<NSString *, id> *)tokens {
  NSDictionary *json = @{
    @"_comment" : @"This file contains secrets and should not be committed to source repositories",
    @"tokens" : tokens,
  };
  NSError *error;
  NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
  XCTAssertNotNil(data, @"%@", error);
  [self writeConfigStoreContents:[[NSString alloc] initWithData:data
                                                       encoding:NSUTF8StringEncoding]];
}

#pragma mark - Tests

- (void)testRelativePath {
  XCTAssertEqualObjects(FIRAppCheckDebugTokenConfigStore.relativePath,
                        @".config/configstore/firebase-appcheck.json");
}

- (void)testDebugTokenForAppInConfigStore {
  [self writeConfigStoreTokens:@{kAppID : kToken, kOtherAppID : @"other-token"}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertEqualObjects(token, kToken);
}

- (void)testDebugTokenForAppMissingFromConfigStore {
  [self writeConfigStoreTokens:@{kOtherAppID : @"other-token"}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenConfigStoreFileMissing {
  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenSimulatorHostHomeUnset {
  [self writeConfigStoreTokens:@{kAppID : kToken}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:@{}];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenSimulatorHostHomeEmpty {
  [self writeConfigStoreTokens:@{kAppID : kToken}];

  NSString *token =
      [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                     environment:@{@"SIMULATOR_HOST_HOME" : @""}];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenConfigStoreMalformed {
  [self writeConfigStoreContents:@"{ not json"];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenTokensNotADictionary {
  [self writeConfigStoreContents:@"{\"tokens\": [\"not\", \"a\", \"dictionary\"]}"];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenTokensKeyMissing {
  [self writeConfigStoreContents:@"{\"tokenNames\": {}}"];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenTokenNotAString {
  [self writeConfigStoreTokens:@{kAppID : @42}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenTokenEmpty {
  [self writeConfigStoreTokens:@{kAppID : @""}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenGoogleAppIDEmpty {
  [self writeConfigStoreTokens:@{kAppID : kToken}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:@""
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

@end

#endif  // TARGET_OS_SIMULATOR
