/*
 * Copyright 2026 Google LLC
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

#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingLegacyArchiveFixtures.h"

#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"

// Persisted key names. These are duplicated here rather than imported so that a rename in
// production code causes a visible test failure instead of silently moving the fixtures too.
static NSString *const kLegacyAuthorizedEntityKey = @"authorized_entity";
static NSString *const kLegacyScopeKey = @"scope";
static NSString *const kLegacyTokenKey = @"token";
static NSString *const kLegacyAppVersionKey = @"app_version";
static NSString *const kLegacyFirebaseAppIDKey = @"firebase_app_id";
static NSString *const kLegacyAPNSInfoKey = @"apns_info";
static NSString *const kLegacyCacheTimeKey = @"cache_time";
static NSString *const kLegacyTokenTypeKey = @"token_type";

static NSString *const kLegacyTokenInfoClassName = @"FIRInstanceIDTokenInfo";
static NSString *const kLegacyAPNSInfoClassName = @"FIRInstanceIDAPNSInfo";

#pragma mark - 10.18.0 encoder

@implementation FIRMessagingTokenInfo_Legacy10_18

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:kLegacyAuthorizedEntityKey];
  [aCoder encodeObject:self.scope forKey:kLegacyScopeKey];
  [aCoder encodeObject:self.token forKey:kLegacyTokenKey];
  [aCoder encodeObject:self.appVersion forKey:kLegacyAppVersionKey];
  [aCoder encodeObject:self.firebaseAppID forKey:kLegacyFirebaseAppIDKey];
  NSData *rawAPNSInfo;
  if (self.APNSInfo) {
    // 10.18.0 left this process-global mapping installed. Restoring it below is the one
    // deliberate difference from the shipped encoder; it does not affect the bytes produced.
    NSString *previousName = [NSKeyedArchiver classNameForClass:[FIRMessagingAPNSInfo class]];
    [NSKeyedArchiver setClassName:kLegacyAPNSInfoClassName forClass:[FIRMessagingAPNSInfo class]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    rawAPNSInfo = [NSKeyedArchiver archivedDataWithRootObject:self.APNSInfo];
#pragma clang diagnostic pop
    [NSKeyedArchiver setClassName:previousName forClass:[FIRMessagingAPNSInfo class]];

    [aCoder encodeObject:rawAPNSInfo forKey:kLegacyAPNSInfoKey];
  }
  [aCoder encodeObject:self.cacheTime forKey:kLegacyCacheTimeKey];
}

@end

#pragma mark - 12.19.0 decoder

@implementation FIRMessagingTokenInfo_Legacy12

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  BOOL needsMigration = NO;
  // These value cannot be nil

  NSString *authorizedEntity = [aDecoder decodeObjectOfClass:[NSString class]
                                                      forKey:kLegacyAuthorizedEntityKey];
  if (!authorizedEntity) {
    return nil;
  }

  NSString *scope = [aDecoder decodeObjectOfClass:[NSString class] forKey:kLegacyScopeKey];
  if (!scope) {
    return nil;
  }

  NSString *token = [aDecoder decodeObjectOfClass:[NSString class] forKey:kLegacyTokenKey];
  if (!token) {
    return nil;
  }

  // These values are nullable, so don't fail on nil.

  NSString *appVersion = [aDecoder decodeObjectOfClass:[NSString class]
                                                forKey:kLegacyAppVersionKey];
  NSString *firebaseAppID = [aDecoder decodeObjectOfClass:[NSString class]
                                                   forKey:kLegacyFirebaseAppIDKey];

  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingAPNSInfo.class ]];
  FIRMessagingAPNSInfo *rawAPNSInfo = [aDecoder decodeObjectOfClasses:classes
                                                               forKey:kLegacyAPNSInfoKey];
  if (rawAPNSInfo && ![rawAPNSInfo isKindOfClass:[FIRMessagingAPNSInfo class]]) {
    // If the decoder fails to decode a FIRMessagingAPNSInfo, check if this was archived by a
    // FirebaseMessaging 10.18.0 or earlier.
    @try {
      NSKeyedUnarchiver *unarchiver =
          [[NSKeyedUnarchiver alloc] initForReadingFromData:(NSData *)rawAPNSInfo error:nil];
      unarchiver.requiresSecureCoding = NO;
      [unarchiver setClass:[FIRMessagingAPNSInfo class] forClassName:kLegacyAPNSInfoClassName];
      rawAPNSInfo = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
      [unarchiver finishDecoding];
      needsMigration = YES;
    } @catch (NSException *exception) {
      rawAPNSInfo = nil;
    } @finally {
    }
  }

  NSDate *cacheTime = [aDecoder decodeObjectOfClass:[NSDate class] forKey:kLegacyCacheTimeKey];
  NSString *tokenType = [aDecoder decodeObjectOfClass:[NSString class] forKey:kLegacyTokenTypeKey];

  self = [super init];
  if (self) {
    // 12.19.0 assigned the parent's ivars directly. A subclass cannot, so use KVC; the resulting
    // property values are identical.
    [self setValue:[authorizedEntity copy] forKey:@"authorizedEntity"];
    [self setValue:[scope copy] forKey:@"scope"];
    [self setValue:[token copy] forKey:@"token"];
    [self setValue:[appVersion copy] forKey:@"appVersion"];
    [self setValue:[firebaseAppID copy] forKey:@"firebaseAppID"];
    [self setValue:[rawAPNSInfo copy] forKey:@"APNSInfo"];
    [self setValue:cacheTime forKey:@"cacheTime"];
    [self setValue:@(needsMigration) forKey:@"needsMigration"];
    [self setValue:([tokenType copy] ?: @"V4") forKey:@"tokenType"];
  }
  return self;
}

@end

#pragma mark - Deserialization gadget

@implementation FIRMessagingArchiveGadget

static BOOL sGadgetWasDecoded = NO;

+ (BOOL)wasDecoded {
  return sGadgetWasDecoded;
}

+ (void)setWasDecoded:(BOOL)wasDecoded {
  sGadgetWasDecoded = wasDecoded;
}

// Deliberately does not implement `+supportsSecureCoding`, so it defaults to NO.

- (instancetype)initWithCoder:(NSCoder *)coder {
  // A real gadget would do something harmful here. Recording the call is enough to prove the
  // unarchiver was willing to run attacker-reachable code.
  FIRMessagingArchiveGadget.wasDecoded = YES;
  return [super init];
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end

/// Writes the `<= 10.18.0` key set, but with a caller-supplied payload standing in for the
/// nested APNSInfo blob. Only the `apns_info` value differs from
/// `FIRMessagingTokenInfo_Legacy10_18`; everything else stays well-formed so a test can tell
/// "APNSInfo was rejected" apart from "the whole record was rejected".
@interface FIRMessagingTokenInfo_SubstituteAPNSInfo : FIRMessagingTokenInfo
@property(nonatomic, strong) NSData *substitutePayload;
@end

@implementation FIRMessagingTokenInfo_SubstituteAPNSInfo

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.authorizedEntity forKey:kLegacyAuthorizedEntityKey];
  [aCoder encodeObject:self.scope forKey:kLegacyScopeKey];
  [aCoder encodeObject:self.token forKey:kLegacyTokenKey];
  [aCoder encodeObject:self.appVersion forKey:kLegacyAppVersionKey];
  [aCoder encodeObject:self.firebaseAppID forKey:kLegacyFirebaseAppIDKey];
  [aCoder encodeObject:self.substitutePayload forKey:kLegacyAPNSInfoKey];
  [aCoder encodeObject:self.cacheTime forKey:kLegacyCacheTimeKey];
}

@end

#pragma mark - Released store read/write paths

@implementation FIRMessagingLegacyArchiveFixtures

+ (NSData *)archiveWrittenBy12:(FIRMessagingTokenInfo *)tokenInfo {
  // `setClassName:forClass:` keys off the exact class, so rename whichever class `tokenInfo`
  // actually is. In the shipped SDK that was always `FIRMessagingTokenInfo`; here it may be the
  // `FIRMessagingTokenInfo_Legacy12` produced by `+tokenInfoReadBy12:`. Either way the encoder
  // that runs is the one `FIRMessagingTokenInfo` declares -- which 12.19.0 shares byte-for-byte
  // with HEAD -- and the root object is named `FIRInstanceIDTokenInfo`, so the archive matches
  // what 12.x wrote.
  Class tokenInfoClass = [tokenInfo class];
  NSString *previousName = [NSKeyedArchiver classNameForClass:tokenInfoClass];
  [NSKeyedArchiver setClassName:kLegacyTokenInfoClassName forClass:tokenInfoClass];
  NSData *archive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  archive = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo];
#pragma clang diagnostic pop
  [NSKeyedArchiver setClassName:previousName forClass:tokenInfoClass];
  return archive;
}

+ (NSData *)archiveWrittenBy10_18:(FIRMessagingTokenInfo_Legacy10_18 *)tokenInfo {
  NSString *previousName =
      [NSKeyedArchiver classNameForClass:[FIRMessagingTokenInfo_Legacy10_18 class]];
  [NSKeyedArchiver setClassName:kLegacyTokenInfoClassName
                       forClass:[FIRMessagingTokenInfo_Legacy10_18 class]];
  NSData *archive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  archive = [NSKeyedArchiver archivedDataWithRootObject:tokenInfo];
#pragma clang diagnostic pop
  [NSKeyedArchiver setClassName:previousName forClass:[FIRMessagingTokenInfo_Legacy10_18 class]];
  return archive;
}

+ (nullable FIRMessagingTokenInfo *)tokenInfoReadBy12:(NSData *)item {
  FIRMessagingTokenInfo *tokenInfo = nil;
  if (item) {
    @try {
      NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:item
                                                                                  error:nil];
      unarchiver.requiresSecureCoding = NO;
      // The shipped code mapped this onto FIRMessagingTokenInfo. Routing it to the 12.x mock
      // instead is what makes 12.x's `initWithCoder:` the code under test.
      [unarchiver setClass:[FIRMessagingTokenInfo_Legacy12 class]
              forClassName:kLegacyTokenInfoClassName];
      tokenInfo = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
      [unarchiver finishDecoding];
    } @catch (NSException *exception) {
      tokenInfo = nil;
    } @finally {
    }
  }
  return tokenInfo;
}

+ (NSData *)archiveOfGadget {
  // Secure archiving would refuse to encode a class that does not support it, which is exactly
  // why an attacker would not use it either.
  NSData *archive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  archive = [NSKeyedArchiver archivedDataWithRootObject:[[FIRMessagingArchiveGadget alloc] init]];
#pragma clang diagnostic pop
  return archive;
}

+ (NSData *)archiveWithSubstituteAPNSInfoPayload:(NSData *)payload
                                authorizedEntity:(NSString *)authorizedEntity
                                           scope:(NSString *)scope
                                           token:(NSString *)token {
  FIRMessagingTokenInfo_SubstituteAPNSInfo *substituted =
      [[FIRMessagingTokenInfo_SubstituteAPNSInfo alloc] initWithAuthorizedEntity:authorizedEntity
                                                                           scope:scope
                                                                           token:token
                                                                      appVersion:@"1.0"
                                                                   firebaseAppID:@"firebaseAppID"
                                                                       tokenType:@"V4"];
  substituted.substitutePayload = payload;
  substituted.cacheTime = [NSDate date];

  Class substitutedClass = [FIRMessagingTokenInfo_SubstituteAPNSInfo class];
  NSString *previousName = [NSKeyedArchiver classNameForClass:substitutedClass];
  [NSKeyedArchiver setClassName:kLegacyTokenInfoClassName forClass:substitutedClass];
  NSData *archive;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  archive = [NSKeyedArchiver archivedDataWithRootObject:substituted];
#pragma clang diagnostic pop
  [NSKeyedArchiver setClassName:previousName forClass:substitutedClass];
  return archive;
}

+ (NSData *)archiveWithGadgetInNestedAPNSInfoForAuthorizedEntity:(NSString *)authorizedEntity
                                                           scope:(NSString *)scope
                                                           token:(NSString *)token {
  return [self archiveWithSubstituteAPNSInfoPayload:[self archiveOfGadget]
                                   authorizedEntity:authorizedEntity
                                              scope:scope
                                              token:token];
}

+ (NSData *)archiveWithCorruptNestedAPNSInfoForAuthorizedEntity:(NSString *)authorizedEntity
                                                          scope:(NSString *)scope
                                                          token:(NSString *)token
                                                    payloadKind:
                                                        (FIRMessagingCorruptPayloadKind)kind {
  NSData *payload = nil;
  switch (kind) {
    case FIRMessagingCorruptPayloadKindNotAPropertyList:
      // Bytes that are not a plist at all. The archiver should reject these outright.
      payload = [@"this is not an archive" dataUsingEncoding:NSUTF8StringEncoding];
      break;
    case FIRMessagingCorruptPayloadKindPropertyListButNotAnArchive:
      // A well-formed plist that lacks `$archiver` / `$objects`. This is the more interesting
      // case: the header parses, so failure happens further into the unarchiver.
      payload = [NSPropertyListSerialization dataWithPropertyList:@{@"not" : @"an archive"}
                                                           format:NSPropertyListBinaryFormat_v1_0
                                                          options:0
                                                            error:NULL];
      break;
    case FIRMessagingCorruptPayloadKindTruncatedArchive: {
      // A real archive with its tail lopped off, which is what bit-rot or a partial write looks
      // like rather than a deliberate attack.
      NSData *whole = [self archiveOfGadget];
      payload = [whole subdataWithRange:NSMakeRange(0, whole.length / 2)];
      break;
    }
  }
  return [self archiveWithSubstituteAPNSInfoPayload:payload
                                   authorizedEntity:authorizedEntity
                                              scope:scope
                                              token:token];
}

@end
