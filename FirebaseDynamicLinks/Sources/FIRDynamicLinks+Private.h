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

#import "FirebaseDynamicLinks/Sources/Public/FirebaseDynamicLinks/FIRDynamicLinks.h"

@class UIViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * The version of the Firebase Dynamic Link Service SDK.
 */
FOUNDATION_EXPORT NSString *const kFIRDLVersion;

/**
 * Exposed for Unit Tests usage.
 */
FOUNDATION_EXPORT NSString *const kFIRDLReadDeepLinkAfterInstallKey;

@interface FIRDynamicLinks (Private)

/**
 * @abstract Internal method to return is automatic retrieval of dynamic link enabled or not.
 *    To be used for internal purposes.
 */
+ (BOOL)isAutomaticRetrievalEnabled;

/**
 * @property APIKey
 * @abstract API Key for API access.
 */
@property(nonatomic, copy, readonly) NSString *APIKey;

/**
 * @property URLScheme
 * @abstract Custom URL scheme.
 */
@property(nonatomic, copy, readonly, nullable) NSString *URLScheme;

@end

NS_ASSUME_NONNULL_END
