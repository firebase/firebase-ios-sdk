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

#import "GoogleUtilities/SwizzlerTestHelpers/GULSwizzlingCache.h"

#import <objc/runtime.h>

@interface GULSwizzlingCache ()
- (IMP)originalIMPOfCurrentIMP:(IMP)currentIMP;
@end

@implementation GULSwizzlingCache {
  /** A mapping from the new IMP to the original IMP. */
  CFMutableDictionaryRef _newToOriginalImps;

  /** A mapping from a Class and SEL (stored in a CFArray) to the original IMP that existed for it.
   */
  CFMutableDictionaryRef _originalImps;
}

+ (instancetype)sharedInstance {
  static GULSwizzlingCache *sharedInstance;
  static dispatch_once_t token;
  dispatch_once(&token, ^{
    sharedInstance = [[GULSwizzlingCache alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _newToOriginalImps = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                   0,      // Size.
                                                   NULL,   // Keys are pointers, so this is NULL.
                                                   NULL);  // Values are pointers so this is NULL.
    _originalImps = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                              0,                               // Size.
                                              &kCFTypeDictionaryKeyCallBacks,  // Keys are CFArrays.
                                              NULL);  // Values are pointers so this is NULL.
  }
  return self;
}

- (void)dealloc {
  CFRelease(_newToOriginalImps);
  CFRelease(_originalImps);
}

- (void)cacheCurrentIMP:(IMP)currentIMP
              forNewIMP:(IMP)newIMP
               forClass:(Class)aClass
           withSelector:(SEL)selector {
  IMP originalIMP = [self originalIMPOfCurrentIMP:currentIMP];
  CFDictionaryAddValue(_newToOriginalImps, newIMP, originalIMP);

  const void *classSELCArray[2] = {(__bridge void *)(aClass), selector};
  CFArrayRef classSELPair = CFArrayCreate(kCFAllocatorDefault, classSELCArray,
                                          2,      // Size.
                                          NULL);  // Elements are pointers so this is NULL.
  CFDictionaryAddValue(_originalImps, classSELPair, originalIMP);
  CFRelease(classSELPair);
}

+ (void)cacheCurrentIMP:(IMP)currentIMP
              forNewIMP:(IMP)newIMP
               forClass:(Class)aClass
           withSelector:(SEL)selector {
  [[GULSwizzlingCache sharedInstance] cacheCurrentIMP:currentIMP
                                            forNewIMP:newIMP
                                             forClass:aClass
                                         withSelector:selector];
}

- (IMP)cachedIMPForClass:(Class)aClass withSelector:(SEL)selector {
  const void *classSELCArray[2] = {(__bridge void *)(aClass), selector};
  CFArrayRef classSELPair = CFArrayCreate(kCFAllocatorDefault, classSELCArray,
                                          2,      // Size.
                                          NULL);  // Elements are pointers so this is NULL.
  const void *returnedIMP = CFDictionaryGetValue(_originalImps, classSELPair);
  CFRelease(classSELPair);
  return (IMP)returnedIMP;
}

- (void)clearCacheForSwizzledIMP:(IMP)swizzledIMP selector:(SEL)selector aClass:(Class)aClass {
  CFDictionaryRemoveValue(_newToOriginalImps, swizzledIMP);
  const void *classSELCArray[2] = {(__bridge void *)(aClass), selector};
  CFArrayRef classSELPair = CFArrayCreate(kCFAllocatorDefault, classSELCArray,
                                          2,      // Size.
                                          NULL);  // Elements are pointers so this is NULL.
  CFDictionaryRemoveValue(_originalImps, classSELPair);
  CFRelease(classSELPair);
}

- (IMP)originalIMPOfCurrentIMP:(IMP)currentIMP {
  const void *returnedIMP = CFDictionaryGetValue(_newToOriginalImps, currentIMP);
  if (returnedIMP != NULL) {
    return (IMP)returnedIMP;
  } else {
    return currentIMP;
  }
}

+ (IMP)originalIMPOfCurrentIMP:(IMP)currentIMP {
  return [[GULSwizzlingCache sharedInstance] originalIMPOfCurrentIMP:currentIMP];
}

#pragma mark - Helper methods for testing

- (void)clearCache {
  CFDictionaryRemoveAllValues(_originalImps);
  CFDictionaryRemoveAllValues(_newToOriginalImps);
}

- (CFMutableDictionaryRef)originalImps {
  return _originalImps;
}

- (CFMutableDictionaryRef)newToOriginalImps {
  return _newToOriginalImps;
}

@end
