/*
 * Copyright 2018 Google
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

// Calls a method on a class or object.
#define GINPerformSelector(target, selector) \
  GINPerformSelectorWithArguments(target, selector, 0, nil)

// Calls a method on a class or object, that takes arguments.
#define GINPerformSelectorWithArguments(target, selector, numArgs, args...) \
  [GINInvocation objectByPerformingSelector:selector                        \
                                   onTarget:target                          \
                          numberOfArguments:numArgs, args, nil]

// Calls a method that returns double on a class or object.
#define GINDoubleByPerformingSelector(target, selector) \
  GINDoubleByPerformingSelectorWithArguments(target, selector, 0, nil)

// Calls a method that returns double on a class or object, that takes arguments.
#define GINDoubleByPerformingSelectorWithArguments(target, selector, numArgs, args...) \
  [GINInvocation doubleByPerformingSelector:selector                                   \
                                   onTarget:target                                     \
                          numberOfArguments:numArgs, args, nil]

/**
 * @class GINInvocation
 * @abstract A utility class that provide helper methods to invoke methods on objects and classes.
 */
@interface GINInvocation : NSObject

/**
 * @method objectByPerformingSelector:onTarget:numberOfArguments:...
 * @abstract Performs a selector on a class or object.
 * @param selector The selector to perform.
 * @param target The target class or object to perform the selector on.
 * @param numberOfArguments Number of arguments in the argument list.
 * @param ... An optional argument list, each argument should be of type GINArgument.
 * @return id The result of the selector.
 */
+ (id)objectByPerformingSelector:(SEL)selector
                        onTarget:(id)target
               numberOfArguments:(NSInteger)numberOfArguments, ...;

/**
 * @method doubleByPerformingSelector:onTarget:numberOfArguments:...
 * @abstract Performs a selector on a class or object.
 * @param selector The selector to perform.
 * @param target The target class or object to perform the selector on.
 * @param numberOfArguments Number of arguments in the argument list.
 * @param ... An optional argument list, each argument should be of type GINArgument.
 * @return double The result of the selector.
 */
+ (double)doubleByPerformingSelector:(SEL)selector
                            onTarget:(id)target
                   numberOfArguments:(NSInteger)numberOfArguments, ...;

@end
