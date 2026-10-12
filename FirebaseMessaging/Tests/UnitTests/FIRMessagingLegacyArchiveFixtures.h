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

#import <Foundation/Foundation.h>

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.h"

NS_ASSUME_NONNULL_BEGIN

/// Flavours of a corrupt nested `apns_info` blob, ordered by how far into `NSKeyedUnarchiver`
/// they get before failing.
typedef NS_ENUM(NSInteger, FIRMessagingCorruptPayloadKind) {
  /// Not a property list at all.
  FIRMessagingCorruptPayloadKindNotAPropertyList,
  /// A valid property list that is not a keyed archive.
  FIRMessagingCorruptPayloadKindPropertyListButNotAnArchive,
  /// A real keyed archive, truncated partway through.
  FIRMessagingCorruptPayloadKindTruncatedArchive,
};

/// Reproduces the `<= 10.18.0` *encoding* format, in which `apns_info` was written as a nested
/// `NSKeyedArchiver` blob rather than as a directly encoded object.
///
/// Verified line-by-line against `-[FIRMessagingTokenInfo encodeWithCoder:]` at tag `10.18.0`:
///
/// ```
/// git show 10.18.0:FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.m
/// ```
///
/// Note that `token_type` is deliberately absent: that key was introduced after 10.18.0.
///
/// > IMMUTABLE FIXTURE: do not "modernize" this encoder. It exists to emit bytes byte-for-byte
/// > equivalent to what 10.18.0 wrote. If a test using it fails, fix the production decoder
/// > rather than this mock.
@interface FIRMessagingTokenInfo_Legacy10_18 : FIRMessagingTokenInfo
@end

/// Reproduces the `12.x` *decoding* logic, used to prove that an older SDK can still read
/// archives written by the current one.
///
/// Verified line-by-line against `-[FIRMessagingTokenInfo initWithCoder:]` at tag `12.19.0`:
///
/// ```
/// git show 12.19.0:FirebaseMessaging/Sources/Token/FIRMessagingTokenInfo.m
/// ```
///
/// The only intentional deviations, neither of which affects decoded output:
///   1. Values are assigned with KVC because a subclass cannot reach the parent's ivars.
///   2. The `FIRMessagingLoggerInfo` call in the `@catch` is omitted.
///
/// > IMMUTABLE FIXTURE: do not "modernize" this decoder, and in particular do not delete the
/// > nested-blob branch. It is a record of what 12.x shipped.
@interface FIRMessagingTokenInfo_Legacy12 : FIRMessagingTokenInfo
@end

/// A stand-in for the "gadget class" in an Objective-C deserialization attack: it conforms to
/// `NSCoding` but deliberately not to `NSSecureCoding`, and it records whether the runtime ever
/// handed it a decoder.
///
/// A `requiresSecureCoding = YES` unarchiver must refuse to construct it. A
/// `requiresSecureCoding = NO` unarchiver will happily run its `-initWithCoder:`, which is the
/// primitive the real vulnerability was built on.
@interface FIRMessagingArchiveGadget : NSObject <NSCoding>

/// YES once `-initWithCoder:` has run on any instance. Reset this in `-setUp`; it is global
/// because the point is to observe construction from code that never returns the object.
@property(class, nonatomic, assign) BOOL wasDecoded;

@end

/// Read and write paths lifted from released SDKs, so compatibility tests exercise the genuine
/// legacy logic instead of an approximation of it.
@interface FIRMessagingLegacyArchiveFixtures : NSObject

/// Archives `tokenInfo` the way `-[FIRMessagingTokenStore saveTokenInfo:handler:]` did at tag
/// `12.19.0`: the deprecated insecure API, with the root object renamed to
/// `FIRInstanceIDTokenInfo`.
+ (NSData *)archiveWrittenBy12:(FIRMessagingTokenInfo *)tokenInfo;

/// Archives `tokenInfo` in the `<= 10.18.0` on-disk format. `tokenInfo` must be a
/// `FIRMessagingTokenInfo_Legacy10_18` so the legacy `encodeWithCoder:` runs.
+ (NSData *)archiveWrittenBy10_18:(FIRMessagingTokenInfo_Legacy10_18 *)tokenInfo;

/// Decodes `item` exactly as `+[FIRMessagingTokenStore tokenInfoFromKeychainItem:]` did at tag
/// `12.19.0`, routing the root object to `FIRMessagingTokenInfo_Legacy12` so that 12.x's
/// `initWithCoder:` is what actually runs.
+ (nullable FIRMessagingTokenInfo *)tokenInfoReadBy12:(NSData *)item;

/// A keychain item whose root object is a `FIRMessagingArchiveGadget` rather than a token info:
/// what a hostile process sharing the keychain access group would plant to attack the *outer*
/// unarchiver in `+[FIRMessagingTokenStore tokenInfoFromKeychainItem:]`.
+ (NSData *)archiveOfGadget;

/// A keychain item in the `<= 10.18.0` shape whose nested `apns_info` blob carries a
/// `FIRMessagingArchiveGadget` instead of an APNSInfo: the same attack aimed at the *nested*
/// unarchiver in `-[FIRMessagingTokenInfo initWithCoder:]`, which is the one the legacy fallback
/// keeps reachable.
+ (NSData *)archiveWithGadgetInNestedAPNSInfoForAuthorizedEntity:(NSString *)authorizedEntity
                                                           scope:(NSString *)scope
                                                           token:(NSString *)token;

/// A keychain item in the `<= 10.18.0` shape whose nested `apns_info` blob is corrupt rather than
/// hostile -- bit rot, a partial write, or a bug in some other writer. Distinct from the gadget
/// case because these fail at different depths of `NSKeyedUnarchiver`, and the shallow ones are
/// the ones that can raise rather than return an error.
+ (NSData *)archiveWithCorruptNestedAPNSInfoForAuthorizedEntity:(NSString *)authorizedEntity
                                                          scope:(NSString *)scope
                                                          token:(NSString *)token
                                                    payloadKind:
                                                        (FIRMessagingCorruptPayloadKind)kind;

@end

NS_ASSUME_NONNULL_END
