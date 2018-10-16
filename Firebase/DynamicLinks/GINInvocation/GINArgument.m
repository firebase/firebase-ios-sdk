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

#import "GINArgument.h"

// Currently only supporting arguments of types id and integer.
// Will support more argument types when it is needed.
typedef NS_ENUM(NSUInteger, GINArgumentType) {
  kGINArgumentTypeObject = 0,
  kGINArgumentTypeInteger
};

@interface GINArgument ()

@property(nonatomic, assign) GINArgumentType type;

@property(nonatomic, strong) id object;
@property(nonatomic, assign) NSInteger integer;

@end

@implementation GINArgument

+ (instancetype)argumentWithObject:(NSObject *)object {
  GINArgument *arg = [[GINArgument alloc] init];
  arg.type = kGINArgumentTypeObject;
  arg.object = object;
  return arg;
}

+ (instancetype)argumentWithInteger:(NSInteger)integer {
  GINArgument *arg = [[GINArgument alloc] init];
  arg.type = kGINArgumentTypeInteger;
  arg.integer = integer;
  return arg;
}

+ (BOOL)setNextArgumentInList:(va_list)argumentList
                      atIndex:(NSUInteger)index
                 inInvocation:(NSInvocation *)invocation {
  id argument = va_arg(argumentList, id);

  if (!argument) {
    return NO;
  }

  if (![argument isKindOfClass:[GINArgument class]]) {
    [NSException raise:@"InvalidArgumentException"
                format:@"Invalid argument type at index %lu", (unsigned long)index];
  }

  [argument setArgumentInInvocation:invocation atIndex:index];
  return YES;
}

- (void)setArgumentInInvocation:(NSInvocation *)invocation atIndex:(NSUInteger)index {
  switch (self.type) {
    case kGINArgumentTypeObject:
      [invocation setArgument:&_object atIndex:index];
      break;

    case kGINArgumentTypeInteger:
      [invocation setArgument:&_integer atIndex:index];
      break;

    default:
      break;
  }
}

@end
