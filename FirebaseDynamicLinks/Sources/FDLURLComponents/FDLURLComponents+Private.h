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

#import "FirebaseDynamicLinks/Sources/Public/FirebaseDynamicLinks/FDLURLComponents.h"

/**
 * Label exceptions from FDL.
 */
FOUNDATION_EXPORT NSString *_Nonnull const kFirebaseDurableDeepLinkErrorDomain;

NS_ASSUME_NONNULL_BEGIN

/// Each of the parameter classes used in FIRDynamicLinkURLComponents needs to be able to
/// provide a dictionary representation of itself to be codified into URL query parameters. This
/// protocol defines that behavior.
@protocol FDLDictionaryRepresenting <NSObject>
@required
@property(nonatomic, readonly) NSDictionary<NSString *, NSString *> *dictionaryRepresentation;
@end

@interface FIRDynamicLinkGoogleAnalyticsParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkIOSParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkItunesConnectAnalyticsParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkAndroidParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkSocialMetaTagParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkNavigationInfoParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkOtherPlatformParameters () <FDLDictionaryRepresenting>
@end

@interface FIRDynamicLinkComponents ()

/// Creates and returns a request based on the url and options. Exposed for testing.
+ (NSURLRequest *)shorteningRequestForLongURL:(NSURL *)url
                                      options:(nullable FIRDynamicLinkComponentsOptions *)options;

/// Sends an HTTP request using NSURLSession. Exposed for testing.
+ (void)sendHTTPRequest:(NSURLRequest *)request
             completion:(void (^)(NSData *_Nullable data, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
