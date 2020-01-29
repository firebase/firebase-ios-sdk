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

#import "DynamicLinks/FIRDLDefaultRetrievalProcessV2.h"

#import <UIKit/UIKit.h>
#import "DynamicLinks/FIRDLJavaScriptExecutor.h"
#import "DynamicLinks/FIRDLRetrievalProcessResult+Private.h"
#import "DynamicLinks/FIRDynamicLink+Private.h"
#import "DynamicLinks/FIRDynamicLinkNetworking.h"
#import "DynamicLinks/Utilities/FDLUtilities.h"

// The maximum number of successful fingerprint api calls.
const static NSUInteger kMaximumNumberOfSuccessfulFingerprintAPICalls = 2;

// Reason for this string to ensure that only FDL links, copied to clipboard by AppPreview Page
// JavaScript code, are recognized and used in copy-unique-match process. If user copied FDL to
// clipboard by himself, that link must not be used in copy-unique-match process.
// This constant must be kept in sync with constant in the server version at
// durabledeeplink/click/ios/click_page.js
static NSString *expectedCopiedLinkStringSuffix = @"_icp=1";

NS_ASSUME_NONNULL_BEGIN

@interface FIRDLDefaultRetrievalProcessV2 () <FIRDLJavaScriptExecutorDelegate>

@property(atomic, strong) NSMutableArray *requestResults;

@end

@implementation FIRDLDefaultRetrievalProcessV2 {
  FIRDynamicLinkNetworking *_networkingService;
  NSString *_clientID;
  NSString *_URLScheme;
  NSString *_APIKey;
  NSString *_FDLSDKVersion;
  NSString *_clipboardContentAtMatchProcessStart;
  FIRDLJavaScriptExecutor *_jsExecutor;
  NSString *_localeFromWebView;
}

@synthesize delegate = _delegate;

#pragma mark - Initialization

- (instancetype)initWithNetworkingService:(FIRDynamicLinkNetworking *)networkingService
                                 clientID:(NSString *)clientID
                                URLScheme:(NSString *)URLScheme
                                   APIKey:(NSString *)APIKey
                            FDLSDKVersion:(NSString *)FDLSDKVersion
                                 delegate:(id<FIRDLRetrievalProcessDelegate>)delegate {
  NSParameterAssert(networkingService);
  NSParameterAssert(clientID);
  NSParameterAssert(URLScheme);
  NSParameterAssert(APIKey);
  if (self = [super init]) {
    _networkingService = networkingService;
    _clientID = [clientID copy];
    _URLScheme = [URLScheme copy];
    _APIKey = [APIKey copy];
    _FDLSDKVersion = [FDLSDKVersion copy];
    self.requestResults =
        [[NSMutableArray alloc] initWithCapacity:kMaximumNumberOfSuccessfulFingerprintAPICalls];
    _delegate = delegate;
  }
  return self;
}

#pragma mark - FIRDLRetrievalProcessProtocol

- (void)retrievePendingDynamicLink {
  if (_localeFromWebView) {
    [self retrievePendingDynamicLinkInternal];
  } else {
    [self fetchLocaleFromWebView];
  }
}

- (BOOL)isCompleted {
  return self.requestResults.count >= kMaximumNumberOfSuccessfulFingerprintAPICalls;
}

#pragma mark - FIRDLJavaScriptExecutorDelegate

- (void)javaScriptExecutor:(FIRDLJavaScriptExecutor *)executor
    completedExecutionWithResult:(NSString *)result {
  _localeFromWebView = result ?: @"";
  _jsExecutor = nil;
  [self retrievePendingDynamicLinkInternal];
}

- (void)javaScriptExecutor:(FIRDLJavaScriptExecutor *)executor failedWithError:(NSError *)error {
  _localeFromWebView = @"";
  _jsExecutor = nil;
  [self retrievePendingDynamicLinkInternal];
}

#pragma mark - Internal methods

