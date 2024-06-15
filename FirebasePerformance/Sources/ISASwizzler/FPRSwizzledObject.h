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

@class FPRObjectSwizzler;

/** This class exists as a method donor. These methods will be added to all objects that are
 *  swizzled by the object swizzler. This class should not be instantiated.
 */
@interface FPRSwizzledObject : NSObject

- (instancetype)init NS_UNAVAILABLE;

/** Copies the methods below to the swizzled object.
 *
 *  @param objectSwizzler The swizzler to use when adding the methods below.
 */
+ (void)copyDonorSelectorsUsingObjectSwizzler:(FPRObjectSwizzler *)objectSwizzler;

#pragma mark - Donor methods.

/** @return The generated subclass. Used in respondsToSelector: calls. */
- (Class)gul_class;

/** @return The object swizzler that manages this object. */
- (FPRObjectSwizzler *)gul_objectSwizzler;

@end

NS_ASSUME_NONNULL_END
