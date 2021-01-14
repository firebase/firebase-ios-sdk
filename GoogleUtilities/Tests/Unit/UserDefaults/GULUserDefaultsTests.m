// Copyright 2018 Google
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
#import "OCMock.h"

#import "GoogleUtilities/Network/Public/GoogleUtilities/GULMutableDictionary.h"
#import "GoogleUtilities/UserDefaults/Public/GoogleUtilities/GULUserDefaults.h"

static const double sEpsilon = 0.001;

/// The maximum time to wait for an expectation before failing.
static const NSTimeInterval kGULTestCaseTimeoutInterval = 10;

@interface GULUserDefaultsThreadArgs : NSObject

/// The new user defaults to be tested on threads.
@property(atomic) GULUserDefaults *userDefaults;

/// The old user defaults to be tested on threads.
@property(atomic) NSUserDefaults *oldUserDefaults;

/// The thread index.
@property(atomic) int index;

/// The number of items to be removed/added into the dictionary per thread.
@property(atomic) int itemsPerThread;

/// The dictionary that store all the objects that the user defaults stores.
@property(atomic) GULMutableDictionary *dictionary;

@end

@implementation GULUserDefaultsThreadArgs
@end

@interface GULUserDefaultsTests : XCTestCase

@end

@implementation GULUserDefaultsTests

