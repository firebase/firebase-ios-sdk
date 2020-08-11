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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseDynamicLinks/Sources/FIRDynamicLinkNetworking+Private.h"

#import "FirebaseDynamicLinks/Sources/GINInvocation/GINArgument.h"
#import "FirebaseDynamicLinks/Sources/GINInvocation/GINInvocation.h"
#import "FirebaseDynamicLinks/Sources/Utilities/FDLUtilities.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kApiaryRestBaseUrl = @"https://appinvite-pa.googleapis.com/v1";
static NSString *const kiOSReopenRestBaseUrl = @"https://firebasedynamiclinks.googleapis.com/v1";

// IPv4 and IPv6 Endpoints.
static NSString *const kApiaryRestBaseUrlIPV4 = @"https://appinvite-ipv4-pa.googleapis.com/v1";
static NSString *const kApiaryRestBaseUrlIPV6 = @"https://appinvite-ipv6-pa.googleapis.com/v1";

// IPv4 and IPv6 Endpoints for default retrieval process V2. (Endpoint version is V1)
static NSString *const kIosPostInstallAttributionRestBaseUrlIPV4 =
    @"https://firebasedynamiclinks-ipv4.googleapis.com/v1";
static NSString *const kIosPostInstallAttributionRestBaseUrlIPV6 =
    @"https://firebasedynamiclinks-ipv6.googleapis.com/v1";
static NSString *const kIosPostInstallAttributionRestBaseUrlUniqueMatch =
    @"https://firebasedynamiclinks.googleapis.com/v1";

static NSString *const kReasonString = @"reason";
static NSString *const kiOSInviteReason = @"ios_invite";

NSString *const kFDLResolvedLinkDeepLinkURLKey = @"deepLink";
NSString *const kFDLResolvedLinkMinAppVersionKey = @"iosMinAppVersion";
static NSString *const kFDLAnalyticsDataSourceKey = @"utmSource";
static NSString *const kFDLAnalyticsDataMediumKey = @"utmMedium";
static NSString *const kFDLAnalyticsDataCampaignKey = @"utmCampaign";
static NSString *const kHeaderIosBundleIdentifier = @"X-Ios-Bundle-Identifier";

typedef NSDictionary *_Nullable (^FIRDLNetworkingParserBlock)(
    NSString *requestURLString,
    NSData *data,
    NSString *_Nullable *_Nonnull matchMessagePtr,
    NSError *_Nullable *_Nullable errorPtr);

NSString *FIRURLParameterString(NSString *key, NSString *value) {
  if (key.length > 0) {
    return [NSString stringWithFormat:@"?%@=%@", key, value];
  }
  return @"";
}

NSString *_Nullable FIRDynamicLinkAPIKeyParameter(NSString *apiKey) {
  return apiKey ? FIRURLParameterString(@"key", apiKey) : nil;
}

void FIRMakeHTTPRequest(NSURLRequest *request, FIRNetworkRequestCompletionHandler completion) {
  NSURLSessionConfiguration *sessionConfig =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
  NSURLSessionDataTask *dataTask =
      [session dataTaskWithRequest:request
                 completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   completion(data, error);
                 }];
  [dataTask resume];
}

NSData *_Nullable FIRDataWithDictionary(NSDictionary *dictionary, NSError **_Nullable error) {
  return [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:error];
}

@implementation FIRDynamicLinkNetworking {
  NSString *_APIKey;
  NSString *_clientID;
  NSString *_URLScheme;
}

- (instancetype)initWithAPIKey:(NSString *)APIKey
                      clientID:(NSString *)clientID
                     URLScheme:(NSString *)URLScheme {
  NSParameterAssert(APIKey);
  NSParameterAssert(clientID);
  NSParameterAssert(URLScheme);
  if (self = [super init]) {
    _APIKey = [APIKey copy];
    _clientID = [clientID copy];
    _URLScheme = [URLScheme copy];
  }
  return self;
}

#pragma mark - Public interface

