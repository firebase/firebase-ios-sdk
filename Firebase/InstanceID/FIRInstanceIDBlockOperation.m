/*
 * Copyright 2019 Google
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

#import "FIRInstanceIDBlockOperation.h"
#import "FIRInstanceIDDefines.h"

@interface FIRInstanceIDBlockOperation ()
@property(nonatomic, readonly) FIRInstanceIDOperationBlock operationBlock;
@property(nonatomic, assign) BOOL operationExecuting;
@property(nonatomic, assign) BOOL operationFinished;
@end

@implementation FIRInstanceIDBlockOperation

- (instancetype)initWithBlock:(FIRInstanceIDOperationBlock)block {
  self = [super init];
  if (self) {
    _operationBlock = [block copy];
  }
  return self;
}

#pragma mark - NSOperation Async task routine

- (BOOL)isAsynchronous {
  return YES;
}

- (BOOL)isExecuting {
  return self.operationExecuting;
}

- (void)setOperationExecuting:(BOOL)operationExecuting {
  [self willChangeValueForKey:@"isExecuting"];
  _operationExecuting = operationExecuting;
  [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isFinished {
  return self.operationFinished;
}

- (void)setOperationFinished:(BOOL)operationFinished {
  [self willChangeValueForKey:@"isFinished"];
  _operationFinished = operationFinished;
  [self didChangeValueForKey:@"isFinished"];
}

- (void)start {
  if (self.cancelled) {
    [self finishOperation];
  } else {
    self.operationExecuting = YES;
    [self main];
  }
}

- (void)finishOperation {
  self.operationExecuting = NO;
  self.operationFinished = YES;
}

#pragma mark - Main

- (void)main {
  FIRInstanceID_WEAKIFY(self);
  self.operationBlock(^{
    FIRInstanceID_STRONGIFY(self);
    [self finishOperation];
  });
}

@end
