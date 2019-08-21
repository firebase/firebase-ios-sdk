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

#import "RCNConfigSettings.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FIRNamespaceGooglePlayPlatform;
extern NSString *const RCNTestsFIRNamespace;
extern NSString *const RCNTestsPerfNamespace;
extern NSString *const RCNTestsDefaultFIRAppName;
extern NSString *const RCNTestsSecondFIRAppName;

@interface RCNTestUtilities : NSObject

/// Fake a fetch response with a given dictionary of namespace to config and their fetch status
/// accordingly.
/// @param namespaceToConfig  Dictionary of namespace to a dictionary of config key value pairs.
/// @param statusArray        Response update status for each namespace in namespaceToConfig.
+ (NSMutableDictionary<NSString *, NSString *> *)
    responseWithNamespaceToConfig:(NSDictionary<NSString *, NSDictionary *> *)namespaceToConfig
                      statusArray:(NSArray *)statusArray;

/// Fake an internal metadata array with a given dictionary for a fake response.
///
/// @param aDictionary  Dictionary with content to mock an internal metadata array.
+ (NSMutableArray *)entryArrayWithKeyValuePair:(NSDictionary *)aDictionary;

/// Returns the name of the test that's compatible with configuring a FIRApp name to ensure
/// uniqueness. `testName` is the `name` property of the `XCTest` running.
+ (NSString *)generatedTestAppNameForTest:(NSString *)testName;

/// Creates a new path for a test database.
+ (NSString *)remoteConfigPathForTestDatabase;

/// Creates a new suite name for a test userdefaults suite.
+ (NSString *)userDefaultsSuiteNameForTestSuite;

/// Deletes the database at a given path.
+ (void)removeDatabaseAtPath:(NSString *)DBPath;

@end

NS_ASSUME_NONNULL_END
