/*
 * Copyright 2018 Google LLC
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

#import "GULProxy.h"

@interface GULProxy ()

@property(nonatomic, strong) id target;

@end

@implementation GULProxy

- (instancetype)initWithTarget:(id)target {
  _target = target;
  return self;
}

+ (instancetype)proxyWithTarget:(id)target {
  return [[GULProxy alloc] initWithTarget:target];
}

- (id)forwardingTargetForSelector:(SEL)selector {
  return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
  if (_target != nil) {
    [invocation setTarget:_target];
    [invocation invoke];
  }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
  return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  return [_target respondsToSelector:aSelector];
}

- (BOOL)isEqual:(id)object {
  return [_target isEqual:object];
}

- (NSUInteger)hash {
  return [_target hash];
}

- (Class)superclass {
  return [_target superclass];
}

- (Class)class {
  return [_target class];
}

- (BOOL)isKindOfClass:(Class)aClass {
  return [_target isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
  return [_target isMemberOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
  return [_target conformsToProtocol:aProtocol];
}

- (BOOL)isProxy {
  return YES;
}

- (NSString *)description {
  return [_target description];
}
- (NSString *)debugDescription {
  return [_target debugDescription];
}

@end
