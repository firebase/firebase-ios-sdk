// Copyright 2024 Google LLC
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRRecaptchaBridge.h"
#import "RecaptchaInterop/RecaptchaInterop.h"

void __objc_getClientWithSiteKey(
    NSString *siteKey,
    Class recaptchaClass,
    void (^completionHandler)(id<RCARecaptchaClientProtocol> _Nullable result,
                              NSError *_Nullable error)) {
  SEL selector = NSSelectorFromString(@"getClientWithSiteKey:completion:");
  if (recaptchaClass && [recaptchaClass respondsToSelector:selector]) {
    void (*funcWithoutTimeout)(id, SEL, NSString *,
                               void (^)(id<RCARecaptchaClientProtocol> _Nullable recaptchaClient,
                                        NSError *_Nullable error)) =
        (void *)[recaptchaClass methodForSelector:selector];
    funcWithoutTimeout(recaptchaClass, selector, siteKey,
                       ^(id<RCARecaptchaClientProtocol> _Nonnull client, NSError *_Nullable error) {
                         if (error) {
                           completionHandler(nil, error);
                         } else {
                           completionHandler(client, nil);
                         }
                       });
  } else {
    completionHandler(nil, nil);  // TODO(ncooke3): Add error just in case.
  }
}

id<RCAActionProtocol> _Nullable __fir_initActionFromClass(Class _Nonnull klass,
                                                          NSString *_Nonnull actionString) {
  SEL customActionSelector = NSSelectorFromString(@"initWithCustomAction:");
  if (klass && [klass instancesRespondToSelector:customActionSelector]) {
    id (*funcWithCustomAction)(id, SEL, NSString *) =
        (id(*)(id, SEL, NSString *))[klass instanceMethodForSelector:customActionSelector];

    id<RCAActionProtocol> customAction =
        funcWithCustomAction([klass alloc], customActionSelector, actionString);
    return customAction;
  } else {
    return nil;
  }
}

#endif
