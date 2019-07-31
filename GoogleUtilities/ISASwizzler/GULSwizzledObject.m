// Copyright 2018 Google LLC
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

#import <objc/runtime.h>

#import "GULObjectSwizzler+Internal.h"
#import "Private/GULSwizzledObject.h"

NSString *kSwizzlerAssociatedObjectKey = @"gul_objectSwizzler";

@interface GULSwizzledObject ()

@end

@implementation GULSwizzledObject

+ (void)copyDonorSelectorsUsingObjectSwizzler:(GULObjectSwizzler *)objectSwizzler {
  [objectSwizzler copySelector:@selector(gul_objectSwizzler) fromClass:self isClassSelector:NO];
  [objectSwizzler copySelector:@selector(gul_class) fromClass:self isClassSelector:NO];
  [objectSwizzler copySelector:@selector(dealloc) fromClass:self isClassSelector:NO];

  // This is needed because NSProxy objects usually override -[NSObjectProtocol respondsToSelector:]
  // and ask this question to the underlying object. Since we don't swizzle the underlying object
  // but swizzle the proxy, when someone calls -[NSObjectProtocol respondsToSelector:] on the proxy,
  // the answer ends up being NO even if we added new methods to the subclass through ISA Swizzling.
  // To solve that, we override -[NSObjectProtocol respondsToSelector:] in such a way that takes
  // into account the fact that we've added new methods.
  if ([objectSwizzler isSwizzlingProxyObject]) {
    [objectSwizzler copySelector:@selector(respondsToSelector:) fromClass:self isClassSelector:NO];
  }
}

- (instancetype)init {
  NSAssert(NO, @"Do not instantiate this class, it's only a donor class");
  return nil;
}

- (GULObjectSwizzler *)gul_objectSwizzler {
  return [GULObjectSwizzler getAssociatedObject:self key:kSwizzlerAssociatedObjectKey];
}

#pragma mark - Donor methods

- (Class)gul_class {
  return [[self gul_objectSwizzler] generatedClass];
}

// Only added to a class when we detect it is a proxy.
- (BOOL)respondsToSelector:(SEL)aSelector {
  Class gulClass = [[self gul_objectSwizzler] generatedClass];
  return [gulClass instancesRespondToSelector:aSelector] || [super respondsToSelector:aSelector];
}

- (void)dealloc {
  // We need to make sure the swizzler is deallocated after the swizzled object to do the clean up
  // only when the swizzled object is not used.
  GULObjectSwizzler *swizzler = nil;
  BOOL isInstanceOfGeneratedClass = NO;

  @autoreleasepool {
    Class generatedClass = [self gul_class];
    isInstanceOfGeneratedClass = object_getClass(self) == generatedClass;

    swizzler = [[self gul_objectSwizzler] retain];
    [GULObjectSwizzler setAssociatedObject:self
                                       key:kSwizzlerAssociatedObjectKey
                                     value:nil
                               association:GUL_ASSOCIATION_RETAIN_NONATOMIC];
  }

  [super dealloc];

  [swizzler swizzledObjectHasBeenDeallocatedWithGeneratedSubclass:isInstanceOfGeneratedClass];
  [swizzler release];
}

@end
