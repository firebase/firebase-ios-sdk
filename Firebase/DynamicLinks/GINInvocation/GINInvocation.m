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

#import "DynamicLinks/GINInvocation/GINInvocation.h"

#import "DynamicLinks/GINInvocation/GINArgument.h"

@implementation GINInvocation

// A method that performs a selector on a target object, and return the result.
+ (id)objectByPerformingSelector:(SEL)selector
                        onTarget:(id)target
               numberOfArguments:(NSInteger)numberOfArguments, ... {
  if (![target respondsToSelector:selector]) {
#if DEBUG
    [NSException raise:@"InvalidSelectorException" format:@"Invalid selector send to target"];
#endif
    return nil;
  }

  NSMethodSignature *methodSignature = [target methodSignatureForSelector:selector];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSignature];
  [inv setSelector:selector];
  [inv setTarget:target];

  int index = 2;
  va_list argumentList;

  va_start(argumentList, numberOfArguments);
  for (NSInteger i = 0; i < numberOfArguments; i++) {
    [GINArgument setNextArgumentInList:argumentList atIndex:index inInvocation:inv];
  }
  va_end(argumentList);

  [inv invoke];

  // This method only returns object.
  if ([methodSignature methodReturnLength]) {
    CFTypeRef result;
    [inv getReturnValue:&result];
    if (result) {
      CFRetain(result);
    }
    return (__bridge_transfer id)result;
  }
  return nil;
}

// A method that performs a selector on a target object, and return the result.
+ (double)doubleByPerformingSelector:(SEL)selector
                            onTarget:(id)target
                   numberOfArguments:(NSInteger)numberOfArguments, ... {
  if (![target respondsToSelector:selector]) {
#if DEBUG
    [NSException raise:@"InvalidSelectorException" format:@"Invalid selector send to target"];
#endif
    return 0;
  }

  NSMethodSignature *methodSignature = [target methodSignatureForSelector:selector];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSignature];
  [inv setSelector:selector];
  [inv setTarget:target];

  int index = 2;
  va_list argumentList;

  va_start(argumentList, numberOfArguments);
  for (NSInteger i = 0; i < numberOfArguments; i++) {
    [GINArgument setNextArgumentInList:argumentList atIndex:index inInvocation:inv];
  }
  va_end(argumentList);

  [inv invoke];

  // This method only returns double.
  if ([methodSignature methodReturnLength]) {
    double doubleValue;
    [inv getReturnValue:&doubleValue];
    return doubleValue;
  }
  return 0;
}

@end
