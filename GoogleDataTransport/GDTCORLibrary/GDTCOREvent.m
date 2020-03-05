/*
 * Copyright 2018 Google
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

#import "GDTCORLibrary/Public/GDTCOREvent.h"

#import <GoogleDataTransport/GDTCORAssert.h>
#import <GoogleDataTransport/GDTCORClock.h>
#import <GoogleDataTransport/GDTCORConsoleLogger.h>

#import "GDTCORLibrary/Private/GDTCORDataFuture.h"
#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"

@implementation GDTCOREvent

- (nullable instancetype)initWithMappingID:(NSString *)mappingID target:(NSInteger)target {
  GDTCORAssert(mappingID.length > 0, @"Please give a valid mapping ID");
  GDTCORAssert(target > 0, @"A target cannot be negative or 0");
  if (mappingID == nil || mappingID.length == 0 || target <= 0) {
    return nil;
  }
  self = [super init];
  if (self) {
    _mappingID = mappingID;
    _target = target;
    _qosTier = GDTCOREventQosDefault;
  }
  GDTCORLogDebug("Event %@ created. mappingID: %@ target:%ld qos:%ld", self, _mappingID,
                 (long)_target, (long)_qosTier);
  return self;
}

- (instancetype)copy {
  GDTCOREvent *copy = [[GDTCOREvent alloc] initWithMappingID:_mappingID target:_target];
  copy.dataObject = _dataObject;
  copy.qosTier = _qosTier;
  copy.clockSnapshot = _clockSnapshot;
  copy.customPrioritizationParams = _customPrioritizationParams;
  copy->_fileURL = _fileURL;
  GDTCORLogDebug("Copying event %@ to event %@", self, copy);
  return copy;
}

- (NSUInteger)hash {
  // This loses some precision, but it's probably fine.
  NSUInteger mappingIDHash = [_mappingID hash];
  NSUInteger timeHash = [_clockSnapshot hash];
  NSInteger dataObjectHash = [_dataObject hash];
  NSUInteger fileURL = [_fileURL hash];

  return mappingIDHash ^ _target ^ _qosTier ^ timeHash ^ dataObjectHash ^ fileURL;
}

- (BOOL)isEqual:(id)object {
  return [self hash] == [object hash];
}

- (void)setDataObject:(id<GDTCOREventDataObject>)dataObject {
  // If you're looking here because of a performance issue in -transportBytes slowing the assignment
  // of -dataObject, one way to address this is to add a queue to this class,
  // dispatch_(barrier_ if concurrent)async here, and implement the getter with a dispatch_sync.
  if (dataObject != _dataObject) {
    _dataObject = dataObject;
  }
}

- (BOOL)writeToURL:(NSURL *)fileURL error:(NSError **)error {
  NSData *dataTransportBytes = [_dataObject transportBytes];
  if (dataTransportBytes == nil) {
    _fileURL = nil;
    _dataObject = nil;
    return NO;
  }
  BOOL writingSuccess = [dataTransportBytes writeToURL:fileURL
                                               options:NSDataWritingAtomic
                                                 error:error];
  if (!writingSuccess) {
    GDTCORLogError(GDTCORMCEFileWriteError, @"An event file could not be written: %@", fileURL);
    _fileURL = nil;
    return NO;
  }
  _fileURL = fileURL;
  _dataObject = nil;
  return YES;
}

#pragma mark - NSSecureCoding and NSCoding Protocols

/** NSCoding key for mappingID property. */
static NSString *mappingIDKey = @"_mappingID";

/** NSCoding key for target property. */
static NSString *targetKey = @"_target";

/** NSCoding key for qosTier property. */
static NSString *qosTierKey = @"_qosTier";

/** NSCoding key for clockSnapshot property. */
static NSString *clockSnapshotKey = @"_clockSnapshot";

/** NSCoding key for fileURL property. */
static NSString *fileURLKey = @"_fileURL";

