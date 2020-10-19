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

#import "GoogleDataTransport/GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORAssert.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORStorageProtocol.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREventDataObject.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORTargets.h"

#import "GoogleDataTransport/GDTCCTLibrary/Public/GDTCOREvent+GDTCCTSupport.h"

@interface GDTCCTEventGeneratorDataObject : NSObject <GDTCOREventDataObject>

@property(nullable, nonatomic) NSURL *dataFile;

@end

@implementation GDTCCTEventGeneratorDataObject

- (NSData *)transportBytes {
  return [NSData dataWithContentsOfURL:self.dataFile];
}

@end

@implementation GDTCCTEventGenerator

- (instancetype)initWithTarget:(GDTCORTarget)target {
  self = [super init];
  if (self) {
    _target = target;
    _allGeneratedEvents = [[NSMutableSet alloc] init];
  }
  return self;
}

- (GDTCOREvent *)generateEvent:(GDTCOREventQoS)qosTier {
  CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
  NSURL *testDataFile = [GDTCORRootDirectory()
      URLByAppendingPathComponent:[NSString stringWithFormat:@"test-data-%lf.txt", currentTime]];
  [[NSFileManager defaultManager] createFileAtPath:testDataFile.path
                                          contents:[@"test" dataUsingEncoding:NSUTF8StringEncoding]
                                        attributes:nil];

  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.qosTier = qosTier;
  GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
  dataObject.dataFile = testDataFile;
  event.dataObject = dataObject;
  event.eventCode = @(1405);
  NSError *error;
  id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
  [storage storeEvent:event
           onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
             GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
           }];
  GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
  [self.allGeneratedEvents addObject:event];
  return event;
}

- (GDTCOREvent *)generateEvent:(GDTCOREventQoS)qosTier fileURL:(NSURL *)fileURL {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.qosTier = qosTier;
  GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
  dataObject.dataFile = fileURL;
  event.dataObject = dataObject;
  event.eventCode = @(1405);
  NSError *error;
  id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
  [storage storeEvent:event
           onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
             GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
           }];
  GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
  [self.allGeneratedEvents addObject:event];
  return event;
}

/** Generates a file URL that has the message resource data copied into it.
 *
 * @param messageResource The message resource name to copy.
 * @return A new file containing the data of the message resource.
 */
- (NSURL *)writeConsistentMessageToDisk:(NSString *)messageResource {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSString *filePath = [NSString stringWithFormat:@"test-data-%lf.txt", CFAbsoluteTimeGetCurrent()];
  NSAssert([[NSFileManager defaultManager] fileExistsAtPath:filePath] == NO,
           @"There should be no duplicate files generated.");
  NSData *messageData = [NSData dataWithContentsOfURL:[testBundle URLForResource:messageResource
                                                                   withExtension:nil]];
  [messageData writeToFile:filePath atomically:YES];
  return [NSURL fileURLWithPath:filePath];
}

- (NSArray<GDTCOREvent *> *)generateTheFiveConsistentEvents {
  NSMutableArray<GDTCOREvent *> *events = [[NSMutableArray alloc] init];
  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111222) forKeyPath:@"kernelBootTimeNanoseconds"];
    [event.clockSnapshot setValue:@(1235567890) forKeyPath:@"uptimeNanoseconds"];
    event.qosTier = GDTCOREventQosDefault;
    event.eventCode = @1986;
    NSError *error;
    event.customBytes = [NSJSONSerialization dataWithJSONObject:@{
      @"customParam" : @1337
    }
                                                        options:0
                                                          error:&error];
    GDTCORAssert(error == nil, @"There shouldn't be an issue turning into JSON");
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-32347456.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    error = nil;
    id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
    [storage storeEvent:event
             onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
               GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
             }];
    GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111333) forKeyPath:@"kernelBootTimeNanoseconds"];
    [event.clockSnapshot setValue:@(1236567890) forKeyPath:@"uptimeNanoseconds"];
    event.qosTier = GDTCOREventQoSWifiOnly;
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-35458880.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    event.needsNetworkConnectionInfoPopulated = YES;
    NSError *error;
    id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
    [storage storeEvent:event
             onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
               GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
             }];
    GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111444) forKeyPath:@"kernelBootTimeNanoseconds"];
    [event.clockSnapshot setValue:@(1237567890) forKeyPath:@"uptimeNanoseconds"];
    event.qosTier = GDTCOREventQosDefault;
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-39882816.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    NSError *error;
    id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
    [storage storeEvent:event
             onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
               GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
             }];
    GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111555) forKeyPath:@"kernelBootTimeNanoseconds"];
    [event.clockSnapshot setValue:@(1238567890) forKeyPath:@"uptimeNanoseconds"];
    event.qosTier = GDTCOREventQosDefault;
    NSError *error;
    event.customBytes = [NSJSONSerialization dataWithJSONObject:@{@"customParam1" : @"aValue1"}
                                                        options:0
                                                          error:&error];
    GDTCORAssert(error == nil, @"There shouldn't be an issue turning into JSON");
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-40043840.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    error = nil;
    id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
    [storage storeEvent:event
             onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
               GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
             }];
    GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111666) forKeyPath:@"kernelBootTimeNanoseconds"];
    [event.clockSnapshot setValue:@(1239567890) forKeyPath:@"uptimeNanoseconds"];
    event.qosTier = GDTCOREventQoSTelemetry;
    NSError *error;
    event.customBytes = [NSJSONSerialization dataWithJSONObject:@{
      @"customParam2" : @(34)
    }
                                                        options:0
                                                          error:&error];
    GDTCORAssert(error == nil, @"There shouldn't be an issue turning into JSON");
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-40657984.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    error = nil;
    id<GDTCORStorageProtocol> storage = GDTCORStorageInstanceForTarget(event.target);
    [storage storeEvent:event
             onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
               GDTCORFatalAssert(wasWritten && error == nil, @"Writing a generated event failed.");
             }];
    GDTCORFatalAssert(error == nil, @"Generating an event failed: %@", error);
    [events addObject:event];
  }
  return events;
}

@end
