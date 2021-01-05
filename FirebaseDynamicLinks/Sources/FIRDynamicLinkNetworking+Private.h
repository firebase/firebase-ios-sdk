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

#import "FirebaseDynamicLinks/Sources/FIRDynamicLinkNetworking.h"

NS_ASSUME_NONNULL_BEGIN

/** The key for the DL URL. */
FOUNDATION_EXPORT NSString *const kFDLResolvedLinkDeepLinkURLKey;
/** The key for the mininum iOS app version. */
FOUNDATION_EXPORT NSString *const kFDLResolvedLinkMinAppVersionKey;

// Private interface for testing.
@interface FIRDynamicLinkNetworking ()

/**
 * @method executeOnePlatformRequest:forURL:eventString:completionHandler:
 * @abstract Creates and sends a OnePlatform HTTP request. Also adds the necessary header.
 * @param requestBody The body of the request. Values may be added to this.
 * @param requestURLString The URL to which to send the request.
 * @param handler A block to be executed upon completion. Guaranteed to be called, but not
 *     always on the main thread.
 */
- (void)executeOnePlatformRequest:(NSDictionary *)requestBody
                           forURL:(NSString *)requestURLString
                completionHandler:(FIRNetworkRequestCompletionHandler)handler;

@end

/** Encodes the API key in a query parameter string. */
NSString *_Nullable FIRDynamicLinkAPIKeyParameter(NSString *apiKey);

/** Creates and returns an NSData object from an NSDictionary along with any error. */
NSData *_Nullable FIRDataWithDictionary(NSDictionary *dictionary, NSError **_Nullable error);

NS_ASSUME_NONNULL_END
