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
#import <GoogleDataTransport/GDTCORPlatform.h>
#import <GoogleDataTransport/GDTCORStorageProtocol.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"

static NSString *const kNextEventIDKey = @"GDTCOREventEventIDCounter";

@implementation GDTCOREvent

+ (void)nextEventIDForTarget:(GDTCORTarget)target
                  onComplete:(void (^)(NSNumber *_Nonnull eventID))onComplete {
  __block int32_t lastEventID = -1;
  id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(target);
  [storage libraryDataForKey:kNextEventIDKey
      onFetchComplete:^(NSData *_Nullable data, NSError *_Nullable getValueError) {
        if (getValueError != nil || data == nil || data.length == 0) {
          lastEventID = 1;
        } else {
          [data getBytes:(void *)&lastEventID length:sizeof(int32_t)];
        }
        if (onComplete) {
          onComplete(@(lastEventID));
        }
      }
      setNewValue:^NSData *_Nullable(void) {
        if (lastEventID != -1) {
          int32_t incrementedValue = lastEventID + 1;
          return [NSData dataWithBytes:&incrementedValue length:sizeof(int32_t)];
        }
        return nil;
      }];
}

- (nullable instancetype)initWithMappingID:(NSString *)mappingID target:(NSInteger)target {
  GDTCORAssert(mappingID.length > 0, @"Please give a valid mapping ID");
  GDTCORAssert(target > 0, @"A target cannot be negative or 0");
  __block NSNumber *eventID;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [GDTCOREvent nextEventIDForTarget:target
                         onComplete:^(NSNumber *_Nullable newEventID) {
                           eventID = newEventID;
                           dispatch_semaphore_signal(sema);
                         }];
  if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) {
    return nil;
  }
  if (mappingID == nil || mappingID.length == 0 || target <= 0 || eventID == nil) {
    return nil;
  }
  self = [super init];
  if (self) {
    _eventID = eventID;
    _mappingID = mappingID;
    _target = target;
    _qosTier = GDTCOREventQosDefault;
    _expirationDate = [NSDate dateWithTimeIntervalSinceNow:604800];  // 7 days.
  }
  GDTCORLogDebug(@"Event %@ created. ID:%@ mappingID: %@ target:%ld", self, eventID, mappingID,
                 (long)target);
  return self;
}

- (instancetype)copy {
  GDTCOREvent *copy = [[GDTCOREvent alloc] initWithMappingID:_mappingID target:_target];
  copy->_eventID = _eventID;
  copy.dataObject = _dataObject;
  copy.qosTier = _qosTier;
  copy.clockSnapshot = _clockSnapshot;
  copy.customBytes = _customBytes;
  GDTCORLogDebug(@"Copying event %@ to event %@", self, copy);
  return copy;
}

- (NSUInteger)hash {
  // This loses some precision, but it's probably fine.
  NSUInteger eventIDHash = [_eventID hash];
  NSUInteger mappingIDHash = [_mappingID hash];
  NSUInteger timeHash = [_clockSnapshot hash];
  NSInteger serializedBytesHash = [_serializedDataObjectBytes hash];

  return eventIDHash ^ mappingIDHash ^ _target ^ _qosTier ^ timeHash ^ serializedBytesHash;
}

- (BOOL)isEqual:(id)object {
  return [self hash] == [object hash];
}

#pragma mark - Property overrides

- (void)setDataObject:(id<GDTCOREventDataObject>)dataObject {
  // If you're looking here because of a performance issue in -transportBytes slowing the assignment
  // of -dataObject, one way to address this is to add a queue to this class,
  // dispatch_(barrier_ if concurrent)async here, and implement the getter with a dispatch_sync.
  if (dataObject != _dataObject) {
    _dataObject = dataObject;
  }
  self->_serializedDataObjectBytes = [dataObject transportBytes];
}

#pragma mark - NSSecureCoding and NSCoding Protocols

/** NSCoding key for eventID property. */
static NSString *kEventIDKey = @"GDTCOREventEventIDKey";

/** NSCoding key for mappingID property. */
static NSString *kMappingIDKey = @"GDTCOREventMappingIDKey";

/** NSCoding key for target property. */
static NSString *kTargetKey = @"GDTCOREventTargetKey";

/** NSCoding key for qosTier property. */
static NSString *kQoSTierKey = @"GDTCOREventQoSTierKey";

/** NSCoding key for clockSnapshot property. */
static NSString *kClockSnapshotKey = @"GDTCOREventClockSnapshotKey";

/** NSCoding key for expirationDate property. */
static NSString *kExpirationDateKey = @"GDTCOREventExpirationDateKey";

/** NSCoding key for serializedDataObjectBytes property. */
static NSString *kSerializedDataObjectBytes = @"GDTCOREventSerializedDataObjectBytesKey";

/** NSCoding key for customData property. */
static NSString *kCustomDataKey = @"GDTCOREventCustomDataKey";

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [self init];
  if (self) {
    _mappingID = [aDecoder decodeObjectOfClass:[NSString class] forKey:kMappingIDKey];
    _target = [aDecoder decodeIntegerForKey:kTargetKey];
    _eventID = [aDecoder decodeObjectOfClass:[NSNumber class] forKey:kEventIDKey];
    if (_eventID == nil) {
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
      [GDTCOREvent nextEventIDForTarget:_target
                             onComplete:^(NSNumber *_Nullable eventID) {
                               self->_eventID = eventID;
                               dispatch_semaphore_signal(sema);
                             }];
      if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0 ||
          _eventID == nil) {
        return nil;
      }
    }
    _qosTier = [aDecoder decodeIntegerForKey:kQoSTierKey];
    _clockSnapshot = [aDecoder decodeObjectOfClass:[GDTCORClock class] forKey:kClockSnapshotKey];
    _customBytes = [aDecoder decodeObjectOfClass:[NSData class] forKey:kCustomDataKey];
    _expirationDate = [aDecoder decodeObjectOfClass:[NSDate class] forKey:kExpirationDateKey];
    _serializedDataObjectBytes = [aDecoder decodeObjectOfClass:[NSData class]
                                                        forKey:kSerializedDataObjectBytes];
    if (!_serializedDataObjectBytes) {
      return nil;
    }
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_eventID forKey:kEventIDKey];
  [aCoder encodeObject:_mappingID forKey:kMappingIDKey];
  [aCoder encodeInteger:_target forKey:kTargetKey];
  [aCoder encodeInteger:_qosTier forKey:kQoSTierKey];
  [aCoder encodeObject:_clockSnapshot forKey:kClockSnapshotKey];
  [aCoder encodeObject:_customBytes forKey:kCustomDataKey];
  [aCoder encodeObject:_expirationDate forKey:kExpirationDateKey];
  [aCoder encodeObject:self.serializedDataObjectBytes forKey:kSerializedDataObjectBytes];
}

@end
