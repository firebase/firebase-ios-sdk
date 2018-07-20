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

#import "GULRuntimeClassSnapshot.h"

#import <objc/runtime.h>

#import "GULRuntimeClassDiff.h"

@implementation GULRuntimeClassSnapshot {
  /** The class this snapshot is related to. */
  Class _aClass;

  /** The metaclass of aClass. */
  Class _metaclass;

  /** The current set of class properties on aClass. */
  NSMutableSet<NSString *> *_classProperties;

  /** The current set of instance properties on aClass. */
  NSMutableSet<NSString *> *_instanceProperties;

  /** The current set of class selectors on aClass. */
  NSMutableSet<NSString *> *_classSelectors;

  /** The current set of instance selectors on aClass. */
  NSMutableSet<NSString *> *_instanceSelectors;

  /** The current set of class and instance selector IMPs on aClass. */
  NSMutableSet<NSString *> *_imps;

  /** The current hash of this object, updated as the state of this instance changes. */
  NSUInteger _runningHash;
}

- (instancetype)init {
  NSAssert(NO, @"Please use the designated initializer.");
  return nil;
}

- (instancetype)initWithClass:(Class)aClass {
  self = [super init];
  if (self) {
    _aClass = aClass;
    _metaclass = object_getClass(aClass);
    _classProperties = [[NSMutableSet alloc] init];
    _instanceProperties = [[NSMutableSet alloc] init];
    _instanceSelectors = [[NSMutableSet alloc] init];
    _classSelectors = [[NSMutableSet alloc] init];
    _imps = [[NSMutableSet alloc] init];
    _runningHash = [NSStringFromClass(_aClass) hash] ^ [NSStringFromClass(_metaclass) hash];
  }
  return self;
}

- (void)capture {
  [self captureProperties];
  [self captureSelectorsAndImps];
}

- (GULRuntimeClassDiff *)diff:(GULRuntimeClassSnapshot *)otherClassSnapshot {
  GULRuntimeClassDiff *classDiff = [[GULRuntimeClassDiff alloc] init];
  if (_runningHash != [otherClassSnapshot hash]) {
    classDiff.aClass = _aClass;
    [self computeDiffOfProperties:otherClassSnapshot withClassDiff:classDiff];
    [self computeDiffOfSelectorsAndImps:otherClassSnapshot withClassDiff:classDiff];
  }
  return classDiff;
}

- (NSUInteger)hash {
  return _runningHash;
}

- (BOOL)isEqual:(id)object {
  return self->_runningHash == ((GULRuntimeClassSnapshot *)object)->_runningHash;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@> Hash: 0x%lX", _aClass, (unsigned long)[self hash]];
}

#pragma mark - Private methods below -

#pragma mark State capturing methods

/** Captures class and instance properties and saves state in ivars. */
- (void)captureProperties {
  // Capture instance properties.
  unsigned int outCount;
  objc_property_t *instanceProperties = class_copyPropertyList(_aClass, &outCount);
  for (int i = 0; i < outCount; i++) {
    objc_property_t property = instanceProperties[i];
    NSString *propertyString = [NSString stringWithUTF8String:property_getName(property)];
    [_instanceProperties addObject:propertyString];
    _runningHash ^= [propertyString hash];
  }
  free(instanceProperties);

  // Capture class properties.
  outCount = 0;
  objc_property_t *classProperties = class_copyPropertyList(_metaclass, &outCount);
  for (int i = 0; i < outCount; i++) {
    objc_property_t property = classProperties[i];
    NSString *propertyString = [NSString stringWithUTF8String:property_getName(property)];
    [_classProperties addObject:propertyString];
    _runningHash ^= [propertyString hash];
  }
  free(classProperties);
}

