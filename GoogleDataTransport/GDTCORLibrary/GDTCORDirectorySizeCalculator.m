/*
 * Copyright 2020 Google LLC
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

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORDirectorySizeCalculator.h"

@interface GDTCORDirectorySizeCalculator ()

/** The observed directory path. */
@property(nonatomic, readonly) NSString *directoryPath;

/** The cached content size of the observed directory. */
@property(nonatomic, nullable) NSNumber *cachedSizeBytes;

@end

@implementation GDTCORDirectorySizeCalculator

- (instancetype)initWithDirectoryPath:(NSString *)path {
  self = [super init];
  if (self) {
    _directoryPath = path;
  }
  return self;
}

- (GDTCORStorageSizeBytes)directoryContentSize {
  if (self.cachedSizeBytes == nil) {
    self.cachedSizeBytes = @([self calculateDirectoryContentSize]);
  }

  return self.cachedSizeBytes.unsignedLongLongValue;
}

- (void)fileWithSize:(GDTCORStorageSizeBytes)fileSize wasAddedAtPath:(NSString *)path {
  if (![path hasPrefix:self.directoryPath]) {
    // Ignore because the file is not inside the directory.
    return;
  }

  self.cachedSizeBytes = @([self directoryContentSize] + fileSize);
}

- (void)fileWithSize:(GDTCORStorageSizeBytes)fileSize wasRemovedAtPath:(NSString *)path {
  if (![path hasPrefix:self.directoryPath]) {
    // Ignore because the file is not inside the directory.
    return;
  }

  self.cachedSizeBytes = @([self directoryContentSize] - fileSize);
}

- (void)resetCachedSize {
  self.cachedSizeBytes = nil;
}

- (GDTCORStorageSizeBytes)calculateDirectoryContentSize {
  NSArray *prefetchedProperties = @[ NSURLIsRegularFileKey, NSURLFileSizeKey ];
  uint64_t totalBytes = 0;
  NSURL *directoryURL = [NSURL URLWithString:self.directoryPath];

  NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]
                 enumeratorAtURL:directoryURL
      includingPropertiesForKeys:prefetchedProperties
                         options:NSDirectoryEnumerationSkipsHiddenFiles
                    errorHandler:^BOOL(NSURL *_Nonnull url, NSError *_Nonnull error) {
                      return YES;
                    }];

  for (NSURL *fileURL in enumerator) {
    NSNumber *isRegularFile;
    [fileURL getResourceValue:&isRegularFile forKey:NSURLIsRegularFileKey error:nil];
    if (isRegularFile.boolValue) {
      NSNumber *fileSize;
      [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
      totalBytes += fileSize.unsignedLongLongValue;
    }
  }

  return totalBytes;
}

@end
