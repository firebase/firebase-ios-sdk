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

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

#import <GoogleDataTransport/GoogleDataTransport.h>
#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import "FirebaseMessaging/Sources/FIRMessagingCode.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/Protogen/nanopb/me.nanopb.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessagingExtensionHelper.h"

static NSString *const kPayloadOptionsName = @"fcm_options";
static NSString *const kPayloadOptionsImageURLName = @"image";
static NSString *const kNoExtension = @"";
static NSString *const kImagePathPrefix = @"image/";

#pragma mark - nanopb helper functions

/** Callocs a pb_bytes_array and copies the given NSData bytes into the bytes array.
 *
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param data The data to copy into the new bytes array.
 */
pb_bytes_array_t *FIRMessagingEncodeData(NSData *data) {
  pb_bytes_array_t *pbBytesArray = calloc(1, PB_BYTES_ARRAY_T_ALLOCSIZE(data.length));
  if (pbBytesArray != NULL) {
    [data getBytes:pbBytesArray->bytes length:data.length];
    pbBytesArray->size = (pb_size_t)data.length;
  }
  return pbBytesArray;
}
/** Callocs a pb_bytes_array and copies the given NSString's bytes into the bytes array.
 *
 * @note Memory needs to be free manually, through pb_free or pb_release.
 * @param string The string to encode as pb_bytes.
 */
pb_bytes_array_t *FIRMessagingEncodeString(NSString *string) {
  NSData *stringBytes = [string dataUsingEncoding:NSUTF8StringEncoding];
  return FIRMessagingEncodeData(stringBytes);
}

@interface FIRMessagingMetricsLog : NSObject <GDTCOREventDataObject>

@property(nonatomic) fm_MessagingClientEventExtension eventExtension;

@end

@implementation FIRMessagingMetricsLog

- (instancetype)initWithEventExtension:(fm_MessagingClientEventExtension)eventExtension {
  self = [super init];
  if (self) {
    _eventExtension = eventExtension;
  }
  return self;
}

- (NSData *)transportBytes {
  pb_ostream_t sizestream = PB_OSTREAM_SIZING;

  // Encode 1 time to determine the size.
  if (!pb_encode(&sizestream, fm_MessagingClientEventExtension_fields, &_eventExtension)) {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionTransportBytesError,
                            @"Error in nanopb encoding for size: %s", PB_GET_ERROR(&sizestream));
  }

  // Encode a 2nd time to actually get the bytes from it.
  size_t bufferSize = sizestream.bytes_written;
  CFMutableDataRef dataRef = CFDataCreateMutable(CFAllocatorGetDefault(), bufferSize);
  CFDataSetLength(dataRef, bufferSize);
  pb_ostream_t ostream = pb_ostream_from_buffer((void *)CFDataGetBytePtr(dataRef), bufferSize);
  if (!pb_encode(&ostream, fm_MessagingClientEventExtension_fields, &_eventExtension)) {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionTransportBytesError,
                            @"Error in nanopb encoding for bytes: %s", PB_GET_ERROR(&ostream));
  }
  CFDataSetLength(dataRef, ostream.bytes_written);

  return CFBridgingRelease(dataRef);
}

@end

@interface FIRMessagingExtensionHelper ()
@property(nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property(nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation FIRMessagingExtensionHelper

- (void)populateNotificationContent:(UNMutableNotificationContent *)content
                 withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler {
  self.contentHandler = [contentHandler copy];
  self.bestAttemptContent = content;

  // The `userInfo` property isn't available on newer versions of tvOS.
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_WATCH
  NSObject *currentImageURL = content.userInfo[kPayloadOptionsName][kPayloadOptionsImageURLName];
  if (!currentImageURL || currentImageURL == [NSNull null]) {
    [self deliverNotification];
    return;
  }
  NSURL *attachmentURL = [NSURL URLWithString:(NSString *)currentImageURL];
  if (attachmentURL) {
    [self loadAttachmentForURL:attachmentURL
             completionHandler:^(UNNotificationAttachment *attachment) {
               if (attachment != nil) {
                 self.bestAttemptContent.attachments = @[ attachment ];
               }
               [self deliverNotification];
             }];
  } else {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionImageInvalidURL,
                            @"The Image URL provided is invalid %@.", currentImageURL);
    [self deliverNotification];
  }
#else
  [self deliverNotification];
#endif
}

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_WATCH
- (NSString *)fileExtensionForResponse:(NSURLResponse *)response {
  NSString *suggestedPathExtension = [response.suggestedFilename pathExtension];
  if (suggestedPathExtension.length > 0) {
    return [NSString stringWithFormat:@".%@", suggestedPathExtension];
  }
  if ([response.MIMEType containsString:kImagePathPrefix]) {
    return [response.MIMEType stringByReplacingOccurrencesOfString:kImagePathPrefix
                                                        withString:@"."];
  }
  return kNoExtension;
}

- (void)loadAttachmentForURL:(NSURL *)attachmentURL
           completionHandler:(void (^)(UNNotificationAttachment *))completionHandler {
  __block UNNotificationAttachment *attachment = nil;

  NSURLSession *session = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  [[session
      downloadTaskWithURL:attachmentURL
        completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
          if (error != nil) {
            FIRMessagingLoggerError(kFIRMessagingServiceExtensionImageNotDownloaded,
                                    @"Failed to download image given URL %@, error: %@\n",
                                    attachmentURL, error);
            completionHandler(attachment);
            return;
          }

          NSFileManager *fileManager = [NSFileManager defaultManager];
          NSString *fileExtension = [self fileExtensionForResponse:response];
          NSURL *localURL = [NSURL
              fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:fileExtension]];
          [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];
          if (error) {
            FIRMessagingLoggerError(
                kFIRMessagingServiceExtensionLocalFileNotCreated,
                @"Failed to move the image file to local location: %@, error: %@\n", localURL,
                error);
            completionHandler(attachment);
            return;
          }

          attachment = [UNNotificationAttachment attachmentWithIdentifier:@""
                                                                      URL:localURL
                                                                  options:nil
                                                                    error:&error];
          if (error) {
            FIRMessagingLoggerError(kFIRMessagingServiceExtensionImageNotAttached,
                                    @"Failed to create attachment with URL %@, error: %@\n",
                                    localURL, error);
            completionHandler(attachment);
            return;
          }
          completionHandler(attachment);
        }] resume];
}
#endif

