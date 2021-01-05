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

#import "Crashlytics/Crashlytics/FIRCLSUserDefaults/FIRCLSUserDefaults_private.h"

@interface FIRCLSUserDefaultsTests : XCTestCase {
  FIRCLSUserDefaults* _userDefaults;

  NSString* _testKey1;
  NSString* _testKey2;
  NSString* _testKey3;
  NSString* _testKey4;
  NSString* _testString1;
  NSString* _testString2;
  NSString* _testString3;
  BOOL _testBool;
  NSInteger _testInteger;
}

@end

@implementation FIRCLSUserDefaultsTests

- (void)setUp {
  _userDefaults = [FIRCLSUserDefaults standardUserDefaults];
  [_userDefaults removeAllObjects];  // we need to clear out anything stored by other unit tests.
  [_userDefaults synchronize];

  _testKey1 = @"testKey1";
  _testString1 = @"test1";
  _testKey2 = @"testKey2";
  _testString2 = @"test2";
  _testKey3 = @"testKey3";
  _testString3 = @"test3";
  _testKey4 = @"testKey4";
  _testBool = YES;
  _testInteger = 10;
  [super setUp];
}

- (void)tearDown {
  [_userDefaults removeAllObjects];
  [super tearDown];
}

#pragma mark - dictionary representation tests

- (void)testDictionaryRepresentation {
  [_userDefaults removeAllObjects];

  NSDictionary* expectedTestDict =
      [NSDictionary dictionaryWithObjectsAndKeys:_testString1, _testKey1, _testString2, _testKey2,
                                                 _testString3, _testKey3, nil];

  [_userDefaults setObject:_testString1 forKey:_testKey1];
  [_userDefaults setObject:_testString2 forKey:_testKey2];
  [_userDefaults setObject:_testString3 forKey:_testKey3];

  NSDictionary* testDict = [_userDefaults dictionaryRepresentation];
  NSLog(@"%@", testDict);

  NSLog(@"foooo");

  XCTAssertEqualObjects(testDict, expectedTestDict, @"");
}

#pragma mark - remove tests

- (void)testRemoveObjectForKey {
  [_userDefaults setObject:_testString1 forKey:_testKey1];

  [_userDefaults removeObjectForKey:_testKey1];
  XCTAssertNil([_userDefaults objectForKey:_testKey1], @"");
}

- (void)testRemoveAllObjects {
  [_userDefaults setObject:_testString1 forKey:_testKey1];
  [_userDefaults setObject:_testString2 forKey:_testKey2];
  [_userDefaults setObject:_testString3 forKey:_testKey3];

  [_userDefaults removeAllObjects];

  XCTAssertNil([_userDefaults objectForKey:_testKey1], @"");
  XCTAssertNil([_userDefaults objectForKey:_testKey2], @"");
  XCTAssertNil([_userDefaults objectForKey:_testKey3], @"");
}

#pragma mark - set/fetch object tests

- (void)testSaveObject {
  [_userDefaults setObject:_testString1 forKey:_testKey1];
  XCTAssertEqualObjects([_userDefaults objectForKey:_testKey1], _testString1, @"");
}

- (void)testSaveBool {
  [_userDefaults setObject:_testString1 forKey:_testKey1];
  XCTAssertEqualObjects([_userDefaults stringForKey:_testKey1], _testString1, @"");
}

- (void)testSaveString {
  [_userDefaults setBool:_testBool forKey:_testKey1];
  XCTAssertEqual([_userDefaults boolForKey:_testKey1], _testBool, @"");
}

- (void)testSaveInteger {
  [_userDefaults setInteger:_testInteger forKey:_testKey1];
  XCTAssertEqual([_userDefaults integerForKey:_testKey1], _testInteger, @"");
}

#pragma mark - unset/wrong type object tests

- (void)testLoadObjectUnset {
  XCTAssertNil([_userDefaults objectForKey:_testKey1], @"");
}

- (void)testLoadStringUnset {
  XCTAssertNil([_userDefaults stringForKey:_testKey1], @"");
}

- (void)testLoadStringWrongType {
  [_userDefaults setObject:[NSNumber numberWithInt:100] forKey:_testKey1];
  XCTAssertNotNil([_userDefaults objectForKey:_testKey1], @"");
  XCTAssertNil([_userDefaults stringForKey:_testKey1], @"");
}

- (void)testLoadBoolUnset {
  XCTAssertFalse([_userDefaults boolForKey:_testKey1], @"");
}

- (void)testLoadBoolWrongType {
  [_userDefaults setObject:_testString1 forKey:_testKey1];
  XCTAssertNotNil([_userDefaults objectForKey:_testKey1], @"");
  XCTAssertFalse([_userDefaults boolForKey:_testKey1], @"");
}

- (void)testLoadIntegerUnset {
  XCTAssertEqual([_userDefaults integerForKey:_testKey1], 0, @"");
}

- (void)testLoadIntegerWrongType {
  [_userDefaults setObject:_testString1 forKey:_testKey1];
  XCTAssertNotNil([_userDefaults objectForKey:_testKey1], @"");
  XCTAssertEqual([_userDefaults integerForKey:_testKey1], 0, @"");
}

#pragma mark - NSUserDefaults migration

