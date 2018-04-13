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

// Note: This is forked from FIRMessagingInstanceIDProxy.m

#import "FUNInstanceIDProxy.h"

@implementation FUNInstanceIDProxy

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
    IMP instanceIDImp = [instanceIDClass methodForSelector:instanceIDSelector];
    id (*instanceIDFunc)(id, SEL) = (void *)instanceIDImp;
    proxyInstanceID = instanceIDFunc(instanceIDClass, instanceIDSelector);
  });
  return (FUNInstanceIDProxy *)proxyInstanceID;
}

#pragma mark - Tokens

- (nullable NSString *)token {
  id proxy = [[self class] instanceIDProxy];
  SEL getTokenSelector = NSSelectorFromString(@"token");
  if (![proxy respondsToSelector:getTokenSelector]) {
    return nil;
  }
  IMP getTokenIMP = [proxy methodForSelector:getTokenSelector];
  NSString *(*getToken)(id, SEL) = (void *)getTokenIMP;
  return getToken(proxy, getTokenSelector);
}

@end