- (void)deliverNotification {
  if (self.contentHandler) {
    self.contentHandler(self.bestAttemptContent);
  }
}

- (void)exportDeliveryMetricsToBigQueryWithMessageInfo:(NSDictionary *)info {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1249"
                                                             transformers:nil
                                                                   target:kGDTCORTargetFLL];

  fm_MessagingClientEventExtension eventExtension = fm_MessagingClientEventExtension_init_default;

  fm_MessagingClientEvent clientEvent = fm_MessagingClientEvent_init_default;
  if (!info[kFIRMessagingSenderID]) {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionInvalidProjectID,
                            @"Delivery logging failed: Invalid project ID");
    return;
  }
  clientEvent.project_number = (int64_t)[info[kFIRMessagingSenderID] longLongValue];

  if (!info[kFIRMessagingMessageIDKey] ||
      ![info[kFIRMessagingMessageIDKey] isKindOfClass:NSString.class]) {
    FIRMessagingLoggerWarn(kFIRMessagingServiceExtensionInvalidMessageID,
                           @"Delivery logging failed: Invalid Message ID");
    return;
  }
  clientEvent.message_id = FIRMessagingEncodeString(info[kFIRMessagingMessageIDKey]);

  if (!info[kFIRMessagingFID] || ![info[kFIRMessagingFID] isKindOfClass:NSString.class]) {
    FIRMessagingLoggerWarn(kFIRMessagingServiceExtensionInvalidInstanceID,
                           @"Delivery logging failed: Invalid Instance ID");
    return;
  }
  clientEvent.instance_id = FIRMessagingEncodeString(info[kFIRMessagingFID]);

  if ([info[@"aps"][kFIRMessagingMessageAPNSContentAvailableKey] intValue] == 1 &&
      ![GULAppEnvironmentUtil isAppExtension]) {
    clientEvent.message_type = fm_MessagingClientEvent_MessageType_DATA_MESSAGE;
  } else {
    clientEvent.message_type = fm_MessagingClientEvent_MessageType_DISPLAY_NOTIFICATION;
  }
  clientEvent.sdk_platform = fm_MessagingClientEvent_SDKPlatform_IOS;

  NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
  if ([GULAppEnvironmentUtil isAppExtension]) {
    bundleID = [[self class] bundleIdentifierByRemovingLastPartFrom:bundleID];
  }
  if (bundleID) {
    clientEvent.package_name = FIRMessagingEncodeString(bundleID);
  }
  clientEvent.event = fm_MessagingClientEvent_Event_MESSAGE_DELIVERED;

  if (info[kFIRMessagingAnalyticsMessageLabel]) {
    clientEvent.analytics_label =
        FIRMessagingEncodeString(info[kFIRMessagingAnalyticsMessageLabel]);
  }
  if (info[kFIRMessagingAnalyticsComposerIdentifier]) {
    clientEvent.campaign_id =
        (int64_t)[info[kFIRMessagingAnalyticsComposerIdentifier] longLongValue];
  }
  if (info[kFIRMessagingAnalyticsComposerLabel]) {
    clientEvent.composer_label =
        FIRMessagingEncodeString(info[kFIRMessagingAnalyticsComposerLabel]);
  }

  eventExtension.messaging_client_event = &clientEvent;
  FIRMessagingMetricsLog *log =
      [[FIRMessagingMetricsLog alloc] initWithEventExtension:eventExtension];

  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = log;
  event.qosTier = GDTCOREventQoSFast;

  // Use this API for SDK service data events.
  [transport sendDataEvent:event];
}

+ (NSString *)bundleIdentifierByRemovingLastPartFrom:(NSString *)bundleIdentifier {
  NSString *bundleIDComponentsSeparator = @".";

  NSMutableArray<NSString *> *bundleIDComponents =
      [[bundleIdentifier componentsSeparatedByString:bundleIDComponentsSeparator] mutableCopy];
  [bundleIDComponents removeLastObject];

  return [bundleIDComponents componentsJoinedByString:bundleIDComponentsSeparator];
}

@end
