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
  kFIRMessagingMessageCodeMessaging001 = 2001,  // I-FCM002001
  kFIRMessagingMessageCodeMessaging002 = 2002,  // I-FCM002002 - no longer used
  kFIRMessagingMessageCodeMessaging003 = 2003,  // I-FCM002003
  kFIRMessagingMessageCodeMessaging004 = 2004,  // I-FCM002004
  kFIRMessagingMessageCodeMessaging005 = 2005,  // I-FCM002005
  kFIRMessagingMessageCodeMessaging006 = 2006,  // I-FCM002006 - no longer used
  kFIRMessagingMessageCodeMessaging007 = 2007,  // I-FCM002007 - no longer used
  kFIRMessagingMessageCodeMessaging008 = 2008,  // I-FCM002008 - no longer used
  kFIRMessagingMessageCodeMessaging009 = 2009,  // I-FCM002009
  kFIRMessagingMessageCodeMessaging010 = 2010,  // I-FCM002010
  kFIRMessagingMessageCodeMessaging011 = 2011,  // I-FCM002011
  kFIRMessagingMessageCodeMessaging012 = 2012,  // I-FCM002012
  kFIRMessagingMessageCodeMessaging013 = 2013,  // I-FCM002013
  kFIRMessagingMessageCodeMessaging014 = 2014,  // I-FCM002014
  kFIRMessagingMessageCodeMessaging015 = 2015,  // I-FCM002015
  kFIRMessagingMessageCodeMessaging016 = 2016,  // I-FCM002016 - no longer used
  kFIRMessagingMessageCodeMessaging017 = 2017,  // I-FCM002017
  kFIRMessagingMessageCodeMessaging018 = 2018,  // I-FCM002018
  kFIRMessagingMessageCodeRemoteMessageDelegateMethodNotImplemented = 2019, // I-FCM002019
  kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenFetch = 2020, // I-FCM002020
  kFIRMessagingMessageCodeSenderIDNotSuppliedForTokenDelete = 2021, // I-FCM002021
  kFIRMessagingMessageCodeAPNSTokenNotAvailableDuringTokenFetch = 2022, // I-FCM002022
  kFIRMessagingMessageCodeTokenDelegateMethodsNotImplemented = 2023, // I-FCM002023
  kFIRMessagingMessageCodeTopicFormatIsDeprecated = 2024,
  kFIRMessagingMessageCodeDirectChannelConnectionFailed = 2025,
  kFIRMessagingMessageCodeInvalidClient = 2026,
  // FIRMessagingClient.m
  kFIRMessagingMessageCodeClient000 = 4000,  // I-FCM004000
  kFIRMessagingMessageCodeClient001 = 4001,  // I-FCM004001
  kFIRMessagingMessageCodeClient002 = 4002,  // I-FCM004002
  kFIRMessagingMessageCodeClient003 = 4003,  // I-FCM004003
  kFIRMessagingMessageCodeClient004 = 4004,  // I-FCM004004
  kFIRMessagingMessageCodeClient005 = 4005,  // I-FCM004005
  kFIRMessagingMessageCodeClient006 = 4006,  // I-FCM004006
  kFIRMessagingMessageCodeClient007 = 4007,  // I-FCM004007
  kFIRMessagingMessageCodeClient008 = 4008,  // I-FCM004008
  kFIRMessagingMessageCodeClient009 = 4009,  // I-FCM004009
  kFIRMessagingMessageCodeClient010 = 4010,  // I-FCM004010
  kFIRMessagingMessageCodeClient011 = 4011,  // I-FCM004011
  kFIRMessagingMessageCodeClientInvalidState = 4012,
  kFIRMessagingMessageCodeClientInvalidStateTimeout = 4013,

  // FIRMessagingConnection.m
  kFIRMessagingMessageCodeConnection000 = 5000,  // I-FCM005000
  kFIRMessagingMessageCodeConnection001 = 5001,  // I-FCM005001
  kFIRMessagingMessageCodeConnection002 = 5002,  // I-FCM005002
  kFIRMessagingMessageCodeConnection003 = 5003,  // I-FCM005003
  kFIRMessagingMessageCodeConnection004 = 5004,  // I-FCM005004
  kFIRMessagingMessageCodeConnection005 = 5005,  // I-FCM005005
  kFIRMessagingMessageCodeConnection006 = 5006,  // I-FCM005006
  kFIRMessagingMessageCodeConnection007 = 5007,  // I-FCM005007
  kFIRMessagingMessageCodeConnection008 = 5008,  // I-FCM005008
  kFIRMessagingMessageCodeConnection009 = 5009,  // I-FCM005009
  kFIRMessagingMessageCodeConnection010 = 5010,  // I-FCM005010
  kFIRMessagingMessageCodeConnection011 = 5011,  // I-FCM005011
  kFIRMessagingMessageCodeConnection012 = 5012,  // I-FCM005012
  kFIRMessagingMessageCodeConnection013 = 5013,  // I-FCM005013
  kFIRMessagingMessageCodeConnection014 = 5014,  // I-FCM005014
  kFIRMessagingMessageCodeConnection015 = 5015,  // I-FCM005015
  kFIRMessagingMessageCodeConnection016 = 5016,  // I-FCM005016
  kFIRMessagingMessageCodeConnection017 = 5017,  // I-FCM005017
  kFIRMessagingMessageCodeConnection018 = 5018,  // I-FCM005018
  kFIRMessagingMessageCodeConnection019 = 5019,  // I-FCM005019
  kFIRMessagingMessageCodeConnection020 = 5020,  // I-FCM005020
  kFIRMessagingMessageCodeConnection021 = 5021,  // I-FCM005021
  kFIRMessagingMessageCodeConnection022 = 5022,  // I-FCM005022
  kFIRMessagingMessageCodeConnection023 = 5023,  // I-FCM005023
  // FIRMessagingContextManagerService.m
  kFIRMessagingMessageCodeContextManagerService000 = 6000,  // I-FCM006000
  kFIRMessagingMessageCodeContextManagerService001 = 6001,  // I-FCM006001
  kFIRMessagingMessageCodeContextManagerService002 = 6002,  // I-FCM006002
  kFIRMessagingMessageCodeContextManagerService003 = 6003,  // I-FCM006003
  kFIRMessagingMessageCodeContextManagerService004 = 6004,  // I-FCM006004
  kFIRMessagingMessageCodeContextManagerService005 = 6005,  // I-FCM006005
  // FIRMessagingDataMessageManager.m
  // DO NOT USE 7005
  kFIRMessagingMessageCodeDataMessageManager000 = 7000,  // I-FCM007000
  kFIRMessagingMessageCodeDataMessageManager001 = 7001,  // I-FCM007001
  kFIRMessagingMessageCodeDataMessageManager002 = 7002,  // I-FCM007002
  kFIRMessagingMessageCodeDataMessageManager003 = 7003,  // I-FCM007003
  kFIRMessagingMessageCodeDataMessageManager004 = 7004,  // I-FCM007004
  kFIRMessagingMessageCodeDataMessageManager006 = 7006,  // I-FCM007006
  kFIRMessagingMessageCodeDataMessageManager007 = 7007,  // I-FCM007007
  kFIRMessagingMessageCodeDataMessageManager008 = 7008,  // I-FCM007008
  kFIRMessagingMessageCodeDataMessageManager009 = 7009,  // I-FCM007009
  kFIRMessagingMessageCodeDataMessageManager010 = 7010,  // I-FCM007010
  kFIRMessagingMessageCodeDataMessageManager011 = 7011,  // I-FCM007011
  kFIRMessagingMessageCodeDataMessageManager012 = 7012,  // I-FCM007012
  kFIRMessagingMessageCodeDataMessageManager013 = 7013,

  // FIRMessagingPendingTopicsList.m
  kFIRMessagingMessageCodePendingTopicsList000 = 8000,  // I-FCM008000
  // FIRMessagingPubSub.m
  kFIRMessagingMessageCodePubSub000 = 9000,  // I-FCM009000
  kFIRMessagingMessageCodePubSub001 = 9001,  // I-FCM009001
  kFIRMessagingMessageCodePubSub002 = 9002,  // I-FCM009002
  kFIRMessagingMessageCodePubSub003 = 9003,  // I-FCM009003
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
  kFIRMessagingMessageCodeRemoteNotificationsProxy000 = 12000,  // I-FCM012000
  kFIRMessagingMessageCodeRemoteNotificationsProxy001 = 12001,  // I-FCM012001
  kFIRMessagingMessageCodeRemoteNotificationsProxyAPNSFailed = 12002,  // I-FCM012002
  kFIRMessagingMessageCodeRemoteNotificationsProxyMethodNotAdded = 12003,  // I-FCM012003
  // FIRMessagingRmq2PersistentStore.m
  // DO NOT USE 13000, 13001, 13009
  kFIRMessagingMessageCodeRmq2PersistentStore002 = 13002,  // I-FCM013002
  kFIRMessagingMessageCodeRmq2PersistentStore003 = 13003,  // I-FCM013003
  kFIRMessagingMessageCodeRmq2PersistentStore004 = 13004,  // I-FCM013004
  kFIRMessagingMessageCodeRmq2PersistentStore005 = 13005,  // I-FCM013005
  kFIRMessagingMessageCodeRmq2PersistentStore006 = 13006,  // I-FCM013006
  kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingDatabase = 13007,  // I-FCM013007
  kFIRMessagingMessageCodeRmq2PersistentStoreErrorOpeningDatabase = 13008,  // I-FCM013008
  kFIRMessagingMessageCodeRmq2PersistentStoreErrorCreatingTable = 13010,  // I-FCM013010
  // FIRMessagingRmqManager.m
  kFIRMessagingMessageCodeRmqManager000 = 14000,  // I-FCM014000
  // FIRMessagingSecureSocket.m
  kFIRMessagingMessageCodeSecureSocket000 = 15000,  // I-FCM015000
  kFIRMessagingMessageCodeSecureSocket001 = 15001,  // I-FCM015001
  kFIRMessagingMessageCodeSecureSocket002 = 15002,  // I-FCM015002
  kFIRMessagingMessageCodeSecureSocket003 = 15003,  // I-FCM015003
  kFIRMessagingMessageCodeSecureSocket004 = 15004,  // I-FCM015004
  kFIRMessagingMessageCodeSecureSocket005 = 15005,  // I-FCM015005
  kFIRMessagingMessageCodeSecureSocket006 = 15006,  // I-FCM015006
  kFIRMessagingMessageCodeSecureSocket007 = 15007,  // I-FCM015007
  kFIRMessagingMessageCodeSecureSocket008 = 15008,  // I-FCM015008
  kFIRMessagingMessageCodeSecureSocket009 = 15009,  // I-FCM015009
  kFIRMessagingMessageCodeSecureSocket010 = 15010,  // I-FCM015010
  kFIRMessagingMessageCodeSecureSocket011 = 15011,  // I-FCM015011
  kFIRMessagingMessageCodeSecureSocket012 = 15012,  // I-FCM015012
  kFIRMessagingMessageCodeSecureSocket013 = 15013,  // I-FCM015013
  kFIRMessagingMessageCodeSecureSocket014 = 15014,  // I-FCM015014
  kFIRMessagingMessageCodeSecureSocket015 = 15015,  // I-FCM015015
  kFIRMessagingMessageCodeSecureSocket016 = 15016,  // I-FCM015016
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
  kFIRMessagingMessageCodeTopicOption000 = 17000,  // I-FCM017000
  kFIRMessagingMessageCodeTopicOption001 = 17001,  // I-FCM017001
  kFIRMessagingMessageCodeTopicOption002 = 17002,  // I-FCM017002
  kFIRMessagingMessageCodeTopicOptionTopicEncodingFailed = 17003,  // I-FCM017003
  kFIRMessagingMessageCodeTopicOperationEmptyResponse = 17004,  // I-FCM017004
  // FIRMessagingUtilities.m
  kFIRMessagingMessageCodeUtilities000 = 18000,  // I-FCM018000
  kFIRMessagingMessageCodeUtilities001 = 18001,  // I-FCM018001
  kFIRMessagingMessageCodeUtilities002 = 18002,  // I-FCM018002
  // FIRMessagingAnalytics.m
  kFIRMessagingMessageCodeAnalytics000 = 19000,  // I-FCM019000
  kFIRMessagingMessageCodeAnalytics001 = 19001,  // I-FCM019001
  kFIRMessagingMessageCodeAnalytics002 = 19002,  // I-FCM019002
  kFIRMessagingMessageCodeAnalytics003 = 19003,  // I-FCM019003
  kFIRMessagingMessageCodeAnalytics004 = 19004,  // I-FCM019004
  kFIRMessagingMessageCodeAnalytics005 = 19005,  // I-FCM019005
  kFIRMessagingMessageCodeAnalyticsInvalidEvent = 19006,  // I-FCM019006
  kFIRMessagingMessageCodeAnalytics007 = 19007,  // I-FCM019007
  kFIRMessagingMessageCodeAnalyticsCouldNotInvokeAnalyticsLog = 19008,  // I-FCM019008

  // FIRMessagingExtensionHelper.m
  kFIRMessagingServiceExtensionImageInvalidURL = 20000,
  kFIRMessagingServiceExtensionImageNotDownloaded = 20001,
  kFIRMessagingServiceExtensionLocalFileNotCreated = 20002,
  kFIRMessagingServiceExtensionImageNotAttached = 20003,

  // FIRMessagingCodedInputStream.m
  kFIRMessagingCodeInputStreamInvalidParameters = 21000,

};