- (void)resolveShortLink:(NSURL *)url
           FDLSDKVersion:(NSString *)FDLSDKVersion
              completion:(FIRDynamicLinkResolverHandler)handler {
  NSParameterAssert(handler);
  if (!url) {
    handler(nil, nil);
    return;
  }

  NSDictionary *requestBody = @{
    @"requestedLink" : url.absoluteString,
    @"bundle_id" : [NSBundle mainBundle].bundleIdentifier,
    @"sdk_version" : FDLSDKVersion
  };

  FIRNetworkRequestCompletionHandler resolveLinkCallback = ^(NSData *data, NSError *error) {
    NSURL *resolvedURL;

    if (!error && data) {
      NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
      if ([result isKindOfClass:[NSDictionary class]]) {
        id invitationIDObject = [result objectForKey:@"invitationId"];

        NSString *invitationIDString;
        if ([invitationIDObject isKindOfClass:[NSDictionary class]]) {
          NSDictionary *invitationIDDictionary = invitationIDObject;
          invitationIDString = invitationIDDictionary[@"id"];
        } else if ([invitationIDObject isKindOfClass:[NSString class]]) {
          invitationIDString = invitationIDObject;
        }

        NSString *deepLinkString = result[kFDLResolvedLinkDeepLinkURLKey];
        NSString *minAppVersion = result[kFDLResolvedLinkMinAppVersionKey];
        NSString *utmSource = result[kFDLAnalyticsDataSourceKey];
        NSString *utmMedium = result[kFDLAnalyticsDataMediumKey];
        NSString *utmCampaign = result[kFDLAnalyticsDataCampaignKey];
        resolvedURL = FIRDLDeepLinkURLWithInviteID(invitationIDString, deepLinkString, utmSource,
                                                   utmMedium, utmCampaign, NO, nil, minAppVersion,
                                                   self->_URLScheme, nil);
      }
    }
    handler(resolvedURL, error);
  };

  NSString *requestURLString =
      [NSString stringWithFormat:@"%@/reopenAttribution%@", kiOSReopenRestBaseUrl,
                                 FIRDynamicLinkAPIKeyParameter(_APIKey)];
  [self executeOnePlatformRequest:requestBody
                           forURL:requestURLString
                completionHandler:resolveLinkCallback];
}

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
                                             (FIRPostInstallAttributionCompletionHandler)handler {
  NSParameterAssert(handler);

  NSMutableDictionary *requestBody = [@{
    @"bundleId" : [NSBundle mainBundle].bundleIdentifier,
    @"device" : @{
      @"screenResolutionHeight" : @(resolutionHeight),
      @"screenResolutionWidth" : @(resolutionWidth),
      @"languageCode" : locale,
      @"languageCodeRaw" : localeRaw,
      @"languageCodeFromWebview" : localeFromWebView,
      @"timezone" : timezone,
      @"deviceModelName" : modelName,
    },
    @"iosVersion" : IOSVersion,
    @"sdkVersion" : FDLSDKVersion,
    @"visualStyle" : @(uniqueMatchVisualStyle),
    @"retrievalMethod" : @(retrievalProcessType),
  } mutableCopy];
  if (appInstallationDate) {
    requestBody[@"appInstallationTime"] = @((NSInteger)[appInstallationDate timeIntervalSince1970]);
  }
  if (uniqueMatchLinkToCheck) {
    requestBody[@"uniqueMatchLinkToCheck"] = uniqueMatchLinkToCheck.absoluteString;
  }

  FIRDLNetworkingParserBlock responseParserBlock = ^NSDictionary *_Nullable(
      NSString *requestURLString, NSData *data, NSString **matchMessagePtr, NSError **errorPtr) {
    NSError *serializationError;
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:&serializationError];

    if (serializationError) {
      *errorPtr = serializationError;
      return nil;
    }

    NSString *matchMessage = result[@"matchMessage"];
    if (matchMessage.length) {
      *matchMessagePtr = matchMessage;
    }

    // Create the dynamic link parameters
    NSMutableDictionary *dynamicLinkParameters = [[NSMutableDictionary alloc] init];
    dynamicLinkParameters[kFIRDLParameterInviteId] = result[@"invitationId"];
    dynamicLinkParameters[kFIRDLParameterDeepLinkIdentifier] = result[@"deepLink"];
    if (result[@"deepLink"]) {
      dynamicLinkParameters[kFIRDLParameterMatchType] =
          FIRDLMatchTypeStringFromServerString(result[@"attributionConfidence"]);
    }
    dynamicLinkParameters[kFIRDLParameterSource] = result[@"utmSource"];
    dynamicLinkParameters[kFIRDLParameterMedium] = result[@"utmMedium"];
    dynamicLinkParameters[kFIRDLParameterCampaign] = result[@"utmCampaign"];
    dynamicLinkParameters[kFIRDLParameterMinimumAppVersion] = result[@"appMinimumVersion"];
    dynamicLinkParameters[kFIRDLParameterRequestIPVersion] = result[@"requestIpVersion"];
    dynamicLinkParameters[kFIRDLParameterMatchMessage] = matchMessage;

    return [dynamicLinkParameters copy];
  };

  // If uniqueMatch link available send to the unique match endpoint,
  // else send requests to both IPv4 and IPv6 endpoints.
  NSArray *baseURLs =
      uniqueMatchLinkToCheck ? @[ kIosPostInstallAttributionRestBaseUrlUniqueMatch ] : @[
        kIosPostInstallAttributionRestBaseUrlIPV4, kIosPostInstallAttributionRestBaseUrlIPV6
      ];
  for (NSString *baseURL in baseURLs) {
    [self sendRequestWithBaseURLString:baseURL
                           requestBody:requestBody
                          endpointPath:@"installAttribution"
                           parserBlock:responseParserBlock
                            completion:handler];
  }
}

