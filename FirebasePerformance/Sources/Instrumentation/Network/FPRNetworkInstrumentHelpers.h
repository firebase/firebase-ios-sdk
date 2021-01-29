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
@class FPRClassInstrumentor;

/** Throws an exception declaring that the selector was not found on the class. This is a
 *  convenience function.
 *
 *  This should only be invoked when one of two things has happened:
 *  - The underlying iOS implementation removes a method on a class and we haven't detected it yet.
 *  - We instrument a new method using the wrong selector/class combo and don't discover that
 *    through unit tests or other kinds of testing or development.
 *
 *  @param selector The selector being invoked.
 *  @param aClass The class the selector belongs to.
 *  @throws An exception if invoked.
 */
FOUNDATION_EXTERN
void ThrowExceptionBecauseSelectorNotFoundOnClass(SEL selector, Class aClass);

/** Throws an exception declaring that the selector instrumentor has been deallocated. This is a
 *  convenience function.
 *
 *  This should only be invoked when the selector instrumentor has been deallocated, but for some
 *  reason -unswizzle was not called.
 *
 *  @param selector The selector being invoked.
 *  @param aClass The class the selector belongs to.
 *  @throws An exception if invoked.
 */
FOUNDATION_EXTERN
void ThrowExceptionBecauseSelectorInstrumentorHasBeenDeallocated(SEL selector, Class aClass);

/** Throws an exception declaring that the instrument attempting to register a class has been
 *  deallocated.
 *
 *  This should only be invoked when the instrument of an iOS class cluster has been deallocated,
 *  but not unswizzled.
 *
 *  @param selector The selector being invoked.
 *  @param aClass The class the selector belongs to.
 *  @throws An exception if invoked.
 */
FOUNDATION_EXTERN
void ThrowExceptionBecauseInstrumentHasBeenDeallocated(SEL selector, Class aClass);

/** Returns an FPRSelectorInstrumentor given a SEL and FPRClassInstrumentor. This is a convenience
 *  function.
 *
 *  @param selector The selector to instrument.
 *  @param instrumentor The class instrumentor to generate the selector instrumentor from.
 *  @param isClassSelector YES if the selector is a class selector, NO otherwise.
 *  @return An FPRSelectorInstrumentor instance if the selector is on the class.
 *  @throws An exception if the selector is NOT found on the class.
 */
FOUNDATION_EXTERN
FPRSelectorInstrumentor *SelectorInstrumentor(SEL selector,
                                              FPRClassInstrumentor *instrumentor,
                                              BOOL isClassSelector);
