// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// A protocol to handle obtaining a custom token to exchange for a new Firebase ID token.
NS_SWIFT_NAME(CustomTokenProviderDelegate) @protocol FIRCustomTokenProviderDelegate <NSObject>

// This method is invoked when a new Firebase ID token is requested and no refresh token is
// present (i.e., in passthrough mode). This method should be implemented to obtain a custom
// token to exchange for a new Firebase ID token.
- (void)getCustomTokenWithCompletion:(void (^)(NSString *_Nullable customToken,
                                               NSError *_Nullable error))completion
    NS_SWIFT_NAME(getCustomToken(completion:));
@end

NS_ASSUME_NONNULL_END