- (void)retrievePendingDynamicLinkInternal {
  CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
  NSInteger resolutionWidth = mainScreenBounds.size.width;
  NSInteger resolutionHeight = mainScreenBounds.size.height;
  if ([[[UIDevice currentDevice] model] isEqualToString:@"iPad"] &&
      UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
    // iPhone App running in compatibility mode on iPad
    // screen resolution reported by UIDevice/UIScreen will be wrong
    resolutionWidth = 0;
    resolutionHeight = 0;
  }
  NSURL *uniqueMatchLinkToCheck = [self uniqueMatchLinkToCheck];

  __weak __typeof__(self) weakSelf = self;
  FIRPostInstallAttributionCompletionHandler completionHandler =
      ^(NSDictionary *_Nullable dynamicLinkParameters, NSString *_Nullable matchMessage,
        NSError *_Nullable error) {
        __typeof__(self) strongSelf = weakSelf;
        if (!strongSelf) {
          return;
        }
        if (strongSelf.completed) {
          // we may abort process and return previously found dynamic link before all requests
          // completed
          return;
        }

        FIRDynamicLink *dynamicLink;
        if (dynamicLinkParameters.count) {
          dynamicLink = [[FIRDynamicLink alloc] initWithParametersDictionary:dynamicLinkParameters];
        }
        FIRDLRetrievalProcessResult *result =
            [[FIRDLRetrievalProcessResult alloc] initWithDynamicLink:dynamicLink
                                                               error:error
                                                             message:matchMessage
                                                         matchSource:nil];

        [strongSelf.requestResults addObject:result];
        [strongSelf handleRequestResultsUpdated];
        if (!error) {
          [strongSelf clearUsedUniqueMatchLinkToCheckFromClipboard];
        }
      };

  // Disable deprecated warning for internal methods.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // If not unique match, we send request twice, since there are two server calls:
  // one for IPv4, another for IPV6.
  [_networkingService
      retrievePendingDynamicLinkWithIOSVersion:[UIDevice currentDevice].systemVersion
                              resolutionHeight:resolutionHeight
                               resolutionWidth:resolutionWidth
                                        locale:FIRDLDeviceLocale()
                                     localeRaw:FIRDLDeviceLocaleRaw()
                             localeFromWebView:_localeFromWebView
                                      timezone:FIRDLDeviceTimezone()
                                     modelName:FIRDLDeviceModelName()
                                 FDLSDKVersion:_FDLSDKVersion
                           appInstallationDate:FIRDLAppInstallationDate()
                        uniqueMatchVisualStyle:FIRDynamicLinkNetworkingUniqueMatchVisualStyleUnknown
                          retrievalProcessType:
                              FIRDynamicLinkNetworkingRetrievalProcessTypeImplicitDefault
                        uniqueMatchLinkToCheck:uniqueMatchLinkToCheck
                                       handler:completionHandler];
#pragma clang pop
}

- (NSArray<FIRDLRetrievalProcessResult *> *)foundResultsWithDynamicLinks {
  NSPredicate *predicate =
      [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject,
                                            NSDictionary<NSString *, id> *_Nullable bindings) {
        if ([evaluatedObject isKindOfClass:[FIRDLRetrievalProcessResult class]]) {
          FIRDLRetrievalProcessResult *result = (FIRDLRetrievalProcessResult *)evaluatedObject;
          return result.dynamicLink.url != nil;
        }
        return NO;
      }];
  return [self.requestResults filteredArrayUsingPredicate:predicate];
}

- (NSArray<FIRDLRetrievalProcessResult *> *)resultsWithErrors {
  NSPredicate *predicate =
      [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject,
                                            NSDictionary<NSString *, id> *_Nullable bindings) {
        if ([evaluatedObject isKindOfClass:[FIRDLRetrievalProcessResult class]]) {
          FIRDLRetrievalProcessResult *result = (FIRDLRetrievalProcessResult *)evaluatedObject;
          return result.error != nil;
        }
        return NO;
      }];
  return [self.requestResults filteredArrayUsingPredicate:predicate];
}

- (NSArray<FIRDLRetrievalProcessResult *> *)results {
  NSPredicate *predicate =
      [NSPredicate predicateWithBlock:^BOOL(id _Nullable evaluatedObject,
                                            NSDictionary<NSString *, id> *_Nullable bindings) {
        return [evaluatedObject isKindOfClass:[FIRDLRetrievalProcessResult class]];
      }];
  return [self.requestResults filteredArrayUsingPredicate:predicate];
}

- (nullable FIRDLRetrievalProcessResult *)resultWithUniqueMatchedDynamicLink {
  // return result with unique-matched dynamic link if found
  NSArray<FIRDLRetrievalProcessResult *> *foundResultsWithDynamicLinks =
      [self foundResultsWithDynamicLinks];
  for (FIRDLRetrievalProcessResult *result in foundResultsWithDynamicLinks) {
    if (result.dynamicLink.matchType == FIRDLMatchTypeUnique) {
      return result;
    }
  }
  return nil;
}

