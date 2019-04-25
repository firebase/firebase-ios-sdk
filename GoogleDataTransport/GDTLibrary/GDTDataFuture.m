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

#import <GoogleDataTransport/GDTDataFuture.h>

@implementation GDTDataFuture

- (instancetype)init {
  self = [self initWithData:[NSData data]];
  return self;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
  self = [super init];
  if (self) {
    _fileURL = fileURL;
  }
  return self;
}

- (instancetype)initWithData:(NSData *)data {
  self = [super init];
  if (self) {
    _originalData = data;
  }
  return self;
}

- (nullable NSData *)data {
  if (_fileURL) {
    NSAssert([[NSFileManager defaultManager] fileExistsAtPath:_fileURL.path isDirectory:NULL],
             @"A file should exist for this future at the given URL: %@", _fileURL);
    return [NSData dataWithContentsOfURL:_fileURL];
  } else if (_originalData) {
    return _originalData;
  }
  return nil;
}

- (BOOL)isEqual:(id)object {
  return [self hash] == [object hash];
}

- (NSUInteger)hash {
  // In reality, only one of these should be populated.
  return [_fileURL hash] ^ [_originalData hash];
}

#pragma mark - NSSecureCoding

/** Coding key for _fileURL ivar. */
static NSString *kGDTDataFutureFileURLKey = @"GDTDataFutureFileURLKey";

/** Coding key for _data ivar. */
static NSString *kGDTDataFutureDataKey = @"GDTDataFutureDataKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
  [aCoder encodeObject:_fileURL forKey:kGDTDataFutureFileURLKey];
  [aCoder encodeObject:_originalData forKey:kGDTDataFutureDataKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
  self = [self init];
  if (self) {
    _fileURL = [aDecoder decodeObjectOfClass:[NSURL class] forKey:kGDTDataFutureFileURLKey];
    _originalData = [aDecoder decodeObjectOfClass:[NSData class] forKey:kGDTDataFutureDataKey];
  }
  return self;
}

@end