/** Captures the class and instance selectors and their IMPs and saves their state in ivars. */
- (void)captureSelectorsAndImps {
  // Capture instance methods and their IMPs.
  unsigned int outCount;
  Method *instanceMethods = class_copyMethodList(_aClass, &outCount);
  for (int i = 0; i < outCount; i++) {
    Method method = instanceMethods[i];
    NSString *methodString = NSStringFromSelector(method_getName(method));
    [_instanceSelectors addObject:methodString];
    IMP imp = method_getImplementation(method);
    NSString *impString =
        [NSString stringWithFormat:@"%p -[%@ %@]", imp, NSStringFromClass(_aClass), methodString];
    NSAssert(![_imps containsObject:impString],
             @"This IMP/method combination has already been captured: %@:%@",
             NSStringFromClass(_aClass), impString);
    [_imps addObject:impString];
    _runningHash ^= [impString hash];
  }
  free(instanceMethods);

  // Capture class methods and their IMPs.
  outCount = 0;
  Method *classMethods = class_copyMethodList(_metaclass, &outCount);
  for (int i = 0; i < outCount; i++) {
    Method method = classMethods[i];
    NSString *methodString = NSStringFromSelector(method_getName(method));
    [_classSelectors addObject:methodString];
    IMP imp = method_getImplementation(method);
    NSString *impString = [NSString
        stringWithFormat:@"%p +[%@ %@]", imp, NSStringFromClass(_metaclass), methodString];
    NSAssert(![_imps containsObject:impString],
             @"This IMP/method combination has already been captured: %@:%@",
             NSStringFromClass(_aClass), impString);
    [_imps addObject:impString];
    _runningHash ^= [impString hash];
  }
  free(classMethods);
}

#pragma mark Diff computation methods

/** Compute the diff of class and instance properties and populates the classDiff with that info.
 *
 *  @param otherClassSnapshot The other class snapshot to diff against.
 *  @param classDiff The diff object to modify.
 */
- (void)computeDiffOfProperties:(GULRuntimeClassSnapshot *)otherClassSnapshot
                  withClassDiff:(GULRuntimeClassDiff *)classDiff {
  if ([_classProperties hash] != [otherClassSnapshot->_classProperties hash]) {
    classDiff.addedClassProperties = [otherClassSnapshot->_classProperties
        objectsPassingTest:^BOOL(NSString *_Nonnull obj, BOOL *_Nonnull stop) {
          return ![self->_classProperties containsObject:obj];
        }];
  }
  if ([_instanceProperties hash] != [otherClassSnapshot->_instanceProperties hash]) {
    classDiff.addedInstanceProperties = [otherClassSnapshot->_instanceProperties
        objectsPassingTest:^BOOL(NSString *_Nonnull obj, BOOL *_Nonnull stop) {
          return ![self->_instanceProperties containsObject:obj];
        }];
  }
}

/** Computes the diff of class and instance selectors and their IMPs and populates the classDiff.
 *
 *  @param otherClassSnapshot The other class snapshot to diff against.
 *  @param classDiff The diff object to modify.
 */
- (void)computeDiffOfSelectorsAndImps:(GULRuntimeClassSnapshot *)otherClassSnapshot
                        withClassDiff:(GULRuntimeClassDiff *)classDiff {
  if ([_classSelectors hash] != [otherClassSnapshot->_classSelectors hash]) {
    classDiff.addedClassSelectors = [otherClassSnapshot->_classSelectors
        objectsPassingTest:^BOOL(NSString *_Nonnull obj, BOOL *_Nonnull stop) {
          return ![self->_classSelectors containsObject:obj];
        }];
  }
  if ([_instanceSelectors hash] != [otherClassSnapshot->_instanceSelectors hash]) {
    classDiff.addedInstanceSelectors = [otherClassSnapshot->_instanceSelectors
        objectsPassingTest:^BOOL(NSString *_Nonnull obj, BOOL *_Nonnull stop) {
          return ![self->_instanceSelectors containsObject:obj];
        }];
  }

  // modifiedImps contains the prior IMP address, not the current IMP address.
  classDiff.modifiedImps =
      [_imps objectsPassingTest:^BOOL(NSString *_Nonnull obj, BOOL *_Nonnull stop) {
        return ![otherClassSnapshot->_imps containsObject:obj];
      }];
}

@end