- (void)handleRequestResultsUpdated {
  FIRDLRetrievalProcessResult *resultWithUniqueMatchedDynamicLink =
      [self resultWithUniqueMatchedDynamicLink];
  if (resultWithUniqueMatchedDynamicLink) {
    [self markCompleted];
    [self.delegate retrievalProcess:self completedWithResult:resultWithUniqueMatchedDynamicLink];
  } else if (self.completed) {
    NSArray<FIRDLRetrievalProcessResult *> *foundResultsWithDynamicLinks =
        [self foundResultsWithDynamicLinks];
    NSArray<FIRDLRetrievalProcessResult *> *resultsThatEncounteredErrors = [self resultsWithErrors];
    if (foundResultsWithDynamicLinks.count) {
      // return any result if no unique-matched URL is available
      // TODO: Merge match message from all results
      [self.delegate retrievalProcess:self
                  completedWithResult:foundResultsWithDynamicLinks.firstObject];
    } else if (resultsThatEncounteredErrors.count > 0) {
      // TODO: Merge match message and errors from all results
      [self.delegate retrievalProcess:self
                  completedWithResult:resultsThatEncounteredErrors.firstObject];
    } else {
      // dynamic link not found
      // TODO: Merge match message from all results
      FIRDLRetrievalProcessResult *result = [[self results] firstObject];
      if (!result) {
        // if we did not get any results, construct one
        NSString *message = NSLocalizedString(@"Pending dynamic link not found",
                                              @"Message when dynamic link was not found");
        result = [[FIRDLRetrievalProcessResult alloc] initWithDynamicLink:nil
                                                                    error:nil
                                                                  message:message
                                                              matchSource:nil];
      }
      [self.delegate retrievalProcess:self completedWithResult:result];
    }
  }
}

- (void)markCompleted {
  while (!self.completed) {
    [self.requestResults addObject:[NSNull null]];
  }
}

- (nullable NSURL *)uniqueMatchLinkToCheck {
  _clipboardContentAtMatchProcessStart = nil;
  NSString *pasteboardContents = [UIPasteboard generalPasteboard].string;
  NSInteger linkStringMinimumLength =
      expectedCopiedLinkStringSuffix.length + /* ? or & */ 1 + /* http:// */ 7;
  if ((pasteboardContents.length >= linkStringMinimumLength) &&
      [pasteboardContents hasSuffix:expectedCopiedLinkStringSuffix] &&
      [NSURL URLWithString:pasteboardContents]) {
    // remove custom suffix and preceding '&' or '?' character from string
    NSString *linkStringWithoutSuffix = [pasteboardContents
        substringToIndex:pasteboardContents.length - expectedCopiedLinkStringSuffix.length - 1];
    NSURL *URL = [NSURL URLWithString:linkStringWithoutSuffix];
    if (URL) {
      // check is link matches short link format
      if (FIRDLMatchesShortLinkFormat(URL)) {
        _clipboardContentAtMatchProcessStart = pasteboardContents;
        return URL;
      }
      // check is link matches long link format
      if (FIRDLCanParseUniversalLinkURL(URL)) {
        _clipboardContentAtMatchProcessStart = pasteboardContents;
        return URL;
      }
    }
  }
  return nil;
}

- (void)clearUsedUniqueMatchLinkToCheckFromClipboard {
  // See discussion in b/65304652
  // We will clear clipboard after we used the unique match link from the clipboard
  if (_clipboardContentAtMatchProcessStart.length > 0 &&
      [_clipboardContentAtMatchProcessStart isEqualToString:_clipboardContentAtMatchProcessStart]) {
    [UIPasteboard generalPasteboard].string = @"";
  }
}

- (void)fetchLocaleFromWebView {
  if (_jsExecutor) {
    return;
  }
  NSString *jsString = @"window.generateFingerprint=function(){try{var "
                       @"languageCode=navigator.languages?navigator.languages[0]:navigator."
                       @"language;return languageCode;}catch(b){return"
                        "}};";
  _jsExecutor = [[FIRDLJavaScriptExecutor alloc] initWithDelegate:self script:jsString];
}

@end

NS_ASSUME_NONNULL_END
