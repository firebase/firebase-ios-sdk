// Copyright 2017 Google
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

#import "FirebaseCommunity/FIRSwizzler.h"

#import <objc/runtime.h>

#import "FirebaseCommunity/FIRSwizzlingCaches.h"

@implementation FIRSwizzler

+ (void)swizzleClass:(Class)aClass
            selector:(SEL)selector
     isClassSelector:(BOOL)isClassSelector
           withBlock:(nullable id)block {
  dispatch_sync(GetFIRSwizzlingQueue(), ^{
    NSAssert(selector, @"The selector cannot be NULL");
    NSAssert(aClass, @"The class cannot be Nil");
    Class resolvedClass = aClass;
    Method method = nil;
    if (isClassSelector) {
      method = class_getClassMethod(aClass, selector);
      resolvedClass = object_getClass(aClass);
    } else {
      method = class_getInstanceMethod(aClass, selector);
    }
    NSAssert(method, @"You're attempting to swizzle a method that doesn't exist. (%@, %@)",
             NSStringFromClass(resolvedClass), NSStringFromSelector(selector));
    IMP originalImp = class_getMethodImplementation(resolvedClass, selector);
    IMP newImp = imp_implementationWithBlock(block);

    // If the method being swizzled has already been swizzled (meaning, it came from a superclass),
    // then it needs to make sure the originalImp points to the actual original IMP, rather than our
    // swizzled IMP.
    if ((*FIRNewToOriginalImp())[originalImp]) {
      originalImp = (*FIRNewToOriginalImp())[originalImp];
    }
    (*FIRNewToOriginalImp())[newImp] = originalImp;
    (*FIRPreviousImpCache())[std::pair<Class, SEL>(resolvedClass, selector)] = originalImp;
    const char *typeEncoding = method_getTypeEncoding(method);
    IMP originalImpOfClass = class_replaceMethod(resolvedClass, selector, newImp, typeEncoding);
    // If !originalImpOfClass, then the IMP came from a superclass.
    if (originalImpOfClass) {
      NSAssert(originalImpOfClass == originalImp, @"The IMP returned by class_replaceMethod and "
               "the originalImp found earlier should be the same thing!");
    }
  });
}

+ (void)unswizzleClass:(Class)aClass selector:(SEL)selector isClassSelector:(BOOL)isClassSelector {
  dispatch_sync(GetFIRSwizzlingQueue(), ^{
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
    std::pair<Class, SEL> classSELPair(resolvedClass, selector);
    IMP originalImp = (*FIRPreviousImpCache())[classSELPair];
    NSAssert(originalImp, @"This class/selector combination hasn't been swizzled");
    IMP currentImp = method_setImplementation(method, originalImp);
    NSAssert((*FIRNewToOriginalImp())[currentImp], @"The current IMP should be our swizzled IMP.");
    BOOL didRemoveBlock = imp_removeBlock(currentImp);
    NSAssert(didRemoveBlock, @"Wasn't able to remove the block of a swizzled IMP.");
    (*FIRNewToOriginalImp()).erase(currentImp);
    (*FIRPreviousImpCache()).erase(classSELPair);
  });
}

+ (nullable IMP)originalImplementationForClass:(Class)aClass
                                      selector:(SEL)selector
                               isClassSelector:(BOOL)isClassSelector {
  __block IMP originalImp = nil;
  dispatch_sync(GetFIRSwizzlingQueue(), ^{
    Class resolvedClass = isClassSelector ? object_getClass(aClass) : aClass;
    originalImp = (*FIRPreviousImpCache())[std::pair<Class, SEL>(resolvedClass, selector)];
    NSAssert(originalImp, @"The IMP for this class/selector combo doesn't exist (%@, %@).",
             NSStringFromClass(resolvedClass), NSStringFromSelector(selector));
  });
  return originalImp;
}

+ (BOOL)selector:(SEL)selector existsInClass:(Class)aClass isClassSelector:(BOOL)isClassSelector {
  Method method = isClassSelector ? class_getClassMethod(aClass, selector) :
                                    class_getInstanceMethod(aClass, selector);
  return method != nil;
}

+ (NSArray<id> *)ivarObjectsForObject:(id)object {
  NSMutableArray *array = [NSMutableArray array];
  unsigned int count;
  Ivar *vars = class_copyIvarList([object class], &count);
  for (NSUInteger i = 0; i < count; i++) {
    const char *typeEncoding = ivar_getTypeEncoding(vars[i]);
    // Check to see if the ivar is an object.
    if (strncmp(typeEncoding, "@", 1) == 0) {
      id ivarObject = object_getIvar(object, vars[i]);
      [array addObject:ivarObject];
    }
  }
  return array;
}

@end
