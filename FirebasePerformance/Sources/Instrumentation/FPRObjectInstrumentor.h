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

#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument.h"

#import <GoogleUtilities/GULSwizzledObject.h>

@class FPRSelectorInstrumentor;

NS_ASSUME_NONNULL_BEGIN

/** Defines the interface that an instrumentor should implement if they are going to instrument
 *  objects.
 */
@protocol FPRObjectInstrumentorProtocol <NSObject>

@required

/** Registers an instance of the delegate class to be instrumented.
 *
 *  @param object The instance to instrument.
 */
- (void)registerObject:(id)object;

@end

/** This class allows the instrumentation of specific objects by isa swizzling specific instances
 *  with a dynamically generated subclass of the object's original class and installing methods
 *  onto this new class.
 */
@interface FPRObjectInstrumentor : FPRInstrument

/** The instrumented object. */
@property(nonatomic, weak) id instrumentedObject;

/** YES if there is reason to swizzle, NO if swizzling is not needed. */
@property(nonatomic) BOOL hasModifications;

/** Please use the designated initializer. */
- (instancetype)init NS_UNAVAILABLE;

/** Instantiates an instance of this class. The designated initializer.
 *
 *  @param object The object to be instrumented.
 *  @return An instance of this class.
 */
- (instancetype)initWithObject:(id)object NS_DESIGNATED_INITIALIZER;

/** Attempts to copy a selector from a donor class onto the dynamically generated subclass that the
 *  object will adopt when -swizzle is called.
 *
 *  @param selector The selector to use.
 *  @param aClass The class to copy the selector from.
 *  @param isClassSelector YES if the selector is a class selector, NO otherwise.
 */
- (void)copySelector:(SEL)selector fromClass:(Class)aClass isClassSelector:(BOOL)isClassSelector;

/** Swizzles the isa of the object and sets its class to the dynamically created subclass. */
- (void)swizzle;

@end

NS_ASSUME_NONNULL_END
