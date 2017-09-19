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

/**
 *  Global constants to be put here.
 *
 */
#import <Foundation/Foundation.h>

#ifndef _FIRMessaging_CONSTANTS_H
#define _FIRMessaging_CONSTANTS_H

FOUNDATION_EXPORT NSString *const kFIRMessagingRawDataKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingCollapseKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingFromKey;

FOUNDATION_EXPORT NSString *const kFIRMessagingSendTo;
FOUNDATION_EXPORT NSString *const kFIRMessagingSendTTL;
FOUNDATION_EXPORT NSString *const kFIRMessagingSendDelay;
FOUNDATION_EXPORT NSString *const kFIRMessagingSendMessageID;
FOUNDATION_EXPORT NSString *const KFIRMessagingSendMessageAppData;

FOUNDATION_EXPORT NSString *const kFIRMessagingMessageInternalReservedKeyword;
FOUNDATION_EXPORT NSString *const kFIRMessagingMessagePersistentIDKey;

FOUNDATION_EXPORT NSString *const kFIRMessagingMessageIDKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingMessageAPNSContentAvailableKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingMessageSyncViaMCSKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingMessageSyncMessageTTLKey;
FOUNDATION_EXPORT NSString *const kFIRMessagingMessageLinkKey;

FOUNDATION_EXPORT NSString *const kFIRMessagingRemoteNotificationsProxyEnabledInfoPlistKey;

FOUNDATION_EXPORT NSString *const kFIRMessagingApplicationSupportSubDirectory;

// Notifications
FOUNDATION_EXPORT NSString *const kFIRMessagingCheckinFetchedNotification;
FOUNDATION_EXPORT NSString *const kFIRMessagingAPNSTokenNotification;
FOUNDATION_EXPORT NSString *const kFIRMessagingFCMTokenNotification;
FOUNDATION_EXPORT NSString *const kFIRMessagingInstanceIDTokenRefreshNotification __deprecated_msg("Use kFIRMessagingRegistrationTokenRefreshNotification instead");
FOUNDATION_EXPORT NSString *const kFIRMessagingRegistrationTokenRefreshNotification;

FOUNDATION_EXPORT const int kFIRMessagingSendTtlDefault; // 24 hours

#endif
