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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** This class is used to manage the swizzling of selectors on classes. An instance of this class
 *  should be created for every selector that is being swizzled.
 */
@interface FPRSelectorInstrumentor : NSObject

/** The swizzled selector. */
@property(nonatomic, readonly) SEL selector;

/** Please use designated initializer. */
- (instancetype)init NS_UNAVAILABLE;

/** Initializes an instance of this class. The designated initializer.
 *
 *  @note Capture the current IMP outside the replacing block which will be the originalIMP once we
 *      swizzle.
 *
 *  @param selector The selector pointer.
 *  @param aClass The class to operate on.
 *  @param isClassSelector YES specifies that the selector is a class selector.
 *  @return An instance of this class.
 */
- (instancetype)initWithSelector:(SEL)selector
                           class:(Class)aClass
                 isClassSelector:(BOOL)isClassSelector NS_DESIGNATED_INITIALIZER;

/** Sets the instrumentor's replacing block. To be used in conjunction with initWithSelector:.
 *
 *  @param block The block to replace the original implementation with. Make sure to call
 *      originalImp in your replacing block.
 */
- (void)setReplacingBlock:(id)block;

/** The current IMP of the swizzled selector.
 *
 *  @return The current IMP for the class, SEL of the FPRSelectorInstrumentor.
 */
- (IMP)currentIMP;

/** Swizzles the selector. */
- (void)swizzle;

/** Causes the original implementation to be run. */
- (void)unswizzle;

@end

NS_ASSUME_NONNULL_END
