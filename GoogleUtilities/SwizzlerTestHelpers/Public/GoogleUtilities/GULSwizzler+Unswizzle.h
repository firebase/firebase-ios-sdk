/*
 * Copyright 2019 Google LLC
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

/** This category adds methods for unswizzling that are only used for testing.
 */
@interface GULSwizzler (Unswizzle)

/** Restores the original implementation.
 *
 *  @param aClass The class to unswizzle.
 *  @param selector The selector to restore the original implementation of.
 *  @param isClassSelector A BOOL specifying whether the selector is a class or instance selector.
 */
+ (void)unswizzleClass:(Class)aClass selector:(SEL)selector isClassSelector:(BOOL)isClassSelector;

/** Returns the original IMP for the given class and selector.
 *
 *  @param aClass The class to use.
 *  @param selector The selector to find the implementation of.
 *  @param isClassSelector A BOOL specifying whether the selector is a class or instance selector.
 *  @return The implementation of the selector in the runtime before any consumer or GULSwizzler
 *          swizzled.
 */
+ (nullable IMP)originalImplementationForClass:(Class)aClass
                                      selector:(SEL)selector
                               isClassSelector:(BOOL)isClassSelector;

@end

NS_ASSUME_NONNULL_END
