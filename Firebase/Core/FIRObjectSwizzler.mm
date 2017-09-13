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

#import "FirebaseCommunity/FIRObjectSwizzler.h"

#import <objc/runtime.h>

#import "FirebaseCommunity/FIRSwizzledObject.h"
#import "FirebaseCommunity/FIRSwizzlingCaches.h"
#import "FirebaseCommunity/FIRSwizzler.h"


@implementation FIRObjectSwizzler {

  // The swizzled object.
  __weak id _swizzledObject;

  // The original class of the object.
  Class _originalClass;

  // The dynamically generated subclass of _originalClass.
  Class _generatedClass;
}

#pragma mark - Class methods

+ (void)setAssociatedObject:(id)object
                        key:(NSString *)key
                      value:(nullable id)value
                association:(FIR_ASSOCIATION)association {
  objc_AssociationPolicy resolvedAssociation;
  switch (association) {
    case FIR_ASSOCIATION_ASSIGN:
      resolvedAssociation = OBJC_ASSOCIATION_ASSIGN;
      break;

    case FIR_ASSOCIATION_RETAIN_NONATOMIC:
      resolvedAssociation = OBJC_ASSOCIATION_RETAIN_NONATOMIC;
      break;

    case FIR_ASSOCIATION_COPY_NONATOMIC:
      resolvedAssociation = OBJC_ASSOCIATION_COPY_NONATOMIC;
      break;

    case FIR_ASSOCIATION_RETAIN:
      resolvedAssociation = OBJC_ASSOCIATION_RETAIN;
      break;

    case FIR_ASSOCIATION_COPY:
      resolvedAssociation = OBJC_ASSOCIATION_COPY;
      break;

    default:
      break;
  }
  objc_setAssociatedObject(object, key.UTF8String, value, resolvedAssociation);
}

+ (nullable id)getAssociatedObject:(id)object key:(NSString *)key {
  return objc_getAssociatedObject(object, key.UTF8String);
}

#pragma mark - Instance methods

/** Instantiates an instance of this class.
 *
 *  @param object The object to swizzle.
 *  @return An instance of this class.
 */
- (instancetype)initWithObject:(id)object {
  self = [super init];
  if (self) {
    __strong id swizzledObject = object;
    if (swizzledObject) {
      _swizzledObject = swizzledObject;
      _originalClass = [swizzledObject class];
      NSString *newClassName = [NSString stringWithFormat:@"fpr_%p_%@",
                                swizzledObject,
                                NSStringFromClass(_originalClass)];
      _generatedClass = objc_allocateClassPair(_originalClass, newClassName.UTF8String, 0);
      NSAssert(_generatedClass, @"Wasn't able to allocate the class pair.");
    } else {
      return nil;
    }
  }
  return self;
}

- (void)copySelector:(SEL)selector
           fromClass:(Class)aClass
     isClassSelector:(BOOL)isClassSelector {
  NSAssert(_generatedClass, @"This object has already been unswizzled.");
  Method method = isClassSelector ? class_getClassMethod(aClass, selector) :
  class_getInstanceMethod(aClass, selector);
  Class targetClass = isClassSelector ? object_getClass(_generatedClass) : _generatedClass;
  IMP implementation = method_getImplementation(method);
  const char *typeEncoding = method_getTypeEncoding(method);
  BOOL success = class_addMethod(targetClass, selector, implementation, typeEncoding);
  NSAssert(success,
           @"Unable to add selector %@ to class %@",
           NSStringFromSelector(selector),
           NSStringFromClass(targetClass));
}

- (void)setAssociatedObjectWithKey:(NSString *)key
                             value:(id)value
                       association:(FIR_ASSOCIATION)association {
  __strong id swizzledObject = _swizzledObject;
  if (swizzledObject) {
    [[self class] setAssociatedObject:swizzledObject
                                  key:key
                                value:value
                          association:association];
  }
}

- (nullable id)getAssociatedObjectForKey:(NSString *)key {
  __strong id swizzledObject = _swizzledObject;
  if (swizzledObject) {
    return [[self class] getAssociatedObject:swizzledObject key:key];
  }
  return nil;
}

- (void)swizzle {
  __strong id swizzledObject = _swizzledObject;
  if (swizzledObject) {
    [FIRObjectSwizzler setAssociatedObject:swizzledObject
                                       key:kSwizzlerAssociatedObjectKey
                                     value:self
                               association:FIR_ASSOCIATION_RETAIN_NONATOMIC];

    [FIRSwizzledObject copyDonorSelectorsUsingObjectSwizzler:self];

    NSAssert(_originalClass == [_swizzledObject class],
             @"The original class is not the reported class now.");
    NSAssert(class_getInstanceSize(_originalClass) == class_getInstanceSize(_generatedClass),
             @"The instance size of the generated class must be equal to the original class.");
    objc_registerClassPair(_generatedClass);
    Class doubleCheckOriginalClass = object_setClass(_swizzledObject, _generatedClass);
    NSAssert(_originalClass == doubleCheckOriginalClass,
             @"The original class must be the same as the class returned by object_setClass");
  } else {
    NSAssert(NO, @"You can't swizzle a nil object");
  }
}

- (void)dealloc {
  objc_disposeClassPair(_generatedClass);
}

@end
