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

#import "DynamicLinks/Public/FIRDynamicLinksCommon.h"

NS_ASSUME_NONNULL_BEGIN

/** A definition for a block used by methods that are asynchronous and may produce errors. */
typedef void (^FIRDynamicLinkNetworkingErrorHandler)(NSError *_Nullable error);

/** A definition for a block used to return a pending Dynamic Link. */
typedef void (^FIRPostInstallAttributionCompletionHandler)(
    NSDictionary *_Nullable dynamicLinkParameters,
    NSString *_Nullable matchMessage,
    NSError *_Nullable error);

/** A definition for a block used to return data and errors after an asynchronous task. */
typedef void (^FIRNetworkRequestCompletionHandler)(NSData *_Nullable data,
                                                   NSError *_Nullable error);

// these enums must be in sync with google/firebase/dynamiclinks/v1/dynamic_links.proto
typedef NS_ENUM(NSInteger, FIRDynamicLinkNetworkingUniqueMatchVisualStyle) {
  // Unknown style.
  FIRDynamicLinkNetworkingUniqueMatchVisualStyleUnknown = 0,
  // Default style.
  FIRDynamicLinkNetworkingUniqueMatchVisualStyleDefault = 1,
  // Custom style.
  FIRDynamicLinkNetworkingUniqueMatchVisualStyleCustom = 2,
};

typedef NS_ENUM(NSInteger, FIRDynamicLinkNetworkingRetrievalProcessType) {
  // Unknown method.
  FIRDynamicLinkNetworkingRetrievalProcessTypeUnknown = 0,
  // iSDK performs a server lookup using default match in the background
  // when app is first-opened; no API called by developer.
  FIRDynamicLinkNetworkingRetrievalProcessTypeImplicitDefault = 1,
  // iSDK performs a server lookup by device fingerprint upon a dev API call.
  FIRDynamicLinkNetworkingRetrievalProcessTypeExplicitDefault = 2,
  // iSDK performs a unique match only if default match is found upon a dev
  // API call.
  FIRDynamicLinkNetworkingRetrievalProcessTypeOptionalUnique = 3,
};

/**
 * @fn FIRMakeHTTPRequest
 * @abstract A basic and simple network request method.
 * @param request The NSURLRequest with which to perform the network request.
 * @param completion The handler executed after the request has completed.
 */
void FIRMakeHTTPRequest(NSURLRequest *request, FIRNetworkRequestCompletionHandler completion);

/** The base of the FDL API URL, Used in AppInvites to switch prod/staging backend */
FOUNDATION_EXPORT NSString *const kApiaryRestBaseUrl;

/**
 * @class FIRDynamicLinkNetworking
 * @abstract The class used to handle all network communications for the the service.
 */
@interface FIRDynamicLinkNetworking : NSObject

/**
 * @method initWithAPIKey:clientID:URLScheme:
 * @param clientID Client ID value.
 * @param URLScheme Custom URL scheme of the app.
 * @param APIKey API Key value.
 */
- (instancetype)initWithAPIKey:(NSString *)APIKey
                      clientID:(NSString *)clientID
                     URLScheme:(NSString *)URLScheme NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 * @method resolveShortLink:URLScheme:APIKey:completion:
 * @abstract Retrieves the details of the durable link that the shortened URL represents
 * @param url A Short Dynamic Link.
 * @param completion Block to be run upon completion.
 */
- (void)resolveShortLink:(NSURL *)url
           FDLSDKVersion:(NSString *)FDLSDKVersion
              completion:(FIRDynamicLinkResolverHandler)completion;

/**
 * @method
 * retrievePendingDynamicLinkWithIOSVersion:resolutionHeight:resolutionWidth:locale:localeRaw:timezone:modelName:FDLSDKVersion:appInstallationDate:uniqueMatchVisualStyle:retrievalProcessType:handler:
 * @abstract Retrieves a pending link from the server using the supplied device info and returns it
 *    by executing the completion handler.
 */
- (void)retrievePendingDynamicLinkWithIOSVersion:(NSString *)IOSVersion
                                resolutionHeight:(NSInteger)resolutionHeight
                                 resolutionWidth:(NSInteger)resolutionWidth
                                          locale:(NSString *)locale
                                       localeRaw:(NSString *)localeRaw
                               localeFromWebView:(NSString *)localeFromWebView
                                        timezone:(NSString *)timezone
                                       modelName:(NSString *)modelName
                                   FDLSDKVersion:(NSString *)FDLSDKVersion
                             appInstallationDate:(NSDate *_Nullable)appInstallationDate
                          uniqueMatchVisualStyle:
                              (FIRDynamicLinkNetworkingUniqueMatchVisualStyle)uniqueMatchVisualStyle
                            retrievalProcessType:
                                (FIRDynamicLinkNetworkingRetrievalProcessType)retrievalProcessType
                          uniqueMatchLinkToCheck:(NSURL *)uniqueMatchLinkToCheck
                                         handler:
                                             (FIRPostInstallAttributionCompletionHandler)handler;
/**
 * @method convertInvitation:handler:
 * @abstract Marks an invitation as converted. You should call this method in your application after
 *    the user performs an action that represents a successful conversion.
 * @param invitationID The invitation ID of the link.
 * @param handler A block that is called upon completion. If successful, the error parameter will be
 *    nil. This is always executed on the main thread.
 */
- (void)convertInvitation:(NSString *)invitationID
                  handler:(nullable FIRDynamicLinkNetworkingErrorHandler)handler;

@end

NS_ASSUME_NONNULL_END
