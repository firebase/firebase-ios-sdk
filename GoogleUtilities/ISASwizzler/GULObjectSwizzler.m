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

#import "GoogleUtilities/ISASwizzler/Public/GoogleUtilities/GULObjectSwizzler.h"

#import <objc/runtime.h>

#import "GoogleUtilities/ISASwizzler/Public/GoogleUtilities/GULSwizzledObject.h"

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
  if (object == nil) {
    return nil;
  }

  GULObjectSwizzler *existingSwizzler =
      [[self class] getAssociatedObject:object key:kSwizzlerAssociatedObjectKey];
  if ([existingSwizzler isKindOfClass:[GULObjectSwizzler class]]) {
    // The object has been swizzled already, no need to swizzle again.
    return existingSwizzler;
  }

  self = [super init];
  if (self) {
    _swizzledObject = object;
    _originalClass = object_getClass(object);
    NSString *newClassName = [NSString stringWithFormat:@"fir_%@_%@", [[NSUUID UUID] UUIDString],
                                                        NSStringFromClass(_originalClass)];
    _generatedClass = objc_allocateClassPair(_originalClass, newClassName.UTF8String, 0);
    NSAssert(_generatedClass, @"Wasn't able to allocate the class pair.");
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
  class_replaceMethod(targetClass, selector, implementation, typeEncoding);
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

  GULObjectSwizzler *existingSwizzler =
      [[self class] getAssociatedObject:swizzledObject key:kSwizzlerAssociatedObjectKey];
  if (existingSwizzler != nil) {
    NSAssert(existingSwizzler == self, @"The swizzled object has a different swizzler.");
    // The object has been swizzled already.
    return;
  }

  if (swizzledObject) {
    [GULObjectSwizzler setAssociatedObject:swizzledObject
                                       key:kSwizzlerAssociatedObjectKey
                                     value:self
                               association:GUL_ASSOCIATION_RETAIN];

    [GULSwizzledObject copyDonorSelectorsUsingObjectSwizzler:self];

    NSAssert(_originalClass == object_getClass(swizzledObject),
             @"The original class is not the reported class now.");
    NSAssert(class_getInstanceSize(_originalClass) == class_getInstanceSize(_generatedClass),
             @"The instance size of the generated class must be equal to the original class.");
    objc_registerClassPair(_generatedClass);
    Class doubleCheckOriginalClass __unused = object_setClass(_swizzledObject, _generatedClass);
    NSAssert(_originalClass == doubleCheckOriginalClass,
             @"The original class must be the same as the class returned by object_setClass");
  } else {
    NSAssert(NO, @"You can't swizzle a nil object");
  }
}

- (void)dealloc {
  if (_generatedClass) {
    if (_swizzledObject == nil) {
      // The swizzled object has been deallocated already, so the generated class can be disposed
      // now.
      objc_disposeClassPair(_generatedClass);
      return;
    }

    // GULSwizzledObject is retained by the swizzled object which means that the swizzled object is
    // being deallocated now. Let's see if we should schedule the generated class disposal.

    // If the swizzled object has a different class, it most likely indicates that the object was
    // ISA swizzled one more time. In this case it is not safe to dispose the generated class. We
    // will have to keep it to prevent a crash.

    // TODO: Consider adding a flag that can be set by the host application to dispose the class
    // pair unconditionally. It may be used by apps that use ISA Swizzling themself and are
    // confident in disposing their subclasses.
    BOOL isSwizzledObjectInstanceOfGeneratedClass =
        object_getClass(_swizzledObject) == _generatedClass;

    if (isSwizzledObjectInstanceOfGeneratedClass) {
      Class generatedClass = _generatedClass;

      // Schedule the generated class disposal after the swizzled object has been deallocated.
      dispatch_async(dispatch_get_main_queue(), ^{
        objc_disposeClassPair(generatedClass);
      });
    }
  }
}

- (BOOL)isSwizzlingProxyObject {
  return [_swizzledObject isProxy];
}

@end
