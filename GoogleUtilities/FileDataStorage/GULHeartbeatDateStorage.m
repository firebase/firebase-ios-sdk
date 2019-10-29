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

#import "GULHeartbeatDateStorage.h"
#import <GoogleUtilities/GULSecureCoding.h>

@interface GULHeartbeatDateStorage ()
@property(nonatomic, readonly) NSURL *fileURL;
@end

@implementation GULHeartbeatDateStorage

- (instancetype)initWithFileURL:(NSURL *)fileURL {
  if (fileURL == nil) {
    return nil;
  }

  self = [super init];
  if (self) {
    _fileURL = fileURL;
  }

  return self;
}

- (nullable NSMutableDictionary *)heartbeatDictionary {
  NSError *error;
  NSData *objectData = [NSData dataWithContentsOfURL:self.fileURL options:0 error:&error];
  if (error != nil) {
    return [NSMutableDictionary dictionary];
  }
  NSMutableDictionary *dict =
      [GULSecureCoding unarchivedObjectOfClass:NSObject.class fromData:objectData error:&error];
  if (error != nil) {
    return [NSMutableDictionary dictionary];
  }
  return dict;
}

- (nullable NSDate *)heartbeatDateForTag:(NSString *)tag {
  NSMutableDictionary *dictionary = [self heartbeatDictionary];
  return dictionary[tag];
}

- (BOOL)setHearbeatDate:(NSDate *)date forTag:(NSString *)tag {
  NSMutableDictionary *dictionary = [self heartbeatDictionary];
  dictionary[tag] = date;
  NSError *error;
  BOOL isSuccess = [self writeDictionary:dictionary error:&error];
  if (isSuccess == false) {
    NSLog(@"Error writing dictionary data %@", error);
  }
  return isSuccess;
}

- (BOOL)writeDictionary:(NSMutableDictionary *)dictionary error:(NSError **)outError {
  NSError *error;
  NSData *data = [GULSecureCoding archivedDataWithRootObject:dictionary error:&error];
  if (error != nil) {
    NSLog(@"Error getting encoded data %@", error);
  } else {
    return [data writeToURL:self.fileURL atomically:YES];
  }
  return false;
}

- (BOOL)setDate:(nullable NSDate *)date error:(NSError **)outError {
  NSString *stringToSave = @"";

  if (date != nil) {
    NSTimeInterval timestamp = [date timeIntervalSinceReferenceDate];
    stringToSave = [NSString stringWithFormat:@"%f", timestamp];
  }
  return [stringToSave writeToURL:self.fileURL
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:outError];
}

// TODO(vguthal): Deprecate this and use setHeartbeatDate
- (nullable NSDate *)date {
  NSString *timestampString = [NSString stringWithContentsOfURL:self.fileURL
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
  if (timestampString.length == 0) {
    return nil;
  }

  NSTimeInterval timestamp = timestampString.doubleValue;
  return [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp];
}

@end
