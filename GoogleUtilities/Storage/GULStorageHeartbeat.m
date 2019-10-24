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

#import "GULStorageHeartbeat.h"

@interface GULStorageHeartbeat ()
@property(nonatomic, readonly) NSURL *fileURL;
@end

@implementation GULStorageHeartbeat

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

- (nullable NSMutableDictionary *) getDictionary {
  NSString *jsonString = [NSString stringWithContentsOfURL:self.fileURL
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
  NSError *jsonError;
  if (jsonString == nil) {
    return [NSMutableDictionary dictionary];
  }
  NSData *objectData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                       options:NSJSONReadingMutableContainers
                                                         error:&jsonError];
  if(!json) {
    NSLog(@"Got an error: %@", jsonError);
  }
  return json;

}

- (BOOL) writeDictionary:(NSMutableDictionary *)dictionary error:(NSError **)outError {
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                     options:0
                                                       error:&error];
  if (! jsonData) {
    NSLog(@"Got an error: %@", error);
  } else {
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [jsonString writeToURL:self.fileURL
                         atomically:YES
                           encoding:NSUTF8StringEncoding
                              error:outError];
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
