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

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMServerMsgFetchStorage.h"
@implementation FIRIAMServerMsgFetchStorage
- (NSString *)determineCacheFilePath {
  NSString *cachePath =
      NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
  NSString *filePath = [NSString stringWithFormat:@"%@/firebase-iam-messages-cache", cachePath];
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM150004",
              @"Persistent file path for fetch response data is %@", filePath);
  return filePath;
}

- (void)saveResponseDictionary:(NSDictionary *)response
                withCompletion:(void (^)(BOOL success))completion {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    if ([response writeToFile:[self determineCacheFilePath] atomically:YES]) {
      completion(YES);
    } else {
      completion(NO);
    }
  });
}

- (void)readResponseDictionary:(void (^)(NSDictionary *response, BOOL success))completion {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    NSString *storageFilePath = [self determineCacheFilePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:storageFilePath]) {
      NSDictionary *dictFromFile =
          [[NSMutableDictionary dictionaryWithContentsOfFile:[self determineCacheFilePath]] copy];
      if (dictFromFile) {
        FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM150001",
                    @"Loaded response from fetch storage successfully.");
        completion(dictFromFile, YES);
      } else {
        FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM150002",
                      @"Not able to read response from fetch storage.");
        completion(dictFromFile, NO);
      }
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM150003",
                  @"Local fetch storage file not existent yet: first time launch of the app.");
      completion(nil, YES);
    }
  });
}
@end
