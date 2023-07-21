/*
 * Copyright 2021 Google LLC
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

#import "AppCheckCore/Sources/AppAttestProvider/Storage/GACAppAttestStoredArtifact.h"

static NSString *const kKeyIDKey = @"keyID";
static NSString *const kArtifactKey = @"artifact";
static NSString *const kStorageVersionKey = @"storageVersion";

static NSInteger const kStorageVersion = 1;

@implementation GACAppAttestStoredArtifact

- (instancetype)initWithKeyID:(NSString *)keyID artifact:(NSData *)artifact {
  self = [super init];
  if (self) {
    _keyID = keyID;
    _artifact = artifact;
  }
  return self;
}

- (NSInteger)storageVersion {
  return kStorageVersion;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
  [coder encodeObject:self.keyID forKey:kKeyIDKey];
  [coder encodeObject:self.artifact forKey:kArtifactKey];
  [coder encodeInteger:self.storageVersion forKey:kStorageVersionKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
  NSInteger storageVersion = [coder decodeIntegerForKey:kStorageVersionKey];

  if (storageVersion < kStorageVersion) {
    // Handle migration here when new versions are added
  }

  // If the version of the stored object is equal or higher than the current version then try the
  // best to get enough data to initialize the object.
  NSString *keyID = [coder decodeObjectOfClass:[NSString class] forKey:kKeyIDKey];
  if (keyID.length < 1) {
    return nil;
  }

  NSData *artifact = [coder decodeObjectOfClass:[NSData class] forKey:kArtifactKey];
  if (artifact.length < 1) {
    return nil;
  }

  return [self initWithKeyID:keyID artifact:artifact];
}

@end
