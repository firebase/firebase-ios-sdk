/*
 * Copyright 2023 Google LLC
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

#import <Foundation/Foundation.h>

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

#import "FirebaseAppCheck/Sources/Core/FIRAppCheck+Internal.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckComponent : NSObject <FIRLibrary>
@end

@implementation FIRAppCheckComponent

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-app-check"];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    return [[FIRAppCheck alloc] initWithApp:container.app];
  };

  // Use eager instantiation timing to give a chance for FAC token to be requested before it is
  // actually needed to avoid extra delaying dependent requests.
  FIRComponent *appCheckProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRAppCheckInterop)
                      instantiationTiming:FIRInstantiationTimingAlwaysEager
                            creationBlock:creationBlock];
  return @[ appCheckProvider ];
}

@end

NS_ASSUME_NONNULL_END
