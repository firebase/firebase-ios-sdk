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
#import <XCTest/XCTest.h>

#import "FirebaseAppCheck/Sources/DebugProvider/FIRAppCheckDebugTokenConfigStore.h"

static NSString *const kAppID = @"1:248211933065:ios:91feeddd848ff1a48f0358";

// The host config store can only be read from a Simulator; elsewhere the lookup is compiled out.
#if TARGET_OS_SIMULATOR

static NSString *const kOtherAppID = @"1:248211933065:android:0123456789abcdef012345";
static NSString *const kToken = @"29d93e77-7bea-4f2a-b6ed-c1d1db892666";

@interface FIRAppCheckDebugTokenConfigStore (Tests)

+ (BOOL)isMissingConfigStoreError:(nullable NSError *)error;

@end

@interface FIRAppCheckDebugTokenConfigStoreTests : XCTestCase

/// A temporary directory standing in for the host user's home directory.
@property(nonatomic) NSURL *hostHomeURL;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *environment;

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

- (void)testDebugTokenWhenConfigStoreIsEmptyObject {
  [self writeConfigStoreContents:@"{}"];

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

- (void)testDebugTokenWhenTopLevelJSONIsAnArray {
  [self writeConfigStoreContents:@"[{\"tokens\": {}}]"];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenTokenIsNull {
  [self writeConfigStoreTokens:@{kAppID : [NSNull null]}];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenSimulatorHostHomeHasTrailingSlash {
  [self writeConfigStoreTokens:@{kAppID : kToken}];
  NSDictionary<NSString *, NSString *> *environment =
      @{@"SIMULATOR_HOST_HOME" : [self.hostHomeURL.path stringByAppendingString:@"/"]};

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:environment];

  XCTAssertEqualObjects(token, kToken);
}

- (void)testDebugTokenWhenConfigStorePathIsADirectory {
  NSURL *directoryURL =
      [self.hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath
                                        isDirectory:YES];
  NSError *error;
  XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:directoryURL
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:&error],
                @"%@", error);

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

- (void)testDebugTokenWhenConfigStoreParentIsAFile {
  // `~/.config` is a regular file, so the config store cannot exist; treated like a missing file.
  [self writeEmptyFileAtRelativePath:@".config"];

  NSString *token = [FIRAppCheckDebugTokenConfigStore debugTokenForGoogleAppID:kAppID
                                                                   environment:self.environment];

  XCTAssertNil(token);
}

#pragma mark - Missing config store errors

- (void)testMissingFileIsMissingConfigStoreError {
  NSError *error = [self configStoreReadError];

  XCTAssertTrue([FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:error], @"%@", error);
}

- (void)testConfigParentFileIsMissingConfigStoreError {
  [self writeEmptyFileAtRelativePath:@".config"];

  NSError *error = [self configStoreReadError];

  XCTAssertTrue([FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:error], @"%@", error);
}

- (void)testConfigstoreParentFileIsMissingConfigStoreError {
  [self writeEmptyFileAtRelativePath:@".config/configstore"];

  NSError *error = [self configStoreReadError];

  XCTAssertTrue([FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:error], @"%@", error);
}

- (void)testDirectoryAtConfigStorePathIsNotMissingConfigStoreError {
  NSURL *directoryURL =
      [self.hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath
                                        isDirectory:YES];
  NSError *createError;
  XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtURL:directoryURL
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:&createError],
                @"%@", createError);

  NSError *error = [self configStoreReadError];

  XCTAssertFalse([FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:error], @"%@", error);
}

- (void)testUnreadableConfigStoreIsNotMissingConfigStoreError {
  [self writeConfigStoreTokens:@{kAppID : kToken}];
  NSString *path =
      [self.hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath]
          .path;
  NSError *attributesError;
  XCTAssertTrue([[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions : @0}
                                                 ofItemAtPath:path
                                                        error:&attributesError],
                @"%@", attributesError);

  NSError *error = [self configStoreReadError];

  XCTAssertFalse([FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:error], @"%@", error);
}

- (void)testNilIsNotMissingConfigStoreError {
  XCTAssertFalse([FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:nil]);
}

- (void)testNonErrorUnderlyingValueIsNotMissingConfigStoreError {
  NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                       code:NSFileReadUnknownError
                                   userInfo:@{NSUnderlyingErrorKey : @"not an error"}];

  BOOL isMissing = [FIRAppCheckDebugTokenConfigStore isMissingConfigStoreError:error];

  XCTAssertFalse(isMissing);
}

#pragma mark - Error helpers

/// Writes an empty regular file at `relativePath` under the temporary host home.
- (void)writeEmptyFileAtRelativePath:(NSString *)relativePath {
  NSURL *fileURL = [self.hostHomeURL URLByAppendingPathComponent:relativePath isDirectory:NO];
  NSError *error;
  XCTAssertTrue(
      [[NSFileManager defaultManager] createDirectoryAtURL:fileURL.URLByDeletingLastPathComponent
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&error],
      @"%@", error);
  XCTAssertTrue([@"" writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error],
                @"%@", error);
}

/// Reads the config store file under the temporary host home the same way the config store does,
/// and returns the resulting error.
- (nullable NSError *)configStoreReadError {
  NSURL *fileURL =
      [self.hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath
                                        isDirectory:NO];
  NSError *error;
  NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
  XCTAssertNil(data);
  XCTAssertNotNil(error);
  return error;
}

@end

#else  // TARGET_OS_SIMULATOR

@interface FIRAppCheckDebugTokenConfigStoreTests : XCTestCase
@end

@implementation FIRAppCheckDebugTokenConfigStoreTests

- (void)testDebugTokenIsNilOutsideSimulator {
  // Seed a valid config store so a `nil` result proves the lookup is compiled out rather than
  // failing to find the file.
  NSURL *hostHomeURL = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
      URLByAppendingPathComponent:[NSUUID UUID].UUIDString
                      isDirectory:YES];
  NSURL *fileURL =
      [hostHomeURL URLByAppendingPathComponent:FIRAppCheckDebugTokenConfigStore.relativePath
                                   isDirectory:NO];
  NSError *error;
  XCTAssertTrue(
      [[NSFileManager defaultManager] createDirectoryAtURL:fileURL.URLByDeletingLastPathComponent
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&error],
      @"%@", error);
  [self addTeardownBlock:^{
    [[NSFileManager defaultManager] removeItemAtURL:hostHomeURL error:nil];
  }];
  NSString *contents = [NSString stringWithFormat:@"{\"tokens\": {\"%@\": \"token\"}}", kAppID];
  XCTAssertTrue([contents writeToURL:fileURL
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:&error],
                @"%@", error);

  NSString *token = [FIRAppCheckDebugTokenConfigStore
      debugTokenForGoogleAppID:kAppID
                   environment:@{@"SIMULATOR_HOST_HOME" : hostHomeURL.path}];

  XCTAssertNil(token);
}

@end

#endif  // TARGET_OS_SIMULATOR
