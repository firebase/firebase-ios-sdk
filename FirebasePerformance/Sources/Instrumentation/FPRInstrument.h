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

@class FPRClassInstrumentor;

NS_ASSUME_NONNULL_BEGIN

/** FPRInstrument instances can instrument many different classes, but should try to instrument
 *  only a single class in the general case. Due to class clusters, FPRInstruments need to be able
 *  to support logical groups of classes, even if the public API is a single class (e.g.
 *  NSDictionary or NSURLSession. FPRInstrument is expected to be subclassed by other classes that
 *  actually implement the instrument. Subclasses should provide their own implementations of
 *  registerInstrumentor
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FPRInstrument : NSObject

/** The list of class instrumentors. count should == 1 in most cases, and be > 1 for class clusters.
 */
@property(nonatomic, readonly) NSArray<FPRClassInstrumentor *> *classInstrumentors;

/** A set of the instrumented classes. */
@property(nonatomic, readonly) NSSet<Class> *instrumentedClasses;

/**
 * Checks if the given object is instrumentable and returns YES if instrumentable. NO, otherwise.
 *
 * @param object Object that needs to be validated.
 * @return Yes if instrumentable, NO otherwise.
 */
- (BOOL)isObjectInstrumentable:(id)object;

/** Registers all instrumentors this instrument will utilize. Should be instrumented in a subclass.
 *
 *  @note This method is thread-safe.
 */
- (void)registerInstrumentors;

/** Deregisters the instrumentors by using API provided by FPRClassInstrumentor. Called by dealloc.
 *
 *  @note This method is thread-safe.
 */
- (void)deregisterInstrumentors;

@end

NS_ASSUME_NONNULL_END
