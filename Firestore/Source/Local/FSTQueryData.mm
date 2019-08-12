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

#include <utility>

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"

namespace util = firebase::firestore::util;
using firebase::firestore::core::Query;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryData {
  Query _query;
  SnapshotVersion _snapshotVersion;
  ByteString _resumeToken;
}

- (instancetype)initWithQuery:(Query)query
                     targetID:(TargetId)targetID
         listenSequenceNumber:(ListenSequenceNumber)sequenceNumber
                      purpose:(QueryPurpose)purpose
              snapshotVersion:(SnapshotVersion)snapshotVersion
                  resumeToken:(ByteString)resumeToken {
  self = [super init];
  if (self) {
    _query = std::move(query);
    _targetID = targetID;
    _sequenceNumber = sequenceNumber;
    _purpose = purpose;
    _snapshotVersion = std::move(snapshotVersion);
    _resumeToken = std::move(resumeToken);
  }
  return self;
}

- (instancetype)initWithQuery:(Query)query
                     targetID:(TargetId)targetID
         listenSequenceNumber:(ListenSequenceNumber)sequenceNumber
                      purpose:(QueryPurpose)purpose {
  return [self initWithQuery:std::move(query)
                    targetID:targetID
        listenSequenceNumber:sequenceNumber
                     purpose:purpose
             snapshotVersion:SnapshotVersion::None()
                 resumeToken:ByteString()];
}

- (const Query &)query {
  return _query;
}

- (const firebase::firestore::model::SnapshotVersion &)snapshotVersion {
  return _snapshotVersion;
}

- (const ByteString &)resumeToken {
  return _resumeToken;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[FSTQueryData class]]) {
    return NO;
  }

  FSTQueryData *other = (FSTQueryData *)object;
  return self.query == other.query && self.targetID == other.targetID &&
         self.sequenceNumber == other.sequenceNumber && self.purpose == other.purpose &&
         self.snapshotVersion == other.snapshotVersion && self.resumeToken == other.resumeToken;
}

- (NSUInteger)hash {
  return util::Hash(self.query, self.targetID, self.sequenceNumber,
                    static_cast<NSInteger>(self.purpose), self.snapshotVersion, self.resumeToken);
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"<FSTQueryData: query:%s target:%d purpose:%lu version:%s resumeToken:%s)>",
                       self.query.ToString().c_str(), self.targetID, (unsigned long)self.purpose,
                       self.snapshotVersion.ToString().c_str(),
                       self.resumeToken.ToString().c_str()];
}

- (instancetype)queryDataByReplacingSnapshotVersion:(SnapshotVersion)snapshotVersion
                                        resumeToken:(ByteString)resumeToken
                                     sequenceNumber:(ListenSequenceNumber)sequenceNumber {
  return [[FSTQueryData alloc] initWithQuery:self.query
                                    targetID:self.targetID
                        listenSequenceNumber:sequenceNumber
                                     purpose:self.purpose
                             snapshotVersion:std::move(snapshotVersion)
                                 resumeToken:std::move(resumeToken)];
}

@end

NS_ASSUME_NONNULL_END
