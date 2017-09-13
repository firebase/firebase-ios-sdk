/*
 * Copyright 2017 Google
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

#import "FIROAuthCredential.h"

#import "FIRVerifyAssertionRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIROAuthCredential ()

- (nullable instancetype)initWithProvider:(NSString *)provider NS_UNAVAILABLE;

@end

@implementation FIROAuthCredential

- (nullable instancetype)initWithProviderID:(NSString *)providerID
                                    IDToken:(nullable NSString *)IDToken
                                accessToken:(nullable NSString *)accessToken {
  self = [super initWithProvider:providerID];
  if (self) {
    _IDToken = IDToken;
    _accessToken = accessToken;
  }
  return self;
}

- (void)prepareVerifyAssertionRequest:(FIRVerifyAssertionRequest *)request {
  request.providerIDToken = _IDToken;
  request.providerAccessToken = _accessToken;
}

NS_ASSUME_NONNULL_END

@end
