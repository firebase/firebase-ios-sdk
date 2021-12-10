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

#import "FirebaseDynamicLinks/Sources/FIRDLDefaultRetrievalProcessV2.h"

#import <UIKit/UIKit.h>
#import "FirebaseDynamicLinks/Sources/FIRDLJavaScriptExecutor.h"
#import "FirebaseDynamicLinks/Sources/FIRDLRetrievalProcessResult+Private.h"
#import "FirebaseDynamicLinks/Sources/FIRDynamicLink+Private.h"
#import "FirebaseDynamicLinks/Sources/FIRDynamicLinkNetworking.h"
#import "FirebaseDynamicLinks/Sources/Utilities/FDLUtilities.h"

// Reason for this string to ensure that only FDL links, copied to clipboard by AppPreview Page
// JavaScript code, are recognized and used in copy-unique-match process. If user copied FDL to
// clipboard by himself, that link must not be used in copy-unique-match process.
// This constant must be kept in sync with constant in the server version at
// durabledeeplink/click/ios/click_page.js
static NSString *expectedCopiedLinkStringSuffix = @"_icp=1";

NS_ASSUME_NONNULL_BEGIN

@interface FIRDLDefaultRetrievalProcessV2 () <FIRDLJavaScriptExecutorDelegate>

@end

@implementation FIRDLDefaultRetrievalProcessV2 {
  FIRDynamicLinkNetworking *_networkingService;
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
                                URLScheme:(NSString *)URLScheme
                                   APIKey:(NSString *)APIKey
                            FDLSDKVersion:(NSString *)FDLSDKVersion
                                 delegate:(id<FIRDLRetrievalProcessDelegate>)delegate {
  NSParameterAssert(networkingService);
  NSParameterAssert(URLScheme);
  NSParameterAssert(APIKey);
  if (self = [super init]) {
    _networkingService = networkingService;
    _URLScheme = [URLScheme copy];
    _APIKey = [APIKey copy];
    _FDLSDKVersion = [FDLSDKVersion copy];
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

        FIRDynamicLink *dynamicLink;
        if (dynamicLinkParameters.count) {
          dynamicLink = [[FIRDynamicLink alloc] initWithParametersDictionary:dynamicLinkParameters];
        }
        FIRDLRetrievalProcessResult *result =
            [[FIRDLRetrievalProcessResult alloc] initWithDynamicLink:dynamicLink
                                                               error:error
                                                             message:matchMessage
                                                         matchSource:nil];

        [strongSelf handleRetrievalProcessWithResult:result];
        if (!error) {
          [strongSelf clearUsedUniqueMatchLinkToCheckFromClipboard];
        }
      };

  // Disable deprecated warning for internal methods.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // If there is not a unique match, we will send an additional request for fingerprinting.
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

- (void)handleRetrievalProcessWithResult:(FIRDLRetrievalProcessResult *)result {
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

- (nullable NSURL *)uniqueMatchLinkToCheck {
  _clipboardContentAtMatchProcessStart = nil;
  NSString *pasteboardContents = [self retrievePasteboardContents];
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

- (NSString *)retrievePasteboardContents {
  if (![self isPasteboardRetrievalEnabled]) {
    // Pasteboard check for dynamic link is disabled by user.
    return @"";
  }

  NSString *pasteboardContents = @"";
  if (@available(iOS 10.0, *)) {
    if ([[UIPasteboard generalPasteboard] hasURLs]) {
      pasteboardContents = [UIPasteboard generalPasteboard].string;
    }
  } else {
    pasteboardContents = [UIPasteboard generalPasteboard].string;
  }
  return pasteboardContents;
}

/**
 Property to enable or disable dynamic link retrieval from Pasteboard.
 This property is added because of iOS 14 feature where pop up is displayed while accessing
 Pasteboard. So if developers don't want their users to see the Pasteboard popup, they can set
 "FirebaseDeepLinkPasteboardRetrievalEnabled" to false in their plist.
 */
- (BOOL)isPasteboardRetrievalEnabled {
  id retrievalEnabledValue =
      [[NSBundle mainBundle] infoDictionary][@"FirebaseDeepLinkPasteboardRetrievalEnabled"];
  if ([retrievalEnabledValue respondsToSelector:@selector(boolValue)]) {
    return [retrievalEnabledValue boolValue];
  }
  return YES;
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
  NSString *jsString = @"window.generateFingerprint=()=>navigator.language||''";
  _jsExecutor = [[FIRDLJavaScriptExecutor alloc] initWithDelegate:self script:jsString];
}

@end

NS_ASSUME_NONNULL_END

#endif  // TARGET_OS_IOS
