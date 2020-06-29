/*
 * Copyright 2020 Google LLC
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

typedef void (^FIRTestsAssertionHandlerBlock)(id object, NSString *fileName, NSInteger lineNumber);

@interface FIRTestsAssertionHandler : NSAssertionHandler

/**
 * Sets a handler for assertions in objects of the specified class.
 * @param aClass A class to set an assertion method failure handler.
 * @param handler A custom handler that will be called each time when
 * `-[FIRTestsAssertionHandler handleFailureInMethod:object:file:lineNumber:description:]` is
 * called. If `nil` then
 * `-[super handleFailureInMethod:object:file:lineNumber:description:]` (default implementation)
 * will be called.
 */
- (void)setMethodFailureHandlerForClass:(Class)aClass
                                handler:(nullable FIRTestsAssertionHandlerBlock)handler;

@end

NS_ASSUME_NONNULL_END
