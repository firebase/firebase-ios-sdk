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

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "GoogleUtilities/SwizzlerTestHelpers/GULSwizzlingCache.h"
#import "GoogleUtilities/SwizzlerTestHelpers/GULSwizzlingCache_Private.h"
@interface GULSwizzlingCacheTest : XCTestCase

@end

@implementation GULSwizzlingCacheTest

- (void)tearDown {
  [[GULSwizzlingCache sharedInstance] clearCache];
  [super tearDown];
}

- (void)testSharedInstanceCreatesSingleton {
  GULSwizzlingCache *firstCache = [GULSwizzlingCache sharedInstance];
  GULSwizzlingCache *secondCache = [GULSwizzlingCache sharedInstance];
  // Pointer equality to make sure they're the same instance.
  XCTAssertEqual(firstCache, secondCache);
}

- (void)testOriginalIMPOfCurrentIMPIsSameWhenNotPreviouslySwizzled {
  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP currentIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);
  IMP returnedOriginalIMP = [GULSwizzlingCache originalIMPOfCurrentIMP:currentIMP];
  // Pointer equality to make sure they're the same IMP.
  XCTAssertEqual(returnedOriginalIMP, currentIMP);
}

- (void)testOriginalIMPOfNewIMPIsActuallyOriginalIMPWhenPreviouslySwizzledManyTimes {
  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP originalIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);

  // Any valid IMP is OK for test.
  IMP intermediateIMP = class_getMethodImplementation(swizzledClass, @selector(copy));
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertNotEqual(originalIMP, intermediateIMP);
  [GULSwizzlingCache cacheCurrentIMP:originalIMP
                           forNewIMP:intermediateIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  IMP returnedOriginalIMPWhenSwizzledOnce =
      [GULSwizzlingCache originalIMPOfCurrentIMP:intermediateIMP];
  // Pointer equality to make sure they're the same IMP.
  XCTAssertEqual(returnedOriginalIMPWhenSwizzledOnce, originalIMP);

  // Any valid IMP is OK for test.
  IMP intermediateIMP2 = class_getMethodImplementation(swizzledClass, @selector(init));
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertNotEqual(intermediateIMP, intermediateIMP2);
  [GULSwizzlingCache cacheCurrentIMP:intermediateIMP
                           forNewIMP:intermediateIMP2
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  IMP returnedOriginalIMPWhenSwizzledTwice =
      [GULSwizzlingCache originalIMPOfCurrentIMP:intermediateIMP2];
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertEqual(returnedOriginalIMPWhenSwizzledTwice, originalIMP);

  IMP newIMP = class_getMethodImplementation(swizzledClass, @selector(mutableCopy));
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertNotEqual(intermediateIMP, newIMP);
  [GULSwizzlingCache cacheCurrentIMP:intermediateIMP
                           forNewIMP:newIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  IMP returnedOriginalIMPWhenSwizzledThrice = [GULSwizzlingCache originalIMPOfCurrentIMP:newIMP];
  // Pointer equality to make sure they're the same IMP.
  XCTAssertEqual(returnedOriginalIMPWhenSwizzledThrice, originalIMP);
}

- (void)testGettingCachedIMPForClassAndSelector {
  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP originalIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);

  // Any valid IMP is OK for test.
  IMP newIMP = class_getMethodImplementation(swizzledClass, @selector(copy));
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertNotEqual(originalIMP, newIMP);
  [GULSwizzlingCache cacheCurrentIMP:originalIMP
                           forNewIMP:newIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  IMP returnedOriginalIMP = [[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass
                                                                     withSelector:swizzledSelector];
  // Pointer equality to make sure they're the same IMP.
  XCTAssertEqual(returnedOriginalIMP, originalIMP);
}

- (void)testGettingCachedIMPForClassAndSelectorWhenLastImpWasPutThereByUs {
  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP originalIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);

  // Any valid IMP is OK for test.
  IMP intermediateIMP = class_getMethodImplementation(swizzledClass, @selector(copy));
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertNotEqual(originalIMP, intermediateIMP);
  [GULSwizzlingCache cacheCurrentIMP:originalIMP
                           forNewIMP:intermediateIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];

  // Any valid IMP is OK for test.
  IMP newIMP = class_getMethodImplementation(swizzledClass, @selector(mutableCopy));
  // Pointer inequality to make sure the IMPs are different.
  XCTAssertNotEqual(intermediateIMP, newIMP);
  [GULSwizzlingCache cacheCurrentIMP:intermediateIMP
                           forNewIMP:newIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  IMP returnedOriginalIMP = [[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass
                                                                     withSelector:swizzledSelector];
  // Pointer equality to make sure they're the same IMP.
  XCTAssertEqual(returnedOriginalIMP, originalIMP);
}

- (void)testClearingCacheActuallyClearsTheCache {
  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP originalIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);

  // Any valid IMP is OK for test.
  IMP newIMP = class_getMethodImplementation(swizzledClass, @selector(copy));
  XCTAssertNotEqual(originalIMP, newIMP);
  [GULSwizzlingCache cacheCurrentIMP:originalIMP
                           forNewIMP:newIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  XCTAssert([[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass
                                                     withSelector:swizzledSelector] != NULL);
  XCTAssertEqual([GULSwizzlingCache originalIMPOfCurrentIMP:newIMP], originalIMP,
                 @"New to original IMP cache was not correctly poplated.");

  [[GULSwizzlingCache sharedInstance] clearCacheForSwizzledIMP:newIMP
                                                      selector:swizzledSelector
                                                        aClass:swizzledClass];
  XCTAssert([[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass
                                                     withSelector:swizzledSelector] == NULL);
  XCTAssertEqual([GULSwizzlingCache originalIMPOfCurrentIMP:newIMP], newIMP,
                 @"New to original IMP cache was not cleared.");
}

- (void)testClearingCacheForOneIMPDoesNotImpactOtherIMPs {
  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP originalIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);

  // Any valid IMP is OK for test.
  IMP newIMP = class_getMethodImplementation(swizzledClass, @selector(copy));
  XCTAssertNotEqual(originalIMP, newIMP);
  [GULSwizzlingCache cacheCurrentIMP:originalIMP
                           forNewIMP:newIMP
                            forClass:swizzledClass
                        withSelector:swizzledSelector];
  XCTAssert([[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass
                                                     withSelector:swizzledSelector] != NULL);
  XCTAssertEqual([GULSwizzlingCache originalIMPOfCurrentIMP:newIMP], originalIMP,
                 @"New to original IMP cache was not correctly populated.");

  Class swizzledClass2 = [NSString class];
  SEL swizzledSelector2 = @selector(stringWithFormat:);
  IMP originalIMP2 = class_getMethodImplementation(swizzledClass2, swizzledSelector2);

  // Any valid IMP is OK for test.
  IMP newIMP2 = class_getMethodImplementation(swizzledClass2, @selector(stringByAppendingString:));
  XCTAssertNotEqual(originalIMP2, newIMP2);
  [GULSwizzlingCache cacheCurrentIMP:originalIMP2
                           forNewIMP:newIMP2
                            forClass:swizzledClass2
                        withSelector:swizzledSelector2];
  XCTAssert([[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass2
                                                     withSelector:swizzledSelector2] != NULL);
  [[GULSwizzlingCache sharedInstance] clearCacheForSwizzledIMP:newIMP
                                                      selector:swizzledSelector
                                                        aClass:swizzledClass];
  XCTAssert([[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass
                                                     withSelector:swizzledSelector] == NULL);
  XCTAssertEqual([GULSwizzlingCache originalIMPOfCurrentIMP:newIMP], newIMP,
                 @"New to original IMP cache was not cleared.");
  XCTAssert([[GULSwizzlingCache sharedInstance] cachedIMPForClass:swizzledClass2
                                                     withSelector:swizzledSelector2] != NULL);
  XCTAssertEqual([GULSwizzlingCache originalIMPOfCurrentIMP:newIMP2], originalIMP2,
                 @"New to original IMP cache was cleared when it shouldn't have.");
}

- (void)testDeallocatingSwizzlingCacheWithoutClearingItDoesntCrash {
  GULSwizzlingCache *cache = [[GULSwizzlingCache alloc] init];

  Class swizzledClass = [NSObject class];
  SEL swizzledSelector = @selector(description);
  IMP originalIMP = class_getMethodImplementation(swizzledClass, swizzledSelector);

  // Any valid IMP is OK for test.
  IMP newIMP = class_getMethodImplementation(swizzledClass, @selector(copy));
  [cache cacheCurrentIMP:originalIMP
               forNewIMP:newIMP
                forClass:swizzledClass
            withSelector:swizzledSelector];

  __weak GULSwizzlingCache *weakCache = cache;
  cache = nil;

  // If it reaches this point, deallocation succeded and it didn't crash.
  XCTAssertNil(weakCache);
}

- (void)testUnderlyingStoresAreDeallocatedWhenCacheIsDeallocated {
  GULSwizzlingCache *cache = [[GULSwizzlingCache alloc] init];
  __weak NSMutableDictionary *originalImps = (__bridge NSMutableDictionary *)cache.originalImps;
  __weak NSMutableDictionary *newToOriginalIMPs =
      (__bridge NSMutableDictionary *)cache.newToOriginalImps;

  XCTAssertNotNil(originalImps);
  XCTAssertNotNil(newToOriginalIMPs);

  cache = nil;
  XCTAssertNil(originalImps);
  XCTAssertNil(newToOriginalIMPs);
}

- (void)testCFMutableDictionaryRetainsAndReleasesClassSELPairCorrectly {
  GULSwizzlingCache *cache = [[GULSwizzlingCache alloc] init];
  Class testClass = [NSObject class];
  SEL testSelector = @selector(description);
  IMP testIMP = class_getMethodImplementation(testClass, testSelector);
  CFMutableDictionaryRef originalImps = cache.originalImps;
  const void *classSELCArray[2] = {(__bridge void *)(testClass), testSelector};
  CFArrayRef classSELPair = CFArrayCreate(kCFAllocatorDefault, classSELCArray,
                                          2,      // Size.
                                          NULL);  // Elements are pointers so this is NULL.
  __weak NSArray *classSELPairNSArray = (__bridge NSArray *)classSELPair;
  CFDictionaryAddValue(originalImps, classSELPair, testIMP);
  CFRelease(classSELPair);
  XCTAssertNotNil(classSELPairNSArray);

  CFDictionaryRemoveValue(originalImps, classSELPair);
  XCTAssertNil(classSELPairNSArray);
}

@end
