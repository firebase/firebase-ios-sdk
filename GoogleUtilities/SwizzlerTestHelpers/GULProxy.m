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

@property(nonatomic, strong) id delegateObject;

@end

@implementation GULProxy

- (instancetype)initWithDelegate:(id)delegate {
  _delegateObject = delegate;
  return self;
}

+ (instancetype)proxyWithDelegate:(id)delegate {
  return [[GULProxy alloc] initWithDelegate:delegate];
}

- (id)forwardingTargetForSelector:(SEL)selector {
  return _delegateObject;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
  if (_delegateObject != nil) {
    [invocation setTarget:_delegateObject];
    [invocation invoke];
  }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
  return [_delegateObject instanceMethodSignatureForSelector:selector];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  return [_delegateObject respondsToSelector:aSelector];
}

- (BOOL)isEqual:(id)object {
  return [_delegateObject isEqual:object];
}

- (NSUInteger)hash {
  return [_delegateObject hash];
}

- (Class)superclass {
  return [_delegateObject superclass];
}

- (Class)class {
  return [_delegateObject class];
}

- (BOOL)isKindOfClass:(Class)aClass {
  return [_delegateObject isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
  return [_delegateObject isMemberOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
  return [_delegateObject conformsToProtocol:aProtocol];
}

- (BOOL)isProxy {
  return YES;
}

- (NSString *)description {
  return [_delegateObject description];
}

- (NSString *)debugDescription {
  return [_delegateObject debugDescription];
}

@end
