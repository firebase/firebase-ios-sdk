// Copyright 2019 Google LLC
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

#import "GoogleUtilities/MethodSwizzler/Public/GoogleUtilities/GULSwizzler.h"

#import <objc/runtime.h>

#import "GoogleUtilities/SwizzlerTestHelpers/GULSwizzlingCache.h"

extern dispatch_queue_t GetGULSwizzlingQueue(void);

@implementation GULSwizzler (Unswizzle)

+ (void)unswizzleClass:(Class)aClass selector:(SEL)selector isClassSelector:(BOOL)isClassSelector {
  dispatch_sync(GetGULSwizzlingQueue(), ^{
    NSAssert(aClass != nil && selector != nil, @"You cannot unswizzle a nil class or selector.");
    Method method = nil;
    Class resolvedClass = aClass;
    if (isClassSelector) {
      resolvedClass = object_getClass(aClass);
      method = class_getClassMethod(aClass, selector);
    } else {
      method = class_getInstanceMethod(aClass, selector);
    }
    NSAssert(method, @"Couldn't find the method you're unswizzling in the runtime.");
    IMP originalImp = [[GULSwizzlingCache sharedInstance] cachedIMPForClass:resolvedClass
                                                               withSelector:selector];
    NSAssert(originalImp, @"This class/selector combination hasn't been swizzled");
    IMP currentImp = method_setImplementation(method, originalImp);
    __unused BOOL didRemoveBlock = imp_removeBlock(currentImp);
    NSAssert(didRemoveBlock, @"Wasn't able to remove the block of a swizzled IMP.");
    [[GULSwizzlingCache sharedInstance] clearCacheForSwizzledIMP:currentImp
                                                        selector:selector
                                                          aClass:resolvedClass];
  });
}

+ (nullable IMP)originalImplementationForClass:(Class)aClass
                                      selector:(SEL)selector
                               isClassSelector:(BOOL)isClassSelector {
  __block IMP originalImp = nil;
  dispatch_sync(GetGULSwizzlingQueue(), ^{
    Class resolvedClass = isClassSelector ? object_getClass(aClass) : aClass;
    originalImp = [[GULSwizzlingCache sharedInstance] cachedIMPForClass:resolvedClass
                                                           withSelector:selector];
    NSAssert(originalImp, @"The IMP for this class/selector combo doesn't exist (%@, %@).",
             NSStringFromClass(resolvedClass), NSStringFromSelector(selector));
  });
  return originalImp;
}

@end
