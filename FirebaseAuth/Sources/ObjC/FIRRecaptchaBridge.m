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

Class<RCARecaptchaProtocol> _Nonnull __fir_castToRecaptchaProtocolFromClass(Class _Nonnull klass) {
  if ([klass conformsToProtocol:@protocol(RCARecaptchaProtocol)]) {
    NSLog(@"RCARecaptchaProtocol - true");
  } else {
    NSLog(@"RCARecaptchaProtocol - false");
  }
  return (Class<RCARecaptchaProtocol>)klass;
}

Class<RCAActionProtocol> _Nonnull __fir_castToRecaptchaActionProtocolFromClass(
    Class _Nonnull klass) {
  if ([klass conformsToProtocol:@protocol(RCAActionProtocol)]) {
    NSLog(@"RCAActionProtocol - true");
  } else {
    NSLog(@"RCAActionProtocol - false");
  }
  return (Class<RCAActionProtocol>)klass;
}

#endif
