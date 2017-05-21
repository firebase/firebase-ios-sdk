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

#import "FIRMessagingInstanceIDProxy.h"

@implementation FIRMessagingInstanceIDProxy

+ (nonnull instancetype)instanceIDProxy {
  static id proxyInstanceID = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class instanceIDClass = NSClassFromString(@"FIRInstanceID");
    if (!instanceIDClass) {
      proxyInstanceID = nil;
      return;
    }
    SEL instanceIDSelector = NSSelectorFromString(@"instanceID");
    if (![instanceIDClass respondsToSelector:instanceIDSelector]) {
      proxyInstanceID = nil;
      return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    proxyInstanceID = [instanceIDClass performSelector:instanceIDSelector];
#pragma clang diagnostic pop
  });
  return (FIRMessagingInstanceIDProxy *)proxyInstanceID;

}

- (void)setAPNSToken:(nonnull NSData *)token
                type:(FIRMessagingInstanceIDProxyAPNSTokenType)type {
  id proxy = [[self class] instanceIDProxy];

  SEL setAPNSTokenSelector = NSSelectorFromString(@"setAPNSToken:type:");
  if (![proxy respondsToSelector:setAPNSTokenSelector]) {
    return;
  }
  // Since setAPNSToken takes a scalar value, use NSInvocation
  NSMethodSignature *methodSignature =
      [[proxy class] instanceMethodSignatureForSelector:setAPNSTokenSelector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  invocation.selector = setAPNSTokenSelector;
  invocation.target = proxy;
  [invocation setArgument:&token atIndex:2];
  [invocation setArgument:&type atIndex:3];
  [invocation invoke];
}

#pragma mark - Tokens

- (nullable NSString *)token {
  id proxy = [[self class] instanceIDProxy];
  SEL getTokenSelector = NSSelectorFromString(@"token");
  if (![proxy respondsToSelector:getTokenSelector]) {
    return nil;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  return [proxy performSelector:getTokenSelector];
#pragma clang diagnostic pop
}


- (void)tokenWithAuthorizedEntity:(nonnull NSString *)authorizedEntity
                            scope:(nonnull NSString *)scope
                          options:(nullable NSDictionary *)options
                          handler:(nonnull FIRMessagingInstanceIDProxyTokenHandler)handler {

  id proxy = [[self class] instanceIDProxy];
  SEL getTokenSelector = NSSelectorFromString(@"tokenWithAuthorizedEntity:scope:options:handler:");
  if (![proxy respondsToSelector:getTokenSelector]) {
    return;
  }
  // Since there are >2 arguments, use NSInvocation
  NSMethodSignature *methodSignature =
      [[proxy class] instanceMethodSignatureForSelector:getTokenSelector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  invocation.selector = getTokenSelector;
  invocation.target = proxy;
  [invocation setArgument:&authorizedEntity atIndex:2];
  [invocation setArgument:&scope atIndex:3];
  [invocation setArgument:&options atIndex:4];
  [invocation setArgument:&handler atIndex:5];
  [invocation invoke];
}

- (void)deleteTokenWithAuthorizedEntity:(nonnull NSString *)authorizedEntity
                                  scope:(nonnull NSString *)scope
                                handler:
      (nonnull FIRMessagingInstanceIDProxyDeleteTokenHandler)handler {

  id proxy = [[self class] instanceIDProxy];
  SEL deleteTokenSelector = NSSelectorFromString(@"deleteTokenWithAuthorizedEntity:scope:handler:");
  if (![proxy respondsToSelector:deleteTokenSelector]) {
    return;
  }
  // Since there are >2 arguments, use NSInvocation
  NSMethodSignature *methodSignature =
      [[proxy class] instanceMethodSignatureForSelector:deleteTokenSelector];
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
  invocation.selector = deleteTokenSelector;
  invocation.target = proxy;
  [invocation setArgument:&authorizedEntity atIndex:2];
  [invocation setArgument:&scope atIndex:3];
  [invocation setArgument:&handler atIndex:4];
  [invocation invoke];
}

@end