- (void)testNewUserDefaultsWithStandardUserDefaults {
  NSString *suiteName = @"test_suite_defaults";
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];

  NSString *key1 = @"testing";
  NSString *value1 = @"blabla";
  [newUserDefaults setObject:value1 forKey:key1];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key1], @"blabla");
  XCTAssertEqualObjects([userDefaults objectForKey:key1], @"blabla");
  XCTAssertEqualObjects([newUserDefaults stringForKey:key1], @"blabla");

  NSString *key2 = @"OtherKey";
  NSNumber *number = @(123.45);
  [newUserDefaults setDouble:123.45 forKey:key2];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key2], number);
  XCTAssertEqualWithAccuracy([newUserDefaults doubleForKey:key2], 123.45, sEpsilon);
  XCTAssertEqualObjects([userDefaults objectForKey:key2], number);

  NSString *key3 = @"ArrayKey";
  NSArray *array = @[ @1, @"Hi" ];
  [newUserDefaults setObject:array forKey:key3];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key3], array);
  XCTAssertEqualObjects([newUserDefaults arrayForKey:key3], array);
  XCTAssertEqualObjects([userDefaults objectForKey:key3], array);

  NSString *key4 = @"DictionaryKey";
  NSDictionary *dictionary = @{@"testing" : @"Hi there!"};
  [newUserDefaults setObject:dictionary forKey:key4];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key4], dictionary);
  XCTAssertEqualObjects([newUserDefaults dictionaryForKey:key4], dictionary);
  XCTAssertEqualObjects([userDefaults objectForKey:key4], dictionary);

  NSString *key5 = @"BoolKey";
  NSNumber *boolObject = @(YES);
  XCTAssertFalse([newUserDefaults boolForKey:key5]);
  XCTAssertFalse([userDefaults boolForKey:key5]);
  [newUserDefaults setObject:boolObject forKey:key5];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key5], boolObject);
  XCTAssertEqualObjects([userDefaults objectForKey:key5], boolObject);
  XCTAssertTrue([newUserDefaults boolForKey:key5]);
  XCTAssertTrue([userDefaults boolForKey:key5]);
  [newUserDefaults setBool:NO forKey:key5];
  XCTAssertFalse([newUserDefaults boolForKey:key5]);
  XCTAssertFalse([userDefaults boolForKey:key5]);

  NSString *key6 = @"DataKey";
  NSData *testData = [@"google" dataUsingEncoding:NSUTF8StringEncoding];
  [newUserDefaults setObject:testData forKey:key6];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key6], testData);
  XCTAssertEqualObjects([userDefaults objectForKey:key6], testData);

  NSString *key7 = @"DateKey";
  NSDate *testDate = [NSDate date];
  [newUserDefaults setObject:testDate forKey:key7];
  XCTAssertNotNil([newUserDefaults objectForKey:key7]);
  XCTAssertNotNil([userDefaults objectForKey:key7]);
  XCTAssertEqualWithAccuracy([testDate timeIntervalSinceDate:[newUserDefaults objectForKey:key7]],
                             0.0, sEpsilon);
  XCTAssertEqualWithAccuracy([testDate timeIntervalSinceDate:[userDefaults objectForKey:key7]], 0.0,
                             sEpsilon);

  NSString *key8 = @"FloatKey";
  [newUserDefaults setFloat:0.99 forKey:key8];
  XCTAssertEqualWithAccuracy([newUserDefaults floatForKey:key8], 0.99, sEpsilon);
  XCTAssertEqualWithAccuracy([userDefaults floatForKey:key8], 0.99, sEpsilon);

  // Remove all of the objects from the normal NSUserDefaults. The values from the new user
  // defaults must also be cleared!
  [userDefaults removePersistentDomainForName:suiteName];
  XCTAssertNil([userDefaults objectForKey:key1]);
  XCTAssertNil([newUserDefaults objectForKey:key1]);
  XCTAssertNil([userDefaults objectForKey:key2]);
  XCTAssertNil([newUserDefaults objectForKey:key2]);

  [newUserDefaults setObject:@"anothervalue" forKey:key1];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key1], @"anothervalue");
  XCTAssertEqualObjects([userDefaults objectForKey:key1], @"anothervalue");

  [newUserDefaults setInteger:111 forKey:key2];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key2], @111);
  XCTAssertEqual([newUserDefaults integerForKey:key2], 111);
  XCTAssertEqualObjects([userDefaults objectForKey:key2], @111);

  NSArray *array2 = @[ @2, @"Hello" ];
  [newUserDefaults setObject:array2 forKey:key3];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key3], array2);
  XCTAssertEqualObjects([newUserDefaults arrayForKey:key3], array2);
  XCTAssertEqualObjects([userDefaults objectForKey:key3], array2);

  NSDictionary *dictionary2 = @{@"testing 2" : @3};
  [newUserDefaults setObject:dictionary2 forKey:key4];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key4], dictionary2);
  XCTAssertEqualObjects([newUserDefaults dictionaryForKey:key4], dictionary2);
  XCTAssertEqualObjects([userDefaults objectForKey:key4], dictionary2);

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testNSUserDefaultsWithNewUserDefaults {
  NSString *suiteName = @"test_suite_defaults_2";
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];

  NSString *key1 = @"testing";
  NSString *value1 = @"blabla";
  [userDefaults setObject:value1 forKey:key1];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key1], @"blabla");
  XCTAssertEqualObjects([userDefaults objectForKey:key1], @"blabla");
  XCTAssertEqualObjects([newUserDefaults stringForKey:key1], @"blabla");

  NSString *key2 = @"OtherKey";
  NSNumber *number = @(123.45);
  [userDefaults setDouble:123.45 forKey:key2];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key2], number);
  XCTAssertEqualWithAccuracy([newUserDefaults doubleForKey:key2], 123.45, sEpsilon);
  XCTAssertEqualObjects([userDefaults objectForKey:key2], number);

  NSString *key3 = @"ArrayKey";
  NSArray *array = @[ @1, @"Hi" ];
  [userDefaults setObject:array forKey:key3];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key3], array);
  XCTAssertEqualObjects([newUserDefaults arrayForKey:key3], array);
  XCTAssertEqualObjects([userDefaults objectForKey:key3], array);

  NSString *key4 = @"DictionaryKey";
  NSDictionary *dictionary = @{@"testing" : @"Hi there!"};
  [userDefaults setObject:dictionary forKey:key4];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key4], dictionary);
  XCTAssertEqualObjects([newUserDefaults dictionaryForKey:key4], dictionary);
  XCTAssertEqualObjects([userDefaults objectForKey:key4], dictionary);

  NSString *key5 = @"BoolKey";
  NSNumber *boolObject = @(YES);
  XCTAssertFalse([newUserDefaults boolForKey:key5]);
  XCTAssertFalse([userDefaults boolForKey:key5]);
  [userDefaults setObject:boolObject forKey:key5];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key5], boolObject);
  XCTAssertEqualObjects([userDefaults objectForKey:key5], boolObject);
  XCTAssertTrue([newUserDefaults boolForKey:key5]);
  XCTAssertTrue([userDefaults boolForKey:key5]);
  [userDefaults setObject:@(NO) forKey:key5];
  XCTAssertFalse([newUserDefaults boolForKey:key5]);
  XCTAssertFalse([userDefaults boolForKey:key5]);

  NSString *key6 = @"DataKey";
  NSData *testData = [@"google" dataUsingEncoding:NSUTF8StringEncoding];
  [userDefaults setObject:testData forKey:key6];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key6], testData);
  XCTAssertEqualObjects([userDefaults objectForKey:key6], testData);

  NSString *key7 = @"DateKey";
  NSDate *testDate = [NSDate date];
  [userDefaults setObject:testDate forKey:key7];
  XCTAssertNotNil([newUserDefaults objectForKey:key7]);
  XCTAssertNotNil([userDefaults objectForKey:key7]);
  XCTAssertEqualWithAccuracy([testDate timeIntervalSinceDate:[newUserDefaults objectForKey:key7]],
                             0.0, sEpsilon);
  XCTAssertEqualWithAccuracy([testDate timeIntervalSinceDate:[userDefaults objectForKey:key7]], 0.0,
                             sEpsilon);

  NSString *key8 = @"FloatKey";
  [userDefaults setFloat:0.99 forKey:key8];
  XCTAssertEqualWithAccuracy([newUserDefaults floatForKey:key8], 0.99, sEpsilon);
  XCTAssertEqualWithAccuracy([userDefaults floatForKey:key8], 0.99, sEpsilon);

  // Remove all of the objects from the normal NSUserDefaults. The values from the new user
  // defaults must also be cleared!
  [userDefaults removePersistentDomainForName:suiteName];
  XCTAssertNil([userDefaults objectForKey:key1]);
  XCTAssertNil([newUserDefaults objectForKey:key1]);
  XCTAssertNil([userDefaults objectForKey:key2]);
  XCTAssertNil([newUserDefaults objectForKey:key2]);

  [userDefaults setObject:@"anothervalue" forKey:key1];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key1], @"anothervalue");
  XCTAssertEqualObjects([userDefaults objectForKey:key1], @"anothervalue");

  [userDefaults setObject:@111 forKey:key2];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key2], @111);
  XCTAssertEqual([newUserDefaults integerForKey:key2], 111);
  XCTAssertEqualObjects([userDefaults objectForKey:key2], @111);

  NSArray *array2 = @[ @2, @"Hello" ];
  [userDefaults setObject:array2 forKey:key3];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key3], array2);
  XCTAssertEqualObjects([newUserDefaults arrayForKey:key3], array2);
  XCTAssertEqualObjects([userDefaults objectForKey:key3], array2);

  NSDictionary *dictionary2 = @{@"testing 2" : @3};
  [userDefaults setObject:dictionary2 forKey:key4];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key4], dictionary2);
  XCTAssertEqualObjects([newUserDefaults dictionaryForKey:key4], dictionary2);
  XCTAssertEqualObjects([userDefaults objectForKey:key4], dictionary2);

  // Remove all of the objects from the new user defaults. The values from the NSUserDefaults must
  // also be cleared.
  [userDefaults removePersistentDomainForName:suiteName];
  XCTAssertNil([userDefaults objectForKey:key1]);
  XCTAssertNil([newUserDefaults objectForKey:key1]);
  XCTAssertNil([userDefaults objectForKey:key2]);
  XCTAssertNil([newUserDefaults objectForKey:key2]);
  XCTAssertNil([userDefaults objectForKey:key3]);
  XCTAssertNil([newUserDefaults objectForKey:key3]);
  XCTAssertNil([userDefaults objectForKey:key4]);
  XCTAssertNil([newUserDefaults objectForKey:key4]);
  XCTAssertNil([userDefaults objectForKey:key5]);
  XCTAssertNil([newUserDefaults objectForKey:key5]);
  XCTAssertNil([userDefaults objectForKey:key6]);
  XCTAssertNil([newUserDefaults objectForKey:key6]);
  XCTAssertNil([userDefaults objectForKey:key7]);
  XCTAssertNil([newUserDefaults objectForKey:key7]);
  XCTAssertNil([userDefaults objectForKey:key8]);
  XCTAssertNil([newUserDefaults objectForKey:key8]);

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testNewSharedUserDefaultsWithStandardUserDefaults {
  NSString *appDomain = [NSBundle mainBundle].bundleIdentifier;
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  GULUserDefaults *newUserDefaults = [GULUserDefaults standardUserDefaults];

  NSString *key1 = @"testing";
  NSString *value1 = @"blabla";
  [newUserDefaults setObject:value1 forKey:key1];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key1], @"blabla");
  XCTAssertEqualObjects([userDefaults objectForKey:key1], @"blabla");
  XCTAssertEqualObjects([newUserDefaults stringForKey:key1], @"blabla");

  NSString *key2 = @"OtherKey";
  NSNumber *number = @(123.45);
  [newUserDefaults setObject:number forKey:key2];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key2], number);
  XCTAssertEqualWithAccuracy([newUserDefaults doubleForKey:key2], 123.45, sEpsilon);
  XCTAssertEqualWithAccuracy([newUserDefaults floatForKey:key2], 123.45, sEpsilon);
  XCTAssertEqualObjects([userDefaults objectForKey:key2], number);

  NSString *key3 = @"ArrayKey";
  NSArray *array = @[ @1, @"Hi" ];
  [userDefaults setObject:array forKey:key3];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key3], array);
  XCTAssertEqualObjects([newUserDefaults arrayForKey:key3], array);
  XCTAssertEqualObjects([userDefaults objectForKey:key3], array);

  NSString *key4 = @"DictionaryKey";
  NSDictionary *dictionary = @{@"testing" : @"Hi there!"};
  [userDefaults setObject:dictionary forKey:key4];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key4], dictionary);
  XCTAssertEqualObjects([newUserDefaults dictionaryForKey:key4], dictionary);
  XCTAssertEqualObjects([userDefaults objectForKey:key4], dictionary);

  NSString *key5 = @"BoolKey";
  NSNumber *boolObject = @(1);
  XCTAssertFalse([newUserDefaults boolForKey:key5]);
  XCTAssertFalse([userDefaults boolForKey:key5]);
  [userDefaults setObject:boolObject forKey:key5];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key5], boolObject);
  XCTAssertEqualObjects([userDefaults objectForKey:key5], boolObject);
  XCTAssertTrue([newUserDefaults boolForKey:key5]);
  XCTAssertTrue([userDefaults boolForKey:key5]);
  [userDefaults setObject:@(0) forKey:key5];
  XCTAssertFalse([newUserDefaults boolForKey:key5]);
  XCTAssertFalse([userDefaults boolForKey:key5]);

  NSString *key6 = @"DataKey";
  NSData *testData = [@"google" dataUsingEncoding:NSUTF8StringEncoding];
  [newUserDefaults setObject:testData forKey:key6];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key6], testData);
  XCTAssertEqualObjects([userDefaults objectForKey:key6], testData);

  NSString *key7 = @"DateKey";
  NSDate *testDate = [NSDate date];
  [newUserDefaults setObject:testDate forKey:key7];
  XCTAssertNotNil([newUserDefaults objectForKey:key7]);
  XCTAssertNotNil([userDefaults objectForKey:key7]);
  XCTAssertEqualWithAccuracy([testDate timeIntervalSinceDate:[newUserDefaults objectForKey:key7]],
                             0.0, sEpsilon);
  XCTAssertEqualWithAccuracy([testDate timeIntervalSinceDate:[userDefaults objectForKey:key7]], 0.0,
                             sEpsilon);

  // Remove all of the objects from the normal NSUserDefaults. The values from the new user
  // defaults must also be cleared!
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
  XCTAssertNil([userDefaults objectForKey:key1]);
  XCTAssertNil([newUserDefaults objectForKey:key1]);
  XCTAssertNil([userDefaults objectForKey:key2]);
  XCTAssertNil([newUserDefaults objectForKey:key2]);

  [userDefaults setObject:@"anothervalue" forKey:key1];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key1], @"anothervalue");
  XCTAssertEqualObjects([userDefaults objectForKey:key1], @"anothervalue");

  [userDefaults setObject:@111 forKey:key2];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key2], @111);
  XCTAssertEqual([newUserDefaults integerForKey:key2], 111);
  XCTAssertEqualObjects([userDefaults objectForKey:key2], @111);

  NSArray *array2 = @[ @2, @"Hello" ];
  [userDefaults setObject:array2 forKey:key3];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key3], array2);
  XCTAssertEqualObjects([newUserDefaults arrayForKey:key3], array2);
  XCTAssertEqualObjects([userDefaults objectForKey:key3], array2);

  NSDictionary *dictionary2 = @{@"testing 2" : @3};
  [userDefaults setObject:dictionary2 forKey:key4];
  XCTAssertEqualObjects([newUserDefaults objectForKey:key4], dictionary2);
  XCTAssertEqualObjects([userDefaults objectForKey:key4], dictionary2);

  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
}

