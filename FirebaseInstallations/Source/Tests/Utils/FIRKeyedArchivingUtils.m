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

#import "FirebaseInstallations/Source/Tests/Utils/FIRKeyedArchivingUtils.h"

@implementation FIRKeyedArchivingUtils

+ (nullable NSData *)archivedDataWithRootObject:(id)object error:(NSError **)outError {
  NSData *archivedData;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    archivedData = [NSKeyedArchiver archivedDataWithRootObject:object
                                         requiringSecureCoding:YES
                                                         error:outError];
  } else {
    @try {
      NSMutableData *data = [NSMutableData data];
      NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
      archiver.requiresSecureCoding = YES;

      [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
      [archiver finishEncoding];

      archivedData = [data copy];
    } @catch (NSException *exception) {
      if (outError) {
        NSString *failureReason = [NSString stringWithFormat:@"Exception: %@", exception];
        *outError = [NSError errorWithDomain:@"FIRKeyedArchivingUtils"
                                        code:-1
                                    userInfo:@{
                                      NSLocalizedFailureReasonErrorKey : failureReason,
                                    }];
      }
    }
  }

  return archivedData;
}

+ (nullable id)unarchivedObjectOfClass:(Class)class
                              fromData:(NSData *)data
                                 error:(NSError **)outError {
  id object;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    object = [NSKeyedUnarchiver unarchivedObjectOfClass:class fromData:data error:outError];
  } else {
    @try {
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
      unarchiver.requiresSecureCoding = YES;

      object = [unarchiver decodeObjectOfClass:class forKey:NSKeyedArchiveRootObjectKey];
    } @catch (NSException *exception) {
      if (outError) {
        NSString *failureReason = [NSString stringWithFormat:@"Exception: %@", exception];
        *outError = [NSError errorWithDomain:@"FIRKeyedArchivingUtils"
                                        code:-1
                                    userInfo:@{
                                      NSLocalizedFailureReasonErrorKey : failureReason,
                                    }];
      }
    }
  }

  return object;
}

@end
