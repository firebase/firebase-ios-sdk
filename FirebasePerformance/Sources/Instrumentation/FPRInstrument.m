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

#import <objc/runtime.h>

#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRObjectInstrumentor.h"

@implementation FPRInstrument {
  NSMutableArray<FPRClassInstrumentor *> *_classInstrumentors;

  NSMutableSet<Class> *_instrumentedClasses;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _classInstrumentors = [[NSMutableArray<FPRClassInstrumentor *> alloc] init];
    _instrumentedClasses = [[NSMutableSet<Class> alloc] init];
  }
  return self;
}

- (NSMutableArray<FPRClassInstrumentor *> *)classInstrumentors {
  return _classInstrumentors;
}

- (NSMutableSet<Class> *)instrumentedClasses {
  return _instrumentedClasses;
}

- (void)registerInstrumentors {
  FPRAssert(NO, @"registerInstrumentors should be implemented in a concrete subclass.");
}

- (BOOL)isObjectInstrumentable:(id)object {
  if (!object || (![object isProxy] && [object isKindOfClass:[NSOperation class]])) {
    return NO;
  }
  Class objectClass = [object isProxy] ? object_getClass(object) : [object class];
  return [self isClassInstrumentable:objectClass];
}

- (BOOL)isClassInstrumentable:(Class)aClass {
  NSString *className = NSStringFromClass(aClass);
  if (!className) {
    // If the className is nil, it should be a no-op.
    return NO;
  }

  if ([[FPRConfigurations sharedInstance].swizzleClassDenylist containsObject:className]) {
    FPRLogInfo(kFPRSwizzleClassDenylisted,
               @"Skipped swizzling %@ because it is listed in "
               @"firebase_performance_swizzle_denylist.",
               className);
    return NO;
  }

  return YES;
}

- (BOOL)registerClassInstrumentor:(FPRClassInstrumentor *)instrumentor {
  @synchronized(self) {
    // Check if it's in the denylist.
    if (![self isClassInstrumentable:instrumentor.instrumentedClass]) {
      return NO;
    }

    if ([_instrumentedClasses containsObject:instrumentor.instrumentedClass] ||
        [instrumentor.instrumentedClass instancesRespondToSelector:@selector(gul_class)]) {
      return NO;
    }
    [_instrumentedClasses addObject:instrumentor.instrumentedClass];
    [_classInstrumentors addObject:instrumentor];
    return YES;
  }
}

- (void)deregisterInstrumentors {
  @synchronized(self) {
    for (FPRClassInstrumentor *classInstrumentor in self.classInstrumentors) {
      [classInstrumentor unswizzle];
    }
    [_classInstrumentors removeAllObjects];
    [_instrumentedClasses removeAllObjects];
  }
}

@end