- (void)testUserDefaultNotifications {
  // Test to ensure no notifications are sent with our implementation.
  void (^callBlock)(NSNotification *) = ^(NSNotification *_Nonnull notification) {
    XCTFail(@"A notification must not be sent for GULUserDefaults!");
  };

  id observer =
      [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:callBlock];
  NSString *suiteName = @"test_suite_notification";
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  [newUserDefaults setObject:@"134" forKey:@"test-another"];
  XCTAssertEqualObjects([newUserDefaults objectForKey:@"test-another"], @"134");
  [newUserDefaults setObject:nil forKey:@"test-another"];
  XCTAssertNil([newUserDefaults objectForKey:@"test-another"]);
  [newUserDefaults synchronize];
  [[NSNotificationCenter defaultCenter] removeObserver:observer];

  // Remove the underlying reference file.
  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testSynchronizeToDisk {
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
  // `NSFileManager` has trouble reading the files in `~/Library` even though the
  // `removeItemAtPath:` call works. Watching Finder while stepping through this test shows that the
  // file does get created and removed properly. When using LLDB to call `fileExistsAtPath:` the
  // correct return value of `YES` is returned, but in this test it returns `NO`. Best guess is the
  // test app is sandboxed and `NSFileManager` is refusing to read the directory.
  // TODO: Investigate the failure and re-enable this test.
  return;
#endif  // TARGET_OS_OSX
  NSString *suiteName = [NSString stringWithFormat:@"another_test_suite"];
  NSString *filePath = [self filePathForPreferencesName:suiteName];
  NSFileManager *fileManager = [NSFileManager defaultManager];

  // Test the new User Defaults.
  [fileManager removeItemAtPath:filePath error:NULL];
  XCTAssertFalse([fileManager fileExistsAtPath:filePath]);

  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  [newUserDefaults setObject:@"134" forKey:@"test-another"];
  [newUserDefaults synchronize];

  XCTAssertTrue([fileManager fileExistsAtPath:filePath],
                @"The user defaults file was not synchronized to disk.");

  // Now get the file directly from disk.
  XCTAssertTrue([fileManager fileExistsAtPath:filePath]);
  [newUserDefaults synchronize];

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testInvalidKeys {
  NSString *suiteName = @"test_suite_invalid_key";
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  // These mostly to make sure that we don't crash.
  [newUserDefaults setObject:@"test" forKey:nil];
  [newUserDefaults setObject:@"test" forKey:(NSString *)@123];
  [newUserDefaults setObject:@"test" forKey:@""];
  [newUserDefaults objectForKey:@""];
  [newUserDefaults objectForKey:(NSString *)@123];
  [newUserDefaults objectForKey:nil];
#pragma clang diagnostic pop

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testInvalidObjects {
  NSString *suiteName = @"test_suite_invalid_obj";
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];

  GULMutableDictionary *invalidObject = [[GULMutableDictionary alloc] init];
  [newUserDefaults setObject:invalidObject forKey:@"Key"];
  XCTAssertNil([newUserDefaults objectForKey:@"Key"]);
  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testSetNilObject {
  NSString *suiteName = @"test_suite_set_nil";
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  [newUserDefaults setObject:@"blabla" forKey:@"fine"];
  XCTAssertEqualObjects([newUserDefaults objectForKey:@"fine"], @"blabla");

  [newUserDefaults setObject:nil forKey:@"fine"];
  XCTAssertNil([newUserDefaults objectForKey:@"fine"]);

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testRemoveObject {
  NSString *suiteName = @"test_suite_remove";
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  [newUserDefaults setObject:@"blabla" forKey:@"fine"];
  XCTAssertEqualObjects([newUserDefaults objectForKey:@"fine"], @"blabla");

  [newUserDefaults removeObjectForKey:@"fine"];
  XCTAssertNil([newUserDefaults objectForKey:@"fine"]);

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testNewUserDefaultsWithNSUserDefaultsFile {
  NSString *suiteName = @"test_suite_file";

  // Create a user defaults with a key and value. This is to make sure that the new user defaults
  // also uses the same plist file.
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  XCTAssertNil([userDefaults objectForKey:@"key1"]);
  XCTAssertNil([userDefaults objectForKey:@"key2"]);
  [userDefaults setObject:@"value1" forKey:@"key1"];
  [userDefaults setObject:@"value2" forKey:@"key2"];
  [userDefaults synchronize];
  userDefaults = nil;

  // Now the new user defaults should access the same values.
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  XCTAssertEqualObjects([newUserDefaults objectForKey:@"key1"], @"value1");
  XCTAssertEqualObjects([newUserDefaults objectForKey:@"key2"], @"value2");

  // Clean up.
  [self removePreferenceFileWithSuiteName:suiteName];
}

#if !TARGET_OS_MACCATALYST
// Disable Catalyst flakes.

#pragma mark - Thread-safety test

- (void)testNewUserDefaultsThreadSafeAddingObjects {
  NSString *suiteName = @"test_adding_threadsafe";
  int itemCount = 100;
  int itemsPerThread = 10;
  GULUserDefaults *userDefaults = [[GULUserDefaults alloc] initWithSuiteName:@"testing"];
  GULMutableDictionary *dictionary = [[GULMutableDictionary alloc] init];

  // Have 100 threads to add 100 unique keys and values into the dictionary.
  for (int threadNum = 0; threadNum < 10; threadNum++) {
    GULUserDefaultsThreadArgs *args = [[GULUserDefaultsThreadArgs alloc] init];
    args.userDefaults = userDefaults;
    args.dictionary = dictionary;
    args.itemsPerThread = itemsPerThread;
    args.index = threadNum;
    [NSThread detachNewThreadSelector:@selector(addObjectsThread:) toTarget:self withObject:args];
  }

  // Verify the size of the dictionary.
  NSPredicate *dictionarySize = [NSPredicate predicateWithFormat:@"count == %d", itemCount];
  XCTestExpectation *expectation = [self expectationForPredicate:dictionarySize
                                             evaluatedWithObject:dictionary
                                                         handler:nil];
  [self waitForExpectations:@[ expectation ] timeout:kGULTestCaseTimeoutInterval];

  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    XCTAssertEqualObjects([userDefaults objectForKey:key], @(i));
  }

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testNewUserDefaultsRemovingObjects {
  NSString *suiteName = @"test_removing_threadsafe";
  int itemCount = 100;
  GULUserDefaults *userDefaults = [[GULUserDefaults alloc] initWithSuiteName:@"testing"];
  GULMutableDictionary *dictionary = [[GULMutableDictionary alloc] init];

  // Create a dictionary of 100 unique keys and values.
  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    [userDefaults setObject:@(i) forKey:key];
    dictionary[key] = @(i);
  }

  XCTAssertEqual(dictionary.count, 100);

  // Spawn 10 threads to remove all items inside the dictionary.
  int itemsPerThread = 100;
  for (int threadNum = 0; threadNum < 10; threadNum++) {
    GULUserDefaultsThreadArgs *args = [[GULUserDefaultsThreadArgs alloc] init];
    args.userDefaults = userDefaults;
    args.dictionary = dictionary;
    args.itemsPerThread = itemsPerThread;
    args.index = threadNum;
    [NSThread detachNewThreadSelector:@selector(removeObjectsThread:)
                             toTarget:self
                           withObject:args];
  }

  // Ensure the dictionary is empty after removing objects.
  NSPredicate *emptyDictionary = [NSPredicate predicateWithFormat:@"count == 0"];
  XCTestExpectation *expectation = [self expectationForPredicate:emptyDictionary
                                             evaluatedWithObject:dictionary
                                                         handler:nil];
  [self waitForExpectations:@[ expectation ] timeout:kGULTestCaseTimeoutInterval];

  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    XCTAssertNil([userDefaults objectForKey:key]);
  }

  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testNewUserDefaultsRemovingSomeObjects {
  NSString *suiteName = @"test_remove_some_objs";
  int itemCount = 200;
  GULUserDefaults *userDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  GULMutableDictionary *dictionary = [[GULMutableDictionary alloc] init];

  // Create a dictionary of 100 unique keys and values.
  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    [userDefaults setObject:@(i) forKey:key];
    dictionary[key] = @(i);
  }

  // Spawn 10 threads to remove the first 100 items inside the dictionary.
  int itemsPerThread = 10;
  for (int threadNum = 0; threadNum < 10; threadNum++) {
    GULUserDefaultsThreadArgs *args = [[GULUserDefaultsThreadArgs alloc] init];
    args.userDefaults = userDefaults;
    args.dictionary = dictionary;
    args.itemsPerThread = itemsPerThread;
    args.index = threadNum;
    [NSThread detachNewThreadSelector:@selector(removeObjectsThread:)
                             toTarget:self
                           withObject:args];
  }

  NSPredicate *dictionarySize = [NSPredicate predicateWithFormat:@"count == 100"];
  XCTestExpectation *expectation = [self expectationForPredicate:dictionarySize
                                             evaluatedWithObject:dictionary
                                                         handler:nil];
  [self waitForExpectations:@[ expectation ] timeout:kGULTestCaseTimeoutInterval];

  // Check the remaining of the user defaults.
  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    if (i < 100) {
      XCTAssertNil([userDefaults objectForKey:key]);
    } else {
      XCTAssertEqualObjects([userDefaults objectForKey:key], @(i));
    }
  }
  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testBothUserDefaultsThreadSafeAddingObjects {
  NSString *suiteName = @"test_adding_both_user_defaults_threadsafe";
  int itemCount = 100;
  int itemsPerThread = 10;
  GULUserDefaults *newUserDefaults = [[GULUserDefaults alloc] initWithSuiteName:@"testing"];
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"testing"];
  GULMutableDictionary *dictionary = [[GULMutableDictionary alloc] init];

  // Have 100 threads to add 100 unique keys and values into the dictionary.
  for (int threadNum = 0; threadNum < 10; threadNum++) {
    GULUserDefaultsThreadArgs *args = [[GULUserDefaultsThreadArgs alloc] init];
    args.userDefaults = newUserDefaults;
    args.oldUserDefaults = userDefaults;
    args.dictionary = dictionary;
    args.itemsPerThread = itemsPerThread;
    args.index = threadNum;
    [NSThread detachNewThreadSelector:@selector(addObjectsBothUserDefaultsThread:)
                             toTarget:self
                           withObject:args];
  }

  // Verify the size of the dictionary.
  NSPredicate *dictionarySize = [NSPredicate predicateWithFormat:@"count == %d", itemCount];
  XCTestExpectation *expectation = [self expectationForPredicate:dictionarySize
                                             evaluatedWithObject:dictionary
                                                         handler:nil];
  [self waitForExpectations:@[ expectation ] timeout:kGULTestCaseTimeoutInterval];

  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    if (i % 2 == 0) {
      XCTAssertEqualObjects([newUserDefaults objectForKey:key], @(i));
    } else {
      XCTAssertEqualObjects([userDefaults objectForKey:key], @(i));
    }
  }
  [self removePreferenceFileWithSuiteName:suiteName];
}

- (void)testBothUserDefaultsRemovingSomeObjects {
  NSString *suiteName = @"test_remove_some_objs_both_user_defaults";
  int itemCount = 200;
  GULUserDefaults *userDefaults = [[GULUserDefaults alloc] initWithSuiteName:suiteName];
  NSUserDefaults *oldUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  GULMutableDictionary *dictionary = [[GULMutableDictionary alloc] init];

  // Create a dictionary of 100 unique keys and values.
  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    [userDefaults setObject:@(i) forKey:key];
    dictionary[key] = @(i);
  }

  // Spawn 10 threads to remove the first 100 items inside the dictionary.
  int itemsPerThread = 10;
  for (int threadNum = 0; threadNum < 10; threadNum++) {
    GULUserDefaultsThreadArgs *args = [[GULUserDefaultsThreadArgs alloc] init];
    args.userDefaults = userDefaults;
    args.oldUserDefaults = oldUserDefaults;
    args.dictionary = dictionary;
    args.itemsPerThread = itemsPerThread;
    args.index = threadNum;
    [NSThread detachNewThreadSelector:@selector(removeObjectsThread:)
                             toTarget:self
                           withObject:args];
  }

  // Verify the size of the dictionary.
  NSPredicate *dictionarySize = [NSPredicate predicateWithFormat:@"count == 100"];
  XCTestExpectation *expectation = [self expectationForPredicate:dictionarySize
                                             evaluatedWithObject:dictionary
                                                         handler:nil];
  [self waitForExpectations:@[ expectation ] timeout:kGULTestCaseTimeoutInterval];

  // Check the remaining of the user defaults.
  for (int i = 0; i < itemCount; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    if (i < 100) {
      if (i % 2 == 0) {
        XCTAssertNil([userDefaults objectForKey:key]);
      } else {
        XCTAssertNil([oldUserDefaults objectForKey:key]);
      }

    } else {
      if (i % 2 == 0) {
        XCTAssertEqualObjects([userDefaults objectForKey:key], @(i));
      } else {
        XCTAssertEqualObjects([oldUserDefaults objectForKey:key], @(i));
      }
    }
  }
  [self removePreferenceFileWithSuiteName:suiteName];
}
#endif  // TARGET_OS_MACCATALYST