- (void)testMigrateFromNSUserDefaults {
  [[NSUserDefaults standardUserDefaults] setObject:_testString1 forKey:_testKey1];
  [[NSUserDefaults standardUserDefaults] setObject:_testString2 forKey:_testKey2];
  [[NSUserDefaults standardUserDefaults] setBool:_testBool forKey:_testKey3];

  [[FIRCLSUserDefaults standardUserDefaults]
      migrateFromNSUserDefaults:@[ _testKey1, _testKey2, _testKey3 ]];

  XCTAssertEqualObjects([_userDefaults objectForKey:_testKey1], _testString1, @"");
  XCTAssertEqualObjects([_userDefaults stringForKey:_testKey2], _testString2, @"");
  XCTAssertEqual([_userDefaults boolForKey:_testKey3], _testBool, @"");
}

- (void)testObjectForKeyByMigratingFromNSUserDefaultsWhenKeyExistsInNSUserDefaults {
  [[NSUserDefaults standardUserDefaults] setObject:_testString1 forKey:_testKey1];

  // Read object and migrate to FIRCLSUserDefaults
  id readObject = [[FIRCLSUserDefaults standardUserDefaults]
      objectForKeyByMigratingFromNSUserDefaults:_testKey1];
  XCTAssertEqualObjects(readObject, _testString1);
  XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:_testKey1]);
  XCTAssertEqualObjects(_testString1,
                        [[FIRCLSUserDefaults standardUserDefaults] objectForKey:_testKey1]);
}

- (void)testObjectForKeyByMigratingFromNSUserDefaultsWhenKeyExistsInFIRCLSUserDefaults {
  [[FIRCLSUserDefaults standardUserDefaults] setObject:_testString1 forKey:_testKey1];
  id readObject = [[FIRCLSUserDefaults standardUserDefaults]
      objectForKeyByMigratingFromNSUserDefaults:_testKey1];
  XCTAssertEqualObjects(readObject, _testString1);
}

- (void)testObjectForKeyByMigratingFromNSUserDefaultsWhenKeyDoesNotExist {
  XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:_testKey1]);
  XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:_testKey1],
                        [[FIRCLSUserDefaults standardUserDefaults]
                            objectForKeyByMigratingFromNSUserDefaults:_testKey1]);
}

#pragma mark - Serialization tests
- (void)testSynchronize {
  [_userDefaults setBool:_testBool forKey:_testKey1];
  [_userDefaults setInteger:_testInteger forKey:_testKey4];
  [_userDefaults setObject:_testString2 forKey:_testKey2];
  [_userDefaults setObject:_testString3 forKey:_testKey3];
  [_userDefaults synchronize];

  // Tests a private method of FIRCLSUserDefaults to verify we can serialize to and from the disk
  NSDictionary* readValue = [_userDefaults loadDefaults];
  XCTAssertEqual([(NSNumber*)[readValue objectForKey:_testKey1] boolValue], _testBool, @"");
  XCTAssertEqual([[readValue objectForKey:_testKey4] integerValue], _testInteger, @"");
  XCTAssertEqualObjects([readValue objectForKey:_testKey2], _testString2, @"");
  XCTAssertEqualObjects([readValue objectForKey:_testKey3], _testString3, @"");
}

- (void)testSynchronizeOnlyWritesOnChanges {
  // test using the private synchronizeWroteToDisk method

  [_userDefaults setBool:_testBool forKey:_testKey1];
  [_userDefaults synchronize];
  XCTAssert([_userDefaults synchronizeWroteToDisk]);

  // synchronize without changes shouldn't do anything
  [_userDefaults synchronize];
  XCTAssertFalse([_userDefaults synchronizeWroteToDisk]);

  // add a new key
  [_userDefaults setObject:_testString2 forKey:_testKey2];
  [_userDefaults synchronize];
  XCTAssert([_userDefaults synchronizeWroteToDisk]);

  // change an existing key
  [_userDefaults setObject:_testString3 forKey:_testKey2];
  [_userDefaults synchronize];
  XCTAssert([_userDefaults synchronizeWroteToDisk]);

  // set an existing key to the same value
  [_userDefaults setObject:[_testString3 copy] forKey:_testKey2];
  [_userDefaults synchronize];
  XCTAssertFalse([_userDefaults synchronizeWroteToDisk]);

  // remove a key
  [_userDefaults removeObjectForKey:_testKey2];
  [_userDefaults synchronize];
  XCTAssert([_userDefaults synchronizeWroteToDisk]);

  // remove everything
  [_userDefaults removeAllObjects];
  [_userDefaults synchronize];
  XCTAssert([_userDefaults synchronizeWroteToDisk]);
}

#pragma mark - Directory URL tests
- (void)testGetDirectoryUrl {
// For the simulator, on tvOS and watchOS can't write to disk
#if TARGET_OS_SIMULATOR && TARGET_OS_IPHONE
  NSURL* baseURL = [NSURL URLWithString:@"/my/base/dir"];
  NSString* bundleId = @"com.my.bundle.id";
  NSURL* generatedURL = [_userDefaults generateDirectoryURLForBaseURL:baseURL
                                              hostAppBundleIdentifier:bundleId];
  XCTAssertEqualObjects(generatedURL, [NSURL URLWithString:@"/my/base/dir/com.crashlytics"]);

// For non-simulator, the only supported scenario is on a mac.
#elif !TARGET_OS_SIMULATOR && !TARGET_OS_EMBEDDED
  NSURL* baseURL = [NSURL URLWithString:@"/my/base/dir"];
  NSString* bundleId = @"com.my.bundle.id";
  NSURL* generatedURL = [_userDefaults generateDirectoryURLForBaseURL:baseURL
                                              hostAppBundleIdentifier:bundleId];
  XCTAssertEqualObjects(generatedURL,
                        [NSURL URLWithString:@"/my/base/dir/com.my.bundle.id/com.crashlytics"]);
#endif
}

@end
