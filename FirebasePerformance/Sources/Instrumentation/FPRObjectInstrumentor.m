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

#import "FirebasePerformance/Sources/Instrumentation/FPRObjectInstrumentor.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"

#import <GoogleUtilities/GULObjectSwizzler.h>

@interface FPRObjectInstrumentor () {
  // The object swizzler instance this instrumentor will use.
  GULObjectSwizzler *_objectSwizzler;
}

@end

@implementation FPRObjectInstrumentor

- (instancetype)init {
  FPRAssert(NO, @"%@: Please use the designated initializer.", NSStringFromClass([self class]));
  return nil;
}

- (instancetype)initWithObject:(id)object {
  self = [super init];
  if (self) {
    _objectSwizzler = [[GULObjectSwizzler alloc] initWithObject:object];
    _instrumentedObject = object;
  }
  return self;
}

- (void)copySelector:(SEL)selector fromClass:(Class)aClass isClassSelector:(BOOL)isClassSelector {
  __strong id instrumentedObject = _instrumentedObject;
  if (instrumentedObject && ![instrumentedObject respondsToSelector:selector]) {
    _hasModifications = YES;
    [_objectSwizzler copySelector:selector fromClass:aClass isClassSelector:isClassSelector];
  }
}

- (void)swizzle {
  if (_hasModifications) {
    [_objectSwizzler swizzle];
  }
}

@end
