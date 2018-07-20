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

#import "Private/GULObjectSwizzler.h"

#import <objc/runtime.h>

#import "Private/GULSwizzledObject.h"

@implementation GULObjectSwizzler {
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
                association:(GUL_ASSOCIATION)association {
  objc_AssociationPolicy resolvedAssociation;
  switch (association) {
    case GUL_ASSOCIATION_ASSIGN:
      resolvedAssociation = OBJC_ASSOCIATION_ASSIGN;
      break;

    case GUL_ASSOCIATION_RETAIN_NONATOMIC:
      resolvedAssociation = OBJC_ASSOCIATION_RETAIN_NONATOMIC;
      break;

    case GUL_ASSOCIATION_COPY_NONATOMIC:
      resolvedAssociation = OBJC_ASSOCIATION_COPY_NONATOMIC;
      break;

    case GUL_ASSOCIATION_RETAIN:
      resolvedAssociation = OBJC_ASSOCIATION_RETAIN;
      break;

    case GUL_ASSOCIATION_COPY:
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
      NSString *newClassName = [NSString
          stringWithFormat:@"fir_%p_%@", swizzledObject, NSStringFromClass(_originalClass)];
      _generatedClass = objc_allocateClassPair(_originalClass, newClassName.UTF8String, 0);
      NSAssert(_generatedClass, @"Wasn't able to allocate the class pair.");
    } else {
      return nil;
    }
  }
  return self;
}

- (void)copySelector:(SEL)selector fromClass:(Class)aClass isClassSelector:(BOOL)isClassSelector {
  NSAssert(_generatedClass, @"This object has already been unswizzled.");
  Method method = isClassSelector ? class_getClassMethod(aClass, selector)
                                  : class_getInstanceMethod(aClass, selector);
  Class targetClass = isClassSelector ? object_getClass(_generatedClass) : _generatedClass;
  IMP implementation = method_getImplementation(method);
  const char *typeEncoding = method_getTypeEncoding(method);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
  BOOL success = class_addMethod(targetClass, selector, implementation, typeEncoding);
  NSAssert(success, @"Unable to add selector %@ to class %@", NSStringFromSelector(selector),
           NSStringFromClass(targetClass));
#pragma clang diagnostic pop
}

- (void)setAssociatedObjectWithKey:(NSString *)key
                             value:(id)value
                       association:(GUL_ASSOCIATION)association {
  __strong id swizzledObject = _swizzledObject;
  if (swizzledObject) {
    [[self class] setAssociatedObject:swizzledObject key:key value:value association:association];
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
    [GULObjectSwizzler setAssociatedObject:swizzledObject
                                       key:kSwizzlerAssociatedObjectKey
                                     value:self
                               association:GUL_ASSOCIATION_RETAIN_NONATOMIC];

    [GULSwizzledObject copyDonorSelectorsUsingObjectSwizzler:self];

    NSAssert(_originalClass == [_swizzledObject class],
             @"The original class is not the reported class now.");
    NSAssert(class_getInstanceSize(_originalClass) == class_getInstanceSize(_generatedClass),
             @"The instance size of the generated class must be equal to the original class.");
    objc_registerClassPair(_generatedClass);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    Class doubleCheckOriginalClass = object_setClass(_swizzledObject, _generatedClass);
    NSAssert(_originalClass == doubleCheckOriginalClass,
             @"The original class must be the same as the class returned by object_setClass");
#pragma clang diagnostic pop
  } else {
    NSAssert(NO, @"You can't swizzle a nil object");
  }
}

- (void)dealloc {
  objc_disposeClassPair(_generatedClass);
}

@end
