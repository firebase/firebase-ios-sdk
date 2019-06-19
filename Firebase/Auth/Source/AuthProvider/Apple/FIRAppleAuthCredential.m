/*
 * Copyright 2019 Google
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

#import "FIRAppleAuthCredential.h"

#import "FIRAppleAuthProvider.h"
#import "FIRAuthExceptionUtils.h"
#import "FIRVerifyAssertionRequest.h"
#import <AuthenticationServices/AuthenticationServices.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppleAuthCredential ()

- (nullable instancetype)initWithProvider:(NSString *)provider NS_UNAVAILABLE;

@end

@implementation FIRAppleAuthCredential

- (nullable instancetype)initWithProvider:(NSString *)provider {
  [FIRAuthExceptionUtils raiseMethodNotImplementedExceptionWithReason:
   @"Please call the designated initializer."];
  return nil;
}

- (nullable instancetype)initWithAuthorizationCredential:(ASAuthorizationAppleIDCredential *)appleIDCredential {
  self = [super initWithProvider:FIRAppleAuthProviderID];
  if (self) {
    _user = [[appleIDCredential user]copy];
    _identityToken = [[appleIDCredential identityToken] base64EncodedStringWithOptions: nil]
  }
  return self;
}

- (nullable instancetype)initWithPasswordCredential: (ASPasswordCredential *)passwordCredential {
  self = [super initWithProvider: FIRAppleAuthProviderID];
  if (self) {
    _user = [[passwordCredential user] copy];
    _password = [[passwordCredential password] copy];
  }
  return self;
}

- (nullable instancetype)initWithUser:(NSString *)user identityToken:(NSString *)identityToken {
  self = [super initWithProvider: FIRAppleAuthProviderID];
  if (self) {
    _user = [user copy];
    _identityToken = [identityToken copy];
  }
  return self;
}

- (void)prepareVerifyAssertionRequest:(FIRVerifyAssertionRequest *)request {
  request.providerAccessToken = _identityToken;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  NSString *user = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"user"];
  NSString *identityToken = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"identityToken"];
  self = [self initWithUser:user identityToken:identityToken];
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.user forKey:@"user"];
  [aCoder encodeObject:self.identityToken forKey: @"identityToken"];
}

@end

NS_ASSUME_NONNULL_END
