/** @file FIRVerifyClientRequest.m
    @brief Firebase Auth SDK
    @copyright Copyright 2017 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import "FIRVerifyClientRequest.h"


NS_ASSUME_NONNULL_BEGIN

/** @var kVerifyClientEndpoint
    @brief The endpoint for the verifyClient request.
 */
static NSString *const kVerifyClientEndpoint = @"verifyClient";

/** @var kAppTokenKey
    @brief The key for the appToken request paramenter.
 */
static NSString *const kAPPTokenKey = @"appToken";

/** @var kIsSandboxKey
    @brief The key for the isSandbox request parameter
 */
static NSString *const kIsSandboxKey = @"isSandbox";

@implementation FIRVerifyClientRequest

- (nullable instancetype)initWithAppToken:(NSString *)appToken
                                isSandbox:(BOOL)isSandbox
                                   APIKey:(NSString *)APIKey {
  self = [super initWithEndpoint:kVerifyClientEndpoint APIKey:APIKey];
  if (self) {
    _appToken = appToken;
    _isSandbox = isSandbox;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing  _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_appToken) {
    postBody[kAPPTokenKey] = _appToken;
  }
  if (_isSandbox) {
    postBody[kIsSandboxKey] = @YES;
  }
  return postBody;
}

@end

NS_ASSUME_NONNULL_END
