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

#import "OCMStubRecorder+FIRAuthUnitTests.h"

#import "FIRAuthGlobalWorkQueue.h"

/** @fn argumentOf
    @brief Retrieves a specific argument from a method invocation.
    @param invocation The Objective-C method invocation.
    @param position The position of the argument to retrieve, starting from 0.
    @return The argument at the given position that the method has been invoked with.
    @remarks The argument type must be compatible with @c id .
 */
static id argumentOf(NSInvocation *invocation, int position) {
  __unsafe_unretained id unretainedArgument;
  // Indices 0 and 1 indicate the hidden arguments self and _cmd. Actual arguments starts from 2.
  [invocation getArgument:&unretainedArgument atIndex:position + 2];
  // The argument needs to be retained, or it will be released along with the invocation object.
  id argument = unretainedArgument;
  return argument;
}

@implementation OCMStubRecorder (FIRAuthUnitTests)

- (id)andCallBlock2:(FIRAuthGeneralBlock2)block2 {
  return [self andDo:^(NSInvocation *invocation) {
    block2(argumentOf(invocation, 0), argumentOf(invocation, 1));
  }];
}

- (id)andDispatchError2:(NSError *)error {
  return [self andCallBlock2:^(id request, FIRAuthGeneralBlock2 callback) {
    dispatch_async(FIRAuthGlobalWorkQueue(), ^() {
      callback(nil, error);
    });
  }];
}

- (OCMStubRecorder *(^)(FIRAuthGeneralBlock2))_andCallBlock2 {
  return ^(FIRAuthGeneralBlock2 block2) {
    return [self andCallBlock2:block2];
  };
}

- (OCMStubRecorder *(^)(NSError *))_andDispatchError2 {
  return ^(NSError *error) {
    return [self andDispatchError2:error];
  };
}

@end
