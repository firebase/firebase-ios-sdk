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

#import "FIRMessagingConstants.h"

NSString *const kFIRMessagingRawDataKey = @"rawData";
NSString *const kFIRMessagingCollapseKey = @"collapse_key";
NSString *const kFIRMessagingFromKey = @"from";

NSString *const kFIRMessagingSendTo = @"google." @"to";
NSString *const kFIRMessagingSendTTL = @"google." @"ttl";
NSString *const kFIRMessagingSendDelay = @"google." @"delay";
NSString *const kFIRMessagingSendMessageID = @"google." @"msg_id";
NSString *const KFIRMessagingSendMessageAppData = @"google." @"data";

NSString *const kFIRMessagingMessageInternalReservedKeyword = @"gcm.";
NSString *const kFIRMessagingMessagePersistentIDKey = @"persistent_id";

NSString *const kFIRMessagingMessageIDKey = @"gcm." @"message_id";
NSString *const kFIRMessagingMessageAPNSContentAvailableKey = @"content-available";
NSString *const kFIRMessagingMessageSyncViaMCSKey = @"gcm." @"duplex";
NSString *const kFIRMessagingMessageSyncMessageTTLKey = @"gcm." @"ttl";
NSString *const kFIRMessagingMessageLinkKey = @"gcm." @"app_link";

NSString *const kFIRMessagingRemoteNotificationsProxyEnabledInfoPlistKey =
    @"FirebaseAppDelegateProxyEnabled";

NSString *const kFIRMessagingSubDirectoryName = @"Google/FirebaseMessaging";

// Notifications
NSString *const kFIRMessagingCheckinFetchedNotification = @"com.google.gcm.notif-checkin-fetched";
NSString *const kFIRMessagingAPNSTokenNotification = @"com.firebase.iid.notif.apns-token";
NSString *const kFIRMessagingFCMTokenNotification = @"com.firebase.iid.notif.fcm-token";
NSString *const kFIRMessagingInstanceIDTokenRefreshNotification =
    @"com.firebase.iid.notif.refresh-token";
NSString *const kFIRMessagingRegistrationTokenRefreshNotification =
    @"com.firebase.iid.notif.refresh-token";

const int kFIRMessagingSendTtlDefault = 24 * 60 * 60; // 24 hours