#pragma mark - Thread methods

/// Add objects into the current GULUserDefaults given arguments.
- (void)addObjectsThread:(GULUserDefaultsThreadArgs *)args {
  int totalItemsPerThread = args.itemsPerThread + args.itemsPerThread * args.index;
  for (int i = args.index * args.itemsPerThread; i < totalItemsPerThread; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    [args.userDefaults setObject:@(i) forKey:key];
    args.dictionary[key] = @(i);
  }
}

/// Remove objects from the current GULUserDefaults given arguments.
- (void)removeObjectsThread:(GULUserDefaultsThreadArgs *)args {
  int totalItemsPerThread = args.itemsPerThread + args.itemsPerThread * args.index;
  for (int i = args.index * args.itemsPerThread; i < totalItemsPerThread; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    [args.userDefaults removeObjectForKey:key];
    [args.dictionary removeObjectForKey:key];
  }
}

/// Add objects into both user defaults given arguments.
- (void)addObjectsBothUserDefaultsThread:(GULUserDefaultsThreadArgs *)args {
  int totalItemsPerThread = args.itemsPerThread + args.itemsPerThread * args.index;
  for (int i = args.index * args.itemsPerThread; i < totalItemsPerThread; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    if (i % 2 == 0) {
      [args.userDefaults setObject:@(i) forKey:key];
    } else {
      [args.oldUserDefaults setObject:@(i) forKey:key];
    }
    args.dictionary[key] = @(i);
  }
}

