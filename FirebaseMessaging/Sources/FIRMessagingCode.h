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

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FIRMessagingMessageCode) {
  // FIRMessaging+FIRApp.m
  kFIRMessagingMessageCodeFIRApp000 = 1000,  // I-FCM001000
  kFIRMessagingMessageCodeFIRApp001 = 1001,  // I-FCM001001
  // FIRMessaging.m
  kFIRMessagingMessageCodeMessagingPrintLibraryVersion = 2000,  // I-FCM002000
  kFIRMessagingMessageCodeMessaging001 = 2001,                  // I-FCM002001
  kFIRMessagingMessageCodeMessaging002 = 2002,                  // I-FCM002002 - no longer used
  kFIRMessagingMessageCodeMessaging003 = 2003,                  // I-FCM002003
  kFIRMessagingMessageCodeMessaging004 = 2004,                  // I-FCM002004
  kFIRMessagingMessageCodeMessaging005 = 2005,                  // I-FCM002005
  kFIRMessagingMessageCodeMessaging006 = 2006,                  // I-FCM002006 - no longer used
  kFIRMessagingMessageCodeMessaging007 = 2007,                  // I-FCM002007 - no longer used
  kFIRMessagingMessageCodeMessaging008 = 2008,                  // I-FCM002008 - no longer used
  kFIRMessagingMessageCodeMessaging009 = 2009,                  // I-FCM002009
  kFIRMessagingMessageCodeMessaging010 = 2010,                  // I-FCM002010
  kFIRMessagingMessageCodeMessaging011 = 2011,                  // I-FCM002011
  kFIRMessagingMessageCodeMessaging012 = 2012,                  // I-FCM002012
  kFIRMessagingMessageCodeMessaging013 = 2013,                  // I-FCM002013
  kFIRMessagingMessageCodeMessaging014 = 2014,                  // I-FCM002014
  kFIRMessagingMessageCodeMessaging015 = 2015,
  kFIRMessagingMessageCodeMessaging016 = 2016,  // I-FCM002016 - no longer used
  kFIRMessagingMessageCodeMessaging017 = 2017,  // I-FCM002017
  kFIRMessagingMessageCodeMessaging018 = 2018,  // I-FCM002018
  kFIRMessagingMessageCodeRemoteMessageDelegateMethodNotImplemented = 2019,  // I-FCM002019
  kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenFetch = 2020,           // I-FCM002020
  kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenDelete = 2021,          // I-FCM002021
  kFIRMessagingMessageCodeAPNSTokenNotAvailableDuringTokenFetch = 2022,      // I-FCM002022
  kFIRMessagingMessageCodeTokenDelegateMethodsNotImplemented = 2023,         // I-FCM002023
  kFIRMessagingMessageCodeTopicFormatIsDeprecated = 2024,
  kFIRMessagingMessageCodeDirectChannelConnectionFailed = 2025,
  kFIRMessagingMessageCodeInvalidClient = 2026,  // no longer used

  // DO NOT USE 4000, 4004 - 4013
  kFIRMessagingMessageCodeClient001 = 4001,  // I-FCM004000
  kFIRMessagingMessageCodeClient002 = 4002,  // I-FCM004001
  kFIRMessagingMessageCodeClient003 = 4003,  // I-FCM004002

  // DO NOT USE 5000 - 5023
  // FIRMessagingContextManagerService.m
  kFIRMessagingMessageCodeContextManagerService000 = 6000,                  // I-FCM006000
  kFIRMessagingMessageCodeContextManagerService001 = 6001,                  // I-FCM006001
  kFIRMessagingMessageCodeContextManagerService002 = 6002,                  // I-FCM006002
  kFIRMessagingMessageCodeContextManagerService003 = 6003,                  // I-FCM006003
  kFIRMessagingMessageCodeContextManagerService004 = 6004,                  // I-FCM006004
  kFIRMessagingMessageCodeContextManagerService005 = 6005,                  // I-FCM006005
  kFIRMessagingMessageCodeContextManagerServiceFailedLocalSchedule = 6006,  // I-FCM006006
  // DO NOT USE 7000 - 7013

  // FIRMessagingPendingTopicsList.m
  kFIRMessagingMessageCodePendingTopicsList000 = 8000,  // I-FCM008000
  // FIRMessagingPubSub.m
  kFIRMessagingMessageCodePubSub000 = 9000,  // I-FCM009000
  kFIRMessagingMessageCodePubSub001 = 9001,  // I-FCM009001
  kFIRMessagingMessageCodePubSub002 = 9002,  // I-FCM009002
  kFIRMessagingMessageCodePubSub003 = 9003,  // I-FCM009003
  kFIRMessagingMessageCodePubSubArchiveError = 9004,
  kFIRMessagingMessageCodePubSubUnarchiveError = 9005,

  // FIRMessagingReceiver.m
  kFIRMessagingMessageCodeReceiver000 = 10000,  // I-FCM010000
  kFIRMessagingMessageCodeReceiver001 = 10001,  // I-FCM010001
  kFIRMessagingMessageCodeReceiver002 = 10002,  // I-FCM010002
  kFIRMessagingMessageCodeReceiver003 = 10003,  // I-FCM010003
  kFIRMessagingMessageCodeReceiver004 = 10004,  // I-FCM010004 - no longer used
  kFIRMessagingMessageCodeReceiver005 = 10005,  // I-FCM010005
  // FIRMessagingRegistrar.m
  kFIRMessagingMessageCodeRegistrar000 = 11000,  // I-FCM011000
  // FIRMessagingRemoteNotificationsProxy.m
  kFIRMessagingMessageCodeRemoteNotificationsProxy000 = 12000,             // I-FCM012000
  kFIRMessagingMessageCodeRemoteNotificationsProxy001 = 12001,             // I-FCM012001
  kFIRMessagingMessageCodeRemoteNotificationsProxyAPNSFailed = 12002,      // I-FCM012002
  kFIRMessagingMessageCodeRemoteNotificationsProxyMethodNotAdded = 12003,  // I-FCM012003
  // FIRMessagingRmq2PersistentStore.m
  // DO NOT USE 13000, 13001, 13009
  kFIRMessagingMessageCodeRmq2PersistentStore002 = 13002,                    // I-FCM013002
  kFIRMessagingMessageCodeRmq2PersistentStore003 = 13003,                    // I-FCM013003
  kFIRMessagingMessageCodeRmq2PersistentStore004 = 13004,                    // I-FCM013004
  kFIRMessagingMessageCodeRmq2PersistentStore005 = 13005,                    // I-FCM013005
  kFIRMessagingMessageCodeRmq2PersistentStore006 = 13006,                    // I-FCM013006
  kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingDatabase = 13007,  // I-FCM013007
  kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase = 13008,   // I-FCM013008
  kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingTable = 13010,     // I-FCM013010
  // FIRMessagingRmqManager.m
  kFIRMessagingMessageCodeRmqManager000 = 14000,  // I-FCM014000
  // FIRMessagingSyncMessageManager.m
  // DO NOT USE 16000, 16003
  kFIRMessagingMessageCodeSyncMessageManager001 = 16001,  // I-FCM016001
  kFIRMessagingMessageCodeSyncMessageManager002 = 16002,  // I-FCM016002
  kFIRMessagingMessageCodeSyncMessageManager004 = 16004,  // I-FCM016004
  kFIRMessagingMessageCodeSyncMessageManager005 = 16005,  // I-FCM016005
  kFIRMessagingMessageCodeSyncMessageManager006 = 16006,  // I-FCM016006
  kFIRMessagingMessageCodeSyncMessageManager007 = 16007,  // I-FCM016007
  kFIRMessagingMessageCodeSyncMessageManager008 = 16008,  // I-FCM016008
  // FIRMessagingTopicOperation.m
  kFIRMessagingMessageCodeTopicOption000 = 17000,                  // I-FCM017000
  kFIRMessagingMessageCodeTopicOption001 = 17001,                  // I-FCM017001
  kFIRMessagingMessageCodeTopicOption002 = 17002,                  // I-FCM017002
  kFIRMessagingMessageCodeTopicOptionTopicEncodingFailed = 17003,  // I-FCM017003
  kFIRMessagingMessageCodeTopicOperationEmptyResponse = 17004,     // I-FCM017004
  // FIRMessagingUtilities.m
  kFIRMessagingMessageCodeUtilities000 = 18000,  // I-FCM018000
  kFIRMessagingMessageCodeUtilities001 = 18001,  // I-FCM018001
  kFIRMessagingMessageCodeUtilities002 = 18002,  // I-FCM018002
  // FIRMessagingAnalytics.m
  kFIRMessagingMessageCodeAnalytics000 = 19000,                         // I-FCM019000
  kFIRMessagingMessageCodeAnalytics001 = 19001,                         // I-FCM019001
  kFIRMessagingMessageCodeAnalytics002 = 19002,                         // I-FCM019002
  kFIRMessagingMessageCodeAnalytics003 = 19003,                         // I-FCM019003
  kFIRMessagingMessageCodeAnalytics004 = 19004,                         // I-FCM019004
  kFIRMessagingMessageCodeAnalytics005 = 19005,                         // I-FCM019005
  kFIRMessagingMessageCodeAnalyticsInvalidEvent = 19006,                // I-FCM019006
  kFIRMessagingMessageCodeAnalytics007 = 19007,                         // I-FCM019007
  kFIRMessagingMessageCodeAnalyticsCouldNotInvokeAnalyticsLog = 19008,  // I-FCM019008

  // FIRMessagingExtensionHelper.m
  kFIRMessagingServiceExtensionImageInvalidURL = 20000,
  kFIRMessagingServiceExtensionImageNotDownloaded = 20001,
  kFIRMessagingServiceExtensionLocalFileNotCreated = 20002,
  kFIRMessagingServiceExtensionImageNotAttached = 20003,

  kFIRMessagingMessageCodeFIRApp002 = 22002,
  kFIRMessagingMessageCodeInternal001 = 22001,
  kFIRMessagingMessageCodeInternal002 = 22002,
  // FIRMessaging.m
  // DO NOT USE 4000.
  kFIRMessagingMessageCodeInstanceID000 = 23000,
  kFIRMessagingMessageCodeInstanceID001 = 23001,
  kFIRMessagingMessageCodeInstanceID002 = 23002,
  kFIRMessagingMessageCodeInstanceID003 = 23003,
  kFIRMessagingMessageCodeInstanceID004 = 23004,
  kFIRMessagingMessageCodeInstanceID005 = 23005,
  kFIRMessagingMessageCodeInstanceID006 = 23006,
  kFIRMessagingMessageCodeInstanceID007 = 23007,
  kFIRMessagingMessageCodeInstanceID008 = 23008,
  kFIRMessagingMessageCodeInstanceID009 = 23009,
  kFIRMessagingMessageCodeInstanceID010 = 23010,
  kFIRMessagingMessageCodeInstanceID011 = 23011,
  kFIRMessagingMessageCodeInstanceID012 = 23012,
  kFIRMessagingMessageCodeInstanceID013 = 23013,
  kFIRMessagingMessageCodeInstanceID014 = 23014,
  kFIRMessagingMessageCodeInstanceID015 = 23015,
  kFIRMessagingMessageCodeRefetchingTokenForAPNS = 23016,
  kFIRMessagingMessageCodeInstanceID017 = 23017,
  kFIRMessagingMessageCodeInstanceID018 = 23018,
  // FIRMessagingAuthService.m
  kFIRMessagingMessageCodeAuthService000 = 25000,
  kFIRMessagingMessageCodeAuthService001 = 25001,
  kFIRMessagingMessageCodeAuthService002 = 25002,
  kFIRMessagingMessageCodeAuthService003 = 25003,
  kFIRMessagingMessageCodeAuthService004 = 25004,
  kFIRMessagingMessageCodeAuthServiceCheckinInProgress = 25004,

  // FIRMessagingBackupExcludedPlist.m
  // Do NOT USE 6003
  kFIRMessagingMessageCodeBackupExcludedPlist000 = 26000,
  kFIRMessagingMessageCodeBackupExcludedPlist001 = 26001,
  kFIRMessagingMessageCodeBackupExcludedPlist002 = 26002,
  // FIRMessagingCheckinService.m
  kFIRMessagingMessageCodeService000 = 27000,
  kFIRMessagingMessageCodeService001 = 27001,
  kFIRMessagingMessageCodeService002 = 27002,
  kFIRMessagingMessageCodeService003 = 27003,
  kFIRMessagingMessageCodeService004 = 27004,
  kFIRMessagingMessageCodeService005 = 27005,
  kFIRMessagingMessageCodeService006 = 27006,
  kFIRMessagingInvalidSettingResponse = 27008,
  // FIRMessagingCheckinStore.m
  // DO NOT USE 8002, 8004 - 8008
  kFIRMessagingMessageCodeCheckinStore000 = 28000,
  kFIRMessagingMessageCodeCheckinStore001 = 28001,
  kFIRMessagingMessageCodeCheckinStore003 = 28003,
  kFIRMessagingMessageCodeCheckinStoreCheckinPlistDeleted = 28009,
  kFIRMessagingMessageCodeCheckinStoreCheckinPlistSaved = 28010,

  // DO NOT USE 9000 - 9006

  // DO NOT USE 10000 - 10009

  // DO NOT USE 11000 - 11002

  // DO NOT USE 12000 - 12014

  // DO NOT USE 13004, 13005, 13007, 13008, 13010, 13011, 13013, 13014
  kFIRMessagingMessageCodeStore000 = 33000,
  kFIRMessagingMessageCodeStore002 = 33002,
  kFIRMessagingMessageCodeStore003 = 33003,
  kFIRMessagingMessageCodeStore006 = 33006,
  kFIRMessagingMessageCodeStore009 = 33009,
  kFIRMessagingMessageCodeStore012 = 33012,
  // FIRMessagingTokenManager.m
  // DO NOT USE 14002, 14005
  kFIRMessagingMessageCodeTokenManager000 = 34000,
  kFIRMessagingMessageCodeTokenManager001 = 34001,
  kFIRMessagingMessageCodeTokenManager003 = 34003,
  kFIRMessagingMessageCodeTokenManager004 = 34004,
  kFIRMessagingMessageCodeTokenManagerErrorDeletingFCMTokensOnAppReset = 34006,
  kFIRMessagingMessageCodeTokenManagerDeletedFCMTokensOnAppReset = 34007,
  kFIRMessagingMessageCodeTokenManagerSavedAppVersion = 34008,
  kFIRMessagingMessageCodeTokenManagerErrorInvalidatingAllTokens = 34009,
  kFIRMessagingMessageCodeTokenManagerAPNSChanged = 34010,
  kFIRMessagingMessageCodeTokenManagerAPNSChangedTokenInvalidated = 34011,
  kFIRMessagingMessageCodeTokenManagerInvalidateStaleToken = 34012,
  // FIRMessagingTokenStore.m
  // DO NOT USE 15002 - 15013
  kFIRMessagingMessageCodeTokenStore000 = 35000,
  kFIRMessagingMessageCodeTokenStore001 = 35001,
  kFIRMessagingMessageCodeTokenStoreExceptionUnarchivingTokenInfo = 35015,

  // DO NOT USE 16000, 18004

  // FIRMessagingUtilities.m
  kFIRMessagingMessageCodeUtilitiesMissingBundleIdentifier = 38000,
  kFIRMessagingMessageCodeUtilitiesAppEnvironmentUtilNotAvailable = 38001,
  kFIRMessagingMessageCodeUtilitiesCannotGetHardwareModel = 38002,
  kFIRMessagingMessageCodeUtilitiesCannotGetSystemVersion = 38003,
  // FIRMessagingTokenOperation.m
  kFIRMessagingMessageCodeTokenOperationFailedToSignParams = 39000,
  // FIRMessagingTokenFetchOperation.m
  // DO NOT USE 40004, 40005
  kFIRMessagingMessageCodeTokenFetchOperationFetchRequest = 40000,
  kFIRMessagingMessageCodeTokenFetchOperationRequestError = 40001,
  kFIRMessagingMessageCodeTokenFetchOperationBadResponse = 40002,
  kFIRMessagingMessageCodeTokenFetchOperationBadTokenStructure = 40003,
  // FIRMessagingTokenDeleteOperation.m
  kFIRMessagingMessageCodeTokenDeleteOperationFetchRequest = 41000,
  kFIRMessagingMessageCodeTokenDeleteOperationRequestError = 41001,
  kFIRMessagingMessageCodeTokenDeleteOperationBadResponse = 41002,
  // FIRMessagingTokenInfo.m
  kFIRMessagingMessageCodeTokenInfoBadAPNSInfo = 42000,
  kFIRMessagingMessageCodeTokenInfoFirebaseAppIDChanged = 42001,
  kFIRMessagingMessageCodeTokenInfoLocaleChanged = 42002,
  // FIRMessagingKeychain.m
  kFIRMessagingKeychainReadItemError = 43000,
  kFIRMessagingKeychainAddItemError = 43001,
  kFIRMessagingKeychainDeleteItemError = 43002,
  kFIRMessagingKeychainCreateKeyPairError = 43003,
  kFIRMessagingKeychainUpdateItemError = 43004,
};
