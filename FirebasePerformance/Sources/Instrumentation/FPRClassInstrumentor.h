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

@class FPRSelectorInstrumentor;

NS_ASSUME_NONNULL_BEGIN

/**
 * Each instrumented class (even classes within class clusters) needs to have its own instrumentor.
 */
@interface FPRClassInstrumentor : NSObject

/** The class being instrumented. */
@property(nonatomic, readonly) Class instrumentedClass;

/** Please use the designated initializer. */
- (instancetype)init NS_UNAVAILABLE;

/** Initializes with a class name and stores a reference to that string. This is the designated
 *  initializer.
 *
 *  @param aClass The class to be instrumented.
 *  @return An instance of this class.
 */
- (instancetype)initWithClass:(Class)aClass NS_DESIGNATED_INITIALIZER;

/** Creates and adds a class selector instrumentor to this class instrumentor.
 *
 *  @param selector The selector to build and add to this class instrumentor;
 *  @return An FPRSelectorInstrumentor if the class/selector combination exists, nil otherwise.
 */
- (nullable FPRSelectorInstrumentor *)instrumentorForClassSelector:(SEL)selector;

/** Creates and adds an instance selector instrumentor to this class instrumentor.
 *
 *  @param selector The selector to build and add to this class instrumentor;
 *  @return An FPRSelectorInstrumentor if the class/selector combination exists, nil otherwise.
 */
- (nullable FPRSelectorInstrumentor *)instrumentorForInstanceSelector:(SEL)selector;

/** Swizzles the set of selector instrumentors. */
- (void)swizzle;

/** Removes all selector instrumentors and unswizzles their implementations. */
- (BOOL)unswizzle;

@end

NS_ASSUME_NONNULL_END
