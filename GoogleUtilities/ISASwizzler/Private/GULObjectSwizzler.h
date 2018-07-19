/*
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Enums that map to their OBJC-prefixed counterparts. */
typedef OBJC_ENUM(uintptr_t, GUL_ASSOCIATION){

    // Is a weak association.
    GUL_ASSOCIATION_ASSIGN,

    // Is a nonatomic strong association.
    GUL_ASSOCIATION_RETAIN_NONATOMIC,

    // Is a nonatomic copy association.
    GUL_ASSOCIATION_COPY_NONATOMIC,

    // Is an atomic strong association.
    GUL_ASSOCIATION_RETAIN,

    // Is an atomic copy association.
    GUL_ASSOCIATION_COPY};

/** This class handles swizzling a specific instance of a class by generating a
 *  dynamic subclass and installing selectors and properties onto the dynamic
 *  subclass. Then, the instance's class is set to the dynamic subclass. There
 *  should be a 1:1 ratio of object swizzlers to swizzled instances.
 */
@interface GULObjectSwizzler : NSObject

/** The subclass that is generated. */
@property(nullable, nonatomic, readonly) Class generatedClass;

/** Sets an associated object in the runtime. This mechanism can be used to
 *  simulate adding properties.
 *
 *  @param object The object that will be queried for the associated object.
 *  @param key The key of the associated object.
 *  @param value The value to associate to the swizzled object.
 *  @param association The mechanism to use when associating the objects.
 */
+ (void)setAssociatedObject:(id)object
                        key:(NSString *)key
                      value:(nullable id)value
                association:(GUL_ASSOCIATION)association;

/** Gets an associated object in the runtime. This mechanism can be used to
 *  simulate adding properties.
 *
 *  @param object The object that will be queried for the associated object.
 *  @param key The key of the associated object.
 */
+ (nullable id)getAssociatedObject:(id)object key:(NSString *)key;

/** Please use the designated initializer. */
- (instancetype)init NS_UNAVAILABLE;

/** Instantiates an object swizzler using an object it will operate on.
 *  Generates a new class pair.
 *
 *  @note There is no need to store this object. After calling -swizzle, this
 *  object can be found by calling -gul_objectSwizzler
 *
 *  @param object The object to be swizzled.
 *  @return An instance of this class.
 */
- (instancetype)initWithObject:(id)object NS_DESIGNATED_INITIALIZER;

/** Sets an associated object in the runtime. This mechanism can be used to
 *  simulate adding properties.
 *
 *  @param key The key of the associated object.
 *  @param value The value to associate to the swizzled object.
 *  @param association The mechanism to use when associating the objects.
 */
- (void)setAssociatedObjectWithKey:(NSString *)key
                             value:(id)value
                       association:(GUL_ASSOCIATION)association;

/** Gets an associated object in the runtime. This mechanism can be used to
 *  simulate adding properties.
 *
 *  @param key The key of the associated object.
 */
- (nullable id)getAssociatedObjectForKey:(NSString *)key;

/** Copies a selector from an existing class onto the generated dynamic subclass
 *  that this object will adopt. This mechanism can be used to add methods to
 *  specific instances of a class.
 *
 *  @note Should not be called after calling -swizzle.
 *  @param selector The selector to add to the instance.
 *  @param aClass The class supplying an implementation of the method.
 *  @param isClassSelector A BOOL specifying whether the selector is a class or
 * instance selector.
 */
- (void)copySelector:(SEL)selector fromClass:(Class)aClass isClassSelector:(BOOL)isClassSelector;

/** Swizzles the object, changing its class to the generated class. Registers
 *  the class pair. */
- (void)swizzle;

@end

NS_ASSUME_NONNULL_END
