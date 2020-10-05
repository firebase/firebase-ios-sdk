/*
 * Copyright 2019 Google
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

#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

NSString *const RCNTestsPerfNamespace = @"fireperf";
NSString *const RCNTestsFIRNamespace = @"firebase";
NSString *const RCNTestsDefaultFIRAppName = @"__FIRAPP_DEFAULT";
NSString *const RCNTestsSecondFIRAppName = @"secondFIRApp";

/// The storage sub-directory that the Remote Config database resides in.
static NSString *const RCNRemoteConfigStorageSubDirectory = @"Google/RemoteConfig";

@implementation RCNTestUtilities

+ (NSString *)generatedTestAppNameForTest:(NSString *)testName {
  // Filter out any characters not valid for FIRApp's naming scheme.
  NSCharacterSet *invalidCharacters = [[NSCharacterSet alphanumericCharacterSet] invertedSet];

  // This will result in a string with the class name, a space, and the test name. We only care
  // about the test name so split it into components and return the last item.
  NSString *friendlyTestName = [testName stringByTrimmingCharactersInSet:invalidCharacters];
  NSArray<NSString *> *components = [friendlyTestName componentsSeparatedByString:@" "];
  return [components lastObject];
}

/// Remote Config database path for test version
+ (NSString *)remoteConfigPathForTestDatabase {
#if TARGET_OS_TV
  NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
  NSArray *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
#endif
  NSString *storageDirPath = dirPaths.firstObject;
  NSArray<NSString *> *components = @[
    storageDirPath, RCNRemoteConfigStorageSubDirectory,
    [NSString stringWithFormat:@"test-%f.sqlite3", [[NSDate date] timeIntervalSince1970] * 1000]
  ];
  NSString *dbPath = [NSString pathWithComponents:components];
  [RCNTestUtilities removeDatabaseAtPath:dbPath];
  return dbPath;
}

+ (void)removeDatabaseAtPath:(NSString *)DBPath {
  // Remove existing database if exists.
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:DBPath]) {
    NSError *error;
    [fileManager removeItemAtPath:DBPath error:&error];
  }
}

#pragma mark UserDefaults
/// Remote Config database path for test version
+ (NSString *)userDefaultsSuiteNameForTestSuite {
  NSString *suiteName =
      [NSString stringWithFormat:@"group.%@.test-%f", [NSBundle mainBundle].bundleIdentifier,
                                 [[NSDate date] timeIntervalSince1970] * 1000];
  return suiteName;
}

@end
