/*
 * Copyright 2018 Google
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
 * @file FIRDynamicLink.h
 * @abstract Dynamic Link object used in Firebase Dynamic Links.
 */

/**
 * @abstract The match type of the Dynamic Link.
 */
typedef NS_ENUM(NSUInteger, FIRDLMatchType) {
  /**
   * The match has not been achieved.
   */
  FIRDLMatchTypeNone,
  /**
   * The match between the Dynamic Link and this device may not be perfect, hence you should not
   *    reveal any personal information related to the Dynamic Link.
   */
  FIRDLMatchTypeWeak,
  /**
   * The match between the Dynamic Link and this device has high confidence but small possibility of
   *    error still exist.
   */
  FIRDLMatchTypeDefault,
  /**
   * The match between the Dynamic Link and this device is exact, hence you may reveal personal
   *     information related to the Dynamic Link.
   */
  FIRDLMatchTypeUnique,
} NS_SWIFT_NAME(DLMatchType);

/**
 * @class FIRDynamicLink
 * @abstract A received Dynamic Link.
 */
NS_SWIFT_NAME(DynamicLink)
@interface FIRDynamicLink : NSObject

/**
 * @property url
 * @abstract The URL that was passed to the app.
 */
@property(nonatomic, copy, readonly, nullable) NSURL *url;

/**
 * @property matchType
 * @abstract The match type of the received Dynamic Link.
 */
@property(nonatomic, assign, readonly) FIRDLMatchType matchType;

/**
 * @property utmParametersDictionary
 * @abstract UTM parameters associated with a Firebase Dynamic Link.
 */
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *utmParametersDictionary;

/**
 * @property minimumAppVersion
 * @abstract The minimum iOS application version that supports the Dynamic Link. This is retrieved
 *     from the imv= parameter of the Dynamic Link URL. Note: This is not the minimum iOS system
 *     version, but the minimum app version. If app version of the opening app is less than the
 *     value of this property, then app expected to open AppStore to allow user to download most
 *     recent version. App can notify or ask user before opening AppStore.
 */
@property(nonatomic, copy, readonly, nullable) NSString *minimumAppVersion;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
