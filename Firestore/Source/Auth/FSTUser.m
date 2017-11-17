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

#import "Firestore/Source/Auth/FSTUser.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTUser

@implementation FSTUser

@dynamic unauthenticated;

+ (instancetype)unauthenticatedUser {
  return [[FSTUser alloc] initWithUID:nil];
}

- (instancetype)initWithUID:(NSString *_Nullable)UID {
  if (self = [super init]) {
    _UID = UID;
  }
  return self;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  } else if (![object isKindOfClass:[FSTUser class]]) {
    return NO;
  } else {
    FSTUser *other = object;
    return (self.isUnauthenticated && other.isUnauthenticated) ||
           [self.UID isEqualToString:other.UID];
  }
}

- (NSUInteger)hash {
  return [self.UID hash];
}

- (id)copyWithZone:(nullable NSZone *)zone {
  return self;  // since FSTUser objects are immutable
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTUser uid=%@>", self.UID];
}

- (BOOL)isUnauthenticated {
  return self.UID == nil;
}

@end

NS_ASSUME_NONNULL_END
