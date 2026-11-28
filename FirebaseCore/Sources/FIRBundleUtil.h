/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * This class provides utilities for accessing resources in bundles.
 */
@interface FIRBundleUtil : NSObject

/**
 * Finds all relevant bundles, starting with [NSBundle mainBundle].
 */
+ (NSArray *)relevantBundles;

/**
 * For tests only. Replaces the bundles returned by `relevantBundles`, or restores the default
 * bundles when `bundles` is nil.
 */
+ (void)setRelevantBundlesForTesting:(nullable NSArray<NSBundle *> *)bundles;

/**
 * Whether the code runs in an app extension. Returns `+[GULAppEnvironmentUtil isAppExtension]`
 * unless a test overrode it with `setIsAppExtensionForTesting:`. FIRApp uses this too, so tests
 * override the environment in one place.
 */
+ (BOOL)isAppExtension;

/**
 * For tests only. Overrides `isAppExtension` with a boolean `NSNumber`, or restores the real
 * environment when `isAppExtension` is nil.
 */
+ (void)setIsAppExtensionForTesting:(nullable NSNumber *)isAppExtension;

/**
 * Reads the options dictionary from one of the provided bundles.
 *
 * @param resourceName The resource name, e.g. @"GoogleService-Info".
 * @param fileType The file type (extension), e.g. @"plist".
 * @param bundles The bundles to expect, in priority order. See also
 * +[FIRBundleUtil relevantBundles].
 */
+ (nullable NSString *)optionsDictionaryPathWithResourceName:(NSString *)resourceName
                                                 andFileType:(NSString *)fileType
                                                   inBundles:(NSArray *)bundles;

/**
 * Finds URL schemes defined in all relevant bundles, starting with those from
 * [NSBundle mainBundle].
 */
+ (NSArray *)relevantURLSchemes;

/**
 * Checks if any of the given bundles have a matching bundle identifier prefix (removing extension
 * suffixes).
 */
+ (BOOL)hasBundleIdentifierPrefix:(NSString *)bundleIdentifier inBundles:(NSArray *)bundles;

@end

NS_ASSUME_NONNULL_END