/// Remove objects from both user defaults given arguments.
- (void)removeObjectsFromBothUserDefaultsThread:(GULUserDefaultsThreadArgs *)args {
  int totalItemsPerThread = args.itemsPerThread + args.itemsPerThread * args.index;
  for (int i = args.index * args.itemsPerThread; i < totalItemsPerThread; i++) {
    NSString *key = [NSString stringWithFormat:@"%d", i];
    if (i % 2 == 0) {
      [args.userDefaults removeObjectForKey:key];
    } else {
      [args.oldUserDefaults removeObjectForKey:key];
    }

    [args.dictionary removeObjectForKey:key];
  }
}

#pragma mark - Helper

- (NSString *)filePathForPreferencesName:(NSString *)preferencesName {
  if (!preferencesName.length) {
    return @"";
  }

  // User Defaults exist in the Library directory, get the path to use it as a prefix.
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
  if (!paths.lastObject) {
    XCTFail(@"Library directory not found - NSSearchPath results are empty.");
  }
  NSArray *components = @[
    paths.lastObject, @"Preferences", [preferencesName stringByAppendingPathExtension:@"plist"]
  ];
  return [NSString pathWithComponents:components];
}

- (void)removePreferenceFileWithSuiteName:(NSString *)suiteName {
  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
  [userDefaults removePersistentDomainForName:suiteName];

  NSString *path = [self filePathForPreferencesName:suiteName];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:path]) {
    XCTAssertTrue([fileManager removeItemAtPath:path error:NULL]);
  }
}

@end
