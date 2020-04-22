/*
 * Copyright 2017 Google
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

FOUNDATION_EXPORT NSString *const kFIRMessagingContextManagerCategory;
FOUNDATION_EXPORT NSString *const kFIRMessagingContextManagerLocalTimeStart;
FOUNDATION_EXPORT NSString *const kFIRMessagingContextManagerLocalTimeEnd;
FOUNDATION_EXPORT NSString *const kFIRMessagingContextManagerBodyKey;

@interface FIRMessagingContextManagerService : NSObject

/**
 *  Check if the message is a context manager message or not.
 *
 *  @param message The message to verify.
 *
 *  @return YES if the message is a context manager message else NO.
 */
+ (BOOL)isContextManagerMessage:(NSDictionary *)message;

/**
 *  Handle context manager message.
 *
 *  @param message The message to handle.
 *
 *  @return YES if the message was handled successfully else NO.
 */
+ (BOOL)handleContextManagerMessage:(NSDictionary *)message;

@end
