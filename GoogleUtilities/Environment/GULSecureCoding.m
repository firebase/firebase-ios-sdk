// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GoogleUtilities/Environment/Public/GULSecureCoding.h"

NSString *const kGULSecureCodingError = @"GULSecureCodingError";

@implementation GULSecureCoding

+ (nullable id)unarchivedObjectOfClasses:(NSSet<Class> *)classes
                                fromData:(NSData *)data
                                   error:(NSError **)outError {
  // Use the default root object key by default.
  return [self unarchivedObjectOfClasses:classes
                                fromData:data
                                     key:NSKeyedArchiveRootObjectKey
                                   error:outError];
}

+ (nullable id)unarchivedObjectOfClasses:(NSSet<Class> *)classes
                                fromData:(NSData *)data
                                     key:(NSString *)key
                                   error:(NSError **)outError {
  id object;
#if __has_builtin(__builtin_available)
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
    // Pass in the outError explicitly, which will return errors from the unarchiver.
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data
                                                                                error:outError];
    unarchiver.requiresSecureCoding = YES;
    object = [unarchiver decodeObjectOfClasses:classes forKey:key];
  } else
#endif  // __has_builtin(__builtin_available)
  {
    // Before the `error` parameter was available in the `NSKeyedUnarchiver` initializer, it threw
    // an exception. Handle that case explicitly and return an error instead which is safer.
    @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
#pragma clang diagnostic pop
      unarchiver.requiresSecureCoding = YES;

      object = [unarchiver decodeObjectOfClasses:classes forKey:key];
    } @catch (NSException *exception) {
      if (outError) {
        *outError = [self archivingErrorWithException:exception];
      }
    }

    if (object == nil && outError && *outError == nil) {
      NSString *failureReason = @"NSKeyedUnarchiver failed to unarchive data.";
      *outError = [NSError errorWithDomain:kGULSecureCodingError
                                      code:-1
                                  userInfo:@{NSLocalizedFailureReasonErrorKey : failureReason}];
    }
  }

  return object;
}

+ (nullable id)unarchivedObjectOfClass:(Class)class
                              fromData:(NSData *)data
                                 error:(NSError **)outError {
  return [self unarchivedObjectOfClass:class
                              fromData:data
                                   key:NSKeyedArchiveRootObjectKey
                                 error:outError];
}

+ (nullable id)unarchivedObjectOfClass:(Class)class
                              fromData:(NSData *)data
                                   key:(NSString *)key
                                 error:(NSError **)outError {
  return [self unarchivedObjectOfClasses:[NSSet setWithObject:class]
                                fromData:data
                                     key:key
                                   error:outError];
}

+ (nullable NSData *)archivedDataWithObject:(id<NSCoding>)object
                                      toKey:(NSString *)key
                                      error:(NSError **)outError {
  NSData *archiveData;
#if __has_builtin(__builtin_available)
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)) {
    @try {
      NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
      [archiver encodeObject:object forKey:key];
      [archiver finishEncoding];

      archiveData = [archiver.encodedData copy];
    } @catch (NSException *exception) {
      if (outError) {
        *outError = [self archivingErrorWithException:exception];
      }
    }
  } else
#endif  // __has_builtin(__builtin_available)
  {
    @try {
      NSMutableData *data = [NSMutableData data];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
#pragma clang diagnostic pop
      archiver.requiresSecureCoding = YES;

      [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
      [archiver finishEncoding];

      archiveData = [data copy];
    } @catch (NSException *exception) {
      if (outError) {
        *outError = [self archivingErrorWithException:exception];
      }
    }
  }

  return archiveData;
}

+ (nullable NSData *)archivedDataWithRootObject:(id<NSCoding>)object error:(NSError **)outError {
  return [self archivedDataWithObject:object toKey:NSKeyedArchiveRootObjectKey error:outError];
}

+ (NSError *)archivingErrorWithException:(NSException *)exception {
  NSString *failureReason = [NSString
      stringWithFormat:@"NSKeyedArchiver exception with name: %@, reason: %@, userInfo: %@",
                       exception.name, exception.reason, exception.userInfo];
  NSDictionary *errorUserInfo = @{NSLocalizedFailureReasonErrorKey : failureReason};

  return [NSError errorWithDomain:kGULSecureCodingError code:-1 userInfo:errorUserInfo];
}

@end
