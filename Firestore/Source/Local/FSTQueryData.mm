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

#import "Firestore/Source/Local/FSTQueryData.h"

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryData

- (instancetype)initWithQuery:(FSTQuery *)query
                     targetID:(FSTTargetID)targetID
         listenSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                      purpose:(FSTQueryPurpose)purpose
              snapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                  resumeToken:(NSData *)resumeToken {
  self = [super init];
  if (self) {
    _query = query;
    _targetID = targetID;
    _sequenceNumber = sequenceNumber;
    _purpose = purpose;
    _snapshotVersion = snapshotVersion;
    _resumeToken = [resumeToken copy];
  }
  return self;
}

- (instancetype)initWithQuery:(FSTQuery *)query
                     targetID:(FSTTargetID)targetID
         listenSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                      purpose:(FSTQueryPurpose)purpose {
  return [self initWithQuery:query
                    targetID:targetID
        listenSequenceNumber:sequenceNumber
                     purpose:purpose
             snapshotVersion:[FSTSnapshotVersion noVersion]
                 resumeToken:[NSData data]];
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTQueryData class]]) {
    return NO;
  }

  FSTQueryData *other = (FSTQueryData *)object;
  return [self.query isEqual:other.query] && self.targetID == other.targetID &&
         self.purpose == other.purpose && [self.snapshotVersion isEqual:other.snapshotVersion] &&
         [self.resumeToken isEqual:other.resumeToken];
}

- (NSUInteger)hash {
  NSUInteger result = [self.query hash];
  result = result * 31 + self.targetID;
  result = result * 31 + self.purpose;
  result = result * 31 + [self.snapshotVersion hash];
  result = result * 31 + [self.resumeToken hash];
  return result;
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTQueryData: query:%@ target:%d purpose:%lu version:%@ resumeToken:%@)>",
                       self.query, self.targetID, (unsigned long)self.purpose, self.snapshotVersion,
                       self.resumeToken];
}

- (instancetype)queryDataByReplacingSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                                        resumeToken:(NSData *)resumeToken {
  return [[FSTQueryData alloc] initWithQuery:self.query
                                    targetID:self.targetID
                        listenSequenceNumber:self.sequenceNumber
                                     purpose:self.purpose
                             snapshotVersion:snapshotVersion
                                 resumeToken:resumeToken];
}

@end

NS_ASSUME_NONNULL_END