/** NSCoding key for customPrioritizationParams property. */
static NSString *customPrioritizationParams = @"_customPrioritizationParams";

/** NSCoding key for backwards compatibility of GDTCORStoredEvent mappingID property.*/
static NSString *kStoredEventMappingIDKey = @"GDTCORStoredEventMappingIDKey";

/** NSCoding key for backwards compatibility of GDTCORStoredEvent target property.*/
static NSString *kStoredEventTargetKey = @"GDTCORStoredEventTargetKey";

/** NSCoding key for backwards compatibility of GDTCORStoredEvent qosTier property.*/
static NSString *kStoredEventQosTierKey = @"GDTCORStoredEventQosTierKey";

/** NSCoding key for backwards compatibility of GDTCORStoredEvent clockSnapshot property.*/
static NSString *kStoredEventClockSnapshotKey = @"GDTCORStoredEventClockSnapshotKey";

/** NSCoding key for backwards compatibility of GDTCORStoredEvent dataFuture property.*/
static NSString *kStoredEventDataFutureKey = @"GDTCORStoredEventDataFutureKey";

/** NSCoding key for backwards compatibility of GDTCORStoredEvent customPrioritizationParams
 * property.*/
static NSString *kStoredEventCustomPrioritizationParamsKey =
    @"GDTCORStoredEventcustomPrioritizationParamsKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  GDTCORDataFuture *dataFuture = [aDecoder decodeObjectOfClass:[GDTCORDataFuture class]
                                                        forKey:kStoredEventDataFutureKey];
  if (dataFuture) {
    return [self initWithCoderForStoredEventBackwardCompatibility:aDecoder
                                                          fileURL:dataFuture.fileURL];
  }
  NSString *mappingID = [aDecoder decodeObjectOfClass:[NSString class] forKey:mappingIDKey];
  NSInteger target = [aDecoder decodeIntegerForKey:targetKey];
  self = [self initWithMappingID:mappingID target:target];
  if (self) {
    _qosTier = [aDecoder decodeIntegerForKey:qosTierKey];
    _clockSnapshot = [aDecoder decodeObjectOfClass:[GDTCORClock class] forKey:clockSnapshotKey];
    _fileURL = [aDecoder decodeObjectOfClass:[NSURL class] forKey:fileURLKey];
    _customPrioritizationParams = [aDecoder decodeObjectOfClass:[NSDictionary class]
                                                         forKey:customPrioritizationParams];
  }
  return self;
}

- (id)initWithCoderForStoredEventBackwardCompatibility:(NSCoder *)aDecoder
                                               fileURL:(NSURL *)fileURL {
  NSString *mappingID = [aDecoder decodeObjectOfClass:[NSString class]
                                               forKey:kStoredEventMappingIDKey];
  NSInteger target = [[aDecoder decodeObjectOfClass:[NSNumber class]
                                             forKey:kStoredEventTargetKey] integerValue];
  self = [self initWithMappingID:mappingID target:target];
  if (self) {
    _qosTier = [[aDecoder decodeObjectOfClass:[NSNumber class]
                                       forKey:kStoredEventQosTierKey] integerValue];
    _clockSnapshot = [aDecoder decodeObjectOfClass:[GDTCORClock class]
                                            forKey:kStoredEventClockSnapshotKey];
    _fileURL = fileURL;
    _customPrioritizationParams =
        [aDecoder decodeObjectOfClass:[NSDictionary class]
                               forKey:kStoredEventCustomPrioritizationParamsKey];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_mappingID forKey:mappingIDKey];
  [aCoder encodeInteger:_target forKey:targetKey];
  [aCoder encodeInteger:_qosTier forKey:qosTierKey];
  [aCoder encodeObject:_clockSnapshot forKey:clockSnapshotKey];
  [aCoder encodeObject:_fileURL forKey:fileURLKey];
  [aCoder encodeObject:_customPrioritizationParams forKey:customPrioritizationParams];
}

@end
