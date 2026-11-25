/*
 * Copyright 2026 Google LLC
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

#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsFakeSecureStorage.h"

@interface FIRInstallationsFakeSecureStorage ()
@property(nonatomic, readonly) NSMutableDictionary<NSString *, NSData *> *items;
@property(nonatomic, readonly) dispatch_queue_t queue;
@end

@implementation FIRInstallationsFakeSecureStorage

- (instancetype)init {
  self = [super initWithService:@"com.firebase.FIRInstallations.fake"];
  if (self) {
    _items = [NSMutableDictionary dictionary];
    _queue = dispatch_queue_create("com.firebase.FIRInstallationsFakeSecureStorage",
                                   DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

#pragma mark - GULKeychainStorage

- (void)getObjectForKey:(NSString *)key
            objectClass:(Class)objectClass
            accessGroup:(nullable NSString *)accessGroup
      completionHandler:
          (void (^)(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error))completionHandler {
  dispatch_async(self.queue, ^{
    NSData *data = self.items[key];
    if (data == nil) {
      completionHandler(nil, nil);
      return;
    }

    NSError *error;
    id object = [NSKeyedUnarchiver unarchivedObjectOfClass:objectClass fromData:data error:&error];
    completionHandler(error ? nil : object, error);
  });
}

- (void)setObject:(id<NSSecureCoding>)object
               forKey:(NSString *)key
          accessGroup:(nullable NSString *)accessGroup
    completionHandler:
        (void (^)(id<NSSecureCoding> _Nullable obj, NSError *_Nullable error))completionHandler {
  dispatch_async(self.queue, ^{
    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object
                                         requiringSecureCoding:YES
                                                         error:&error];
    if (data == nil) {
      completionHandler(nil, error);
      return;
    }

    self.items[key] = data;
    completionHandler(object, nil);
  });
}

- (void)removeObjectForKey:(NSString *)key
               accessGroup:(nullable NSString *)accessGroup
         completionHandler:(void (^)(NSError *_Nullable error))completionHandler {
  dispatch_async(self.queue, ^{
    [self.items removeObjectForKey:key];
    completionHandler(nil);
  });
}

#pragma mark - Test helpers

- (nullable NSData *)dataForKey:(NSString *)key {
  __block NSData *data;
  dispatch_sync(self.queue, ^{
    data = self.items[key];
  });
  return data;
}

- (void)setData:(nullable NSData *)data forKey:(NSString *)key {
  dispatch_sync(self.queue, ^{
    self.items[key] = data;
  });
}

- (NSUInteger)itemCount {
  __block NSUInteger count;
  dispatch_sync(self.queue, ^{
    count = self.items.count;
  });
  return count;
}

@end