- (void)convertInvitation:(NSString *)invitationID
                  handler:(nullable FIRDynamicLinkNetworkingErrorHandler)handler {
  if (!invitationID) {
    return;
  }

  NSDictionary *requestBody = @{
    @"invitationId" : @{@"id" : invitationID},
    @"containerClientId" : @{
      @"type" : @"IOS",
      @"id" : _clientID,
    }
  };

  FIRNetworkRequestCompletionHandler convertInvitationCallback = ^(NSData *data, NSError *error) {
    if (handler) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(error);
      });
    }
  };

  NSString *requestURL = [NSString stringWithFormat:@"%@/convertInvitation%@", kApiaryRestBaseUrl,
                                                    FIRDynamicLinkAPIKeyParameter(_APIKey)];

  [self executeOnePlatformRequest:requestBody
                           forURL:requestURL
                completionHandler:convertInvitationCallback];
}

#pragma mark - Internal methods

- (void)sendRequestWithBaseURLString:(NSString *)baseURL
                         requestBody:(NSDictionary *)requestBody
                        endpointPath:(NSString *)endpointPath
                         parserBlock:(FIRDLNetworkingParserBlock)parserBlock
                          completion:(FIRPostInstallAttributionCompletionHandler)handler {
  NSParameterAssert(handler);
  NSString *requestURLString = [NSString
      stringWithFormat:@"%@/%@%@", baseURL, endpointPath, FIRDynamicLinkAPIKeyParameter(_APIKey)];

  FIRNetworkRequestCompletionHandler completeInvitationByDeviceCallback = ^(NSData *data,
                                                                            NSError *error) {
    if (error || !data) {
      dispatch_async(dispatch_get_main_queue(), ^{
        handler(nil, nil, error);
      });
      return;
    }
    NSString *matchMessage = nil;
    NSError *parsingError = nil;
    NSDictionary *parsedDynamicLinkParameters =
        parserBlock(requestURLString, data, &matchMessage, &parsingError);

    // If request was made with pasteboard contents, verify if we got a unique match. If we got
    // a "none" match, we were unable to get a unique match or deduce using fingerprinting.
    // In this case, resend requests to IPV4 and IPV6 endpoints for fingerprinting. b/79704203
    if (requestBody[@"uniqueMatchLinkToCheck"] && parsedDynamicLinkParameters &&
        (!parsedDynamicLinkParameters[kFIRDLParameterMatchType] ||
         [parsedDynamicLinkParameters[kFIRDLParameterMatchType] isEqualToString:@"none"])) {
      NSMutableDictionary *requestBodyMutable = [requestBody mutableCopy];
      [requestBodyMutable removeObjectForKey:@"uniqueMatchLinkToCheck"];
      NSMutableArray *baseURLs =
          [@[ kIosPostInstallAttributionRestBaseUrlIPV4, kIosPostInstallAttributionRestBaseUrlIPV6 ]
              mutableCopy];
      if (parsedDynamicLinkParameters[kFIRDLParameterRequestIPVersion]) {
        if ([parsedDynamicLinkParameters[kFIRDLParameterRequestIPVersion]
                isEqualToString:@"IP_V4"]) {
          [baseURLs removeObject:kIosPostInstallAttributionRestBaseUrlIPV4];
        } else if ([parsedDynamicLinkParameters[kFIRDLParameterRequestIPVersion]
                       isEqualToString:@"IP_V6"]) {
          [baseURLs removeObject:kIosPostInstallAttributionRestBaseUrlIPV6];
        }
      }

      for (NSString *baseURL in baseURLs) {
        [self sendRequestWithBaseURLString:baseURL
                               requestBody:requestBodyMutable
                              endpointPath:@"installAttribution"
                               parserBlock:parserBlock
                                completion:handler];
      }
    }
    // We want to return out the result of the unique match check irrespective of success/failure as
    // it is the first fingerprinting request as well.
    dispatch_async(dispatch_get_main_queue(), ^{
      handler(parsedDynamicLinkParameters, matchMessage, parsingError);
    });
  };

  [self executeOnePlatformRequest:requestBody
                           forURL:requestURLString
                completionHandler:completeInvitationByDeviceCallback];
}

- (void)executeOnePlatformRequest:(NSDictionary *)requestBody
                           forURL:(NSString *)requestURLString
                completionHandler:(FIRNetworkRequestCompletionHandler)handler {
  NSURL *requestURL = [NSURL URLWithString:requestURLString];

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];

  // TODO: Verify that HTTPBody and HTTPMethod are iOS 8+ and find an alternative.
  request.HTTPBody = FIRDataWithDictionary(requestBody, nil);
  request.HTTPMethod = @"POST";

  [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

  // Set the iOS bundleID as a request header.
  NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
  if (bundleID) {
    [request setValue:bundleID forHTTPHeaderField:kHeaderIosBundleIdentifier];
  }
  FIRMakeHTTPRequest(request, handler);
}

@end

NS_ASSUME_NONNULL_END

#endif  // TARGET_OS_IOS
