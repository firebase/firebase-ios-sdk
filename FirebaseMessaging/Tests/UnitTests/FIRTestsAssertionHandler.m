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

#import "FirebaseMessaging/Tests/UnitTests/FIRTestsAssertionHandler.h"

@interface FIRTestsAssertionHandler ()

@property(nonatomic)
    NSMutableDictionary<NSString *, FIRTestsAssertionHandlerBlock> *methodFailureHandlers;

@end

@implementation FIRTestsAssertionHandler

- (instancetype)init {
  self = [super init];
  if (self) {
    _methodFailureHandlers = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)handleFailureInMethod:(SEL)selector
                       object:(id<NSObject>)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(NSString *)format, ... {
  FIRTestsAssertionHandlerBlock handler;
  @synchronized(self) {
    handler = self.methodFailureHandlers[NSStringFromClass([object class])];
  }

  if (handler) {
    handler(object, fileName, line);
  } else {
    [super handleFailureInMethod:selector
                          object:object
                            file:fileName
                      lineNumber:line
                     description:@"%@", format];
  }
}

- (void)setMethodFailureHandlerForClass:(Class)aClass
                                handler:(FIRTestsAssertionHandlerBlock)handler {
  @synchronized(self) {
    self.methodFailureHandlers[NSStringFromClass(aClass)] = [handler copy];
  }
}

@end
