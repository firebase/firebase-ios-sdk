// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/Instrumentation/FPRProxyObjectHelper.h"

#import <GoogleUtilities/GULSwizzler.h>

@implementation FPRProxyObjectHelper

+ (void)registerProxyObject:(id)proxy
              forSuperclass:(Class)superclass
            varFoundHandler:(void (^)(id ivar))varFoundHandler {
  NSArray<id> *ivars = [GULSwizzler ivarObjectsForObject:proxy];
  for (id ivar in ivars) {
    if ([ivar isKindOfClass:superclass]) {
      varFoundHandler(ivar);
    }
  }
}

@end
