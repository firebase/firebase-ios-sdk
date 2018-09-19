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

#import <WebKit/WebKit.h>

#import "DynamicLinks/FIRDLJavaScriptExecutor.h"

// define below needed because nullability of UIWebViewDelegate method param was changed between
// iOS SDK versions
#if (defined(__IPHONE_10_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0))
#define FIRDL_NULLABLE_IOS9_NONNULLABLE_IOS10 nonnull
#else
#define FIRDL_NULLABLE_IOS9_NONNULLABLE_IOS10 nullable
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const kJSMethodName = @"generateFingerprint";

/** Creates and returns the FDL JS method name. */
NSString *FIRDLTypeofFingerprintJSMethodNameString() {
  static NSString *methodName;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    methodName = [NSString stringWithFormat:@"typeof(%@)", kJSMethodName];
  });
  return methodName;
}

/** Creates and returns the FDL JS method definition. */
NSString *GINFingerprintJSMethodString() {
  static NSString *methodString;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    methodString = [NSString stringWithFormat:@"%@()", kJSMethodName];
  });
  return methodString;
}

@interface FIRDLJavaScriptExecutor () <UIWebViewDelegate, WKNavigationDelegate>
@end

@implementation FIRDLJavaScriptExecutor {
  __weak id<FIRDLJavaScriptExecutorDelegate> _delegate;
  NSString *_script;

  // Web views with which to run JavaScript.
  UIWebView *_uiWebView;  // Used in iOS 7 only.
  WKWebView *_wkWebView;  // Used in iOS 8+ only.
}

- (instancetype)initWithDelegate:(id<FIRDLJavaScriptExecutorDelegate>)delegate
                          script:(NSString *)script {
  NSParameterAssert(delegate);
  NSParameterAssert(script);
  NSParameterAssert(script.length > 0);
  NSAssert([NSThread isMainThread], @"%@ must be used in main thread",
           NSStringFromClass([self class]));
  if (self = [super init]) {
    _delegate = delegate;
    _script = [script copy];
    [self start];
  }
  return self;
}

#pragma mark - Internal methods
- (void)start {
  NSString *htmlContent =
      [NSString stringWithFormat:@"<html><head><script>%@</script></head></html>", _script];

  // Use WKWebView if available as it executes JavaScript more quickly, otherwise, fall back
  // on UIWebView.
  if ([WKWebView class]) {
    _wkWebView = [[WKWebView alloc] init];
    _wkWebView.navigationDelegate = self;
    [_wkWebView loadHTMLString:htmlContent baseURL:nil];
  } else {
    _uiWebView = [[UIWebView alloc] init];
    _uiWebView.delegate = self;
    [_uiWebView loadHTMLString:htmlContent baseURL:nil];
  }
}

- (void)handleExecutionResult:(NSString *)result {
  [self cleanup];
  [_delegate javaScriptExecutor:self completedExecutionWithResult:result];
}

- (void)handleExecutionError:(nullable NSError *)error {
  [self cleanup];
  if (!error) {
    error = [NSError errorWithDomain:@"com.firebase.durabledeeplink" code:-1 userInfo:nil];
  }
  [_delegate javaScriptExecutor:self failedWithError:error];
}

- (void)cleanup {
  _uiWebView.delegate = nil;
  _uiWebView = nil;
  _wkWebView.navigationDelegate = nil;
  _wkWebView = nil;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(null_unspecified WKNavigation *)navigation {
  __weak __typeof__(self) weakSelf = self;

  // Make sure that the javascript was loaded successfully before calling the method.
  [webView evaluateJavaScript:FIRDLTypeofFingerprintJSMethodNameString()
            completionHandler:^(id _Nullable typeofResult, NSError *_Nullable typeError) {
              if (typeError) {
                [weakSelf handleExecutionError:typeError];
                return;
              }
              if ([typeofResult isEqual:@"function"]) {
                [webView
                    evaluateJavaScript:GINFingerprintJSMethodString()
                     completionHandler:^(id _Nullable result, NSError *_Nullable functionError) {
                       if ([result isKindOfClass:[NSString class]]) {
                         [weakSelf handleExecutionResult:result];
                       } else {
                         [weakSelf handleExecutionError:nil];
                       }
                     }];
              } else {
                [weakSelf handleExecutionError:nil];
              }
            }];
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(null_unspecified WKNavigation *)navigation
            withError:(NSError *)error {
  [self handleExecutionError:error];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView {
  // Make sure that the javascript was loaded successfully before calling the method.
  NSString *methodType =
      [webView stringByEvaluatingJavaScriptFromString:FIRDLTypeofFingerprintJSMethodNameString()];
  if (![methodType isEqualToString:@"function"]) {
    // Javascript was not loaded successfully.
    [self handleExecutionError:nil];
    return;
  }

  // Get the result from javascript.
  NSString *result =
      [webView stringByEvaluatingJavaScriptFromString:GINFingerprintJSMethodString()];
  if ([result isKindOfClass:[NSString class]]) {
    [self handleExecutionResult:result];
  } else {
    [self handleExecutionError:nil];
  }
}

- (void)webView:(UIWebView *)webView
    didFailLoadWithError:(FIRDL_NULLABLE_IOS9_NONNULLABLE_IOS10 NSError *)error {
  [self handleExecutionError:error];
}

@end

NS_ASSUME_NONNULL_END
