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

/**
 * @class GINArgument
 * @abstract Encapsulates an argument that is passed to a method.
 */
@interface GINArgument : NSObject

/**
 * @method argumentWithObject:
 * @abstract Creates an GINArgument with an NSObject.
 * @param object The NSObject representing the value of the argument.
 * @return An instance of GINArgument.
 */
+ (instancetype)argumentWithObject:(NSObject *)object;

/**
 * @method argumentWithInteger:
 * @abstract Creates an GINArgument with an NSObject.
 * @param integer The NSInteger representing the value of the argument.
 * @return An instance of GINArgument.
 */
+ (instancetype)argumentWithInteger:(NSInteger)integer;

/**
 * @method setNextArgumentInList:inInvocation:
 * @abstract Reads the next argument in |argumentList| and sets it in the |invocation| object.
 * @param argumentList The list of arguments. Each entry must be of type GINArgument.
 * @param index The argument index to set on the |invocation| object.
 * @param invocation The invocation object to set the argument to.
 * @return YES if the argument was set, NO if there were no arguments left in the list.
 */
+ (BOOL)setNextArgumentInList:(va_list)argumentList
                      atIndex:(NSUInteger)index
                 inInvocation:(NSInvocation *)invocation;
@end
