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

#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor_Private.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"

/** Use ivars instead of properties to reduce message sending overhead. */
@interface FPRClassInstrumentor () {
  // The selector instrumentors associated with this class.
  NSMutableSet<FPRSelectorInstrumentor *> *_selectorInstrumentors;
}

@end

@implementation FPRClassInstrumentor

#pragma mark - Public methods

- (instancetype)init {
  FPRAssert(NO, @"%@: please use the designated initializer.", NSStringFromClass([self class]));
  return nil;
}

- (instancetype)initWithClass:(Class)aClass {
  self = [super init];
  if (self) {
    FPRAssert(aClass, @"You must supply a class in order to instrument its methods");
    _instrumentedClass = aClass;
    _selectorInstrumentors = [[NSMutableSet<FPRSelectorInstrumentor *> alloc] init];
  }
  return self;
}

- (nullable FPRSelectorInstrumentor *)instrumentorForClassSelector:(SEL)selector {
  return [self buildAndAddSelectorInstrumentorForSelector:selector isClassSelector:YES];
}

- (nullable FPRSelectorInstrumentor *)instrumentorForInstanceSelector:(SEL)selector {
  return [self buildAndAddSelectorInstrumentorForSelector:selector isClassSelector:NO];
}

- (void)swizzle {
  for (FPRSelectorInstrumentor *selectorInstrumentor in _selectorInstrumentors) {
    [selectorInstrumentor swizzle];
  }
}

- (BOOL)unswizzle {
  for (FPRSelectorInstrumentor *selectorInstrumentor in _selectorInstrumentors) {
    [selectorInstrumentor unswizzle];
  }
  [_selectorInstrumentors removeAllObjects];
  return _selectorInstrumentors.count == 0;
}

#pragma mark - Private methods

/** Creates and adds a selector instrumentor to this class instrumentor.
 *
 *  @param selector The selector to build and add to this class instrumentor;
 *  @param isClassSelector If YES, then the selector is a class selector.
 *  @return An FPRSelectorInstrumentor if the class/selector combination exists, nil otherwise.
 */
- (nullable FPRSelectorInstrumentor *)buildAndAddSelectorInstrumentorForSelector:(SEL)selector
                                                                 isClassSelector:
                                                                     (BOOL)isClassSelector {
  FPRSelectorInstrumentor *selectorInstrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:selector
                                                  class:_instrumentedClass
                                        isClassSelector:isClassSelector];
  if (selectorInstrumentor) {
    [self addSelectorInstrumentor:selectorInstrumentor];
  }
  return selectorInstrumentor;
}

/** Adds a selector instrumentors to an existing running list of instrumented selectors.
 *
 *  @param selectorInstrumentor A non-nil selector instrumentor, whose SEL objects will be swizzled.
 */
- (void)addSelectorInstrumentor:(nonnull FPRSelectorInstrumentor *)selectorInstrumentor {
  if ([_selectorInstrumentors containsObject:selectorInstrumentor]) {
    FPRAssert(NO, @"You cannot instrument the same selector (%@) twice",
              NSStringFromSelector(selectorInstrumentor.selector));
  }
  [_selectorInstrumentors addObject:selectorInstrumentor];
}

@end
