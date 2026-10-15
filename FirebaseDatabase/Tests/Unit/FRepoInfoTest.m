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
#import <GoogleUtilities/GULUserDefaults.h>
#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

// The configured host of the repo infos in the host tests, and the user
// defaults key that FRepoInfo saves their internal host under.
static NSString *const kConfiguredHost = @"repo-info-test.firebaseio.com";
static NSString *const kHostKey = @"firebase:host:repo-info-test.firebaseio.com";
// An IPv6 emulator host, which isn't a valid server host.
static NSString *const kIPv6ConfiguredHost = @"[::1]:9000";
static NSString *const kIPv6HostKey = @"firebase:host:[::1]:9000";
// A configured host that's short enough to be a tagged pointer string.
static NSString *const kShortConfiguredHost = @"db";
static NSString *const kShortHostKey = @"firebase:host:db";
// A host that the server provides.
static NSString *const kServerHost = @"s-usc1a-nss-2001.firebaseio.com";

@interface FRepoInfoTest : XCTestCase

@end

@implementation FRepoInfoTest

- (void)setUp {
  [super setUp];
  [self removeSavedHosts];
}

- (void)tearDown {
  [self removeSavedHosts];
  [super tearDown];
}

- (void)removeSavedHosts {
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kHostKey];
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kIPv6HostKey];
  [[GULUserDefaults standardUserDefaults] removeObjectForKey:kShortHostKey];
}

- (FRepoInfo *)repoInfo {
  return [[FRepoInfo alloc] initWithHost:kConfiguredHost
                                isSecure:YES
                           withNamespace:@"repo-info-test"];
}

- (id)savedHost {
  return [[GULUserDefaults standardUserDefaults] objectForKey:kHostKey];
}

- (void)testGetConnectionUrl {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"test-namespace.example.com"
                                           isSecure:NO
                                      withNamespace:@"tests"];
  XCTAssertEqualObjects(info.connectionURL, @"ws://test-namespace.example.com/.ws?v=5&ns=tests",
                        @"getConnection works");
}

- (void)testGetConnectionUrlWithLastSession {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:@"tests-namespace.example.com"
                                           isSecure:NO
                                      withNamespace:@"tests"];
  XCTAssertEqualObjects([info connectionURLWithLastSessionID:@"testsession"],
                        @"ws://tests-namespace.example.com/.ws?v=5&ns=tests&ls=testsession",
                        @"getConnectionWithLastSession works");
}

- (void)testIsValidHost {
  NSArray *validHosts = @[
    @"s-usc1a-nss-2001.firebaseio.com", @"test-db.europe-west1.firebasedatabase.app",
    @"S-USC1A-NSS-2001.FIREBASEIO.COM", @"s-usc1a-nss-2001.firebaseio.com.",
    @"xn--bcher-kva.example", @"localhost:9000", @"127.0.0.1:9000", @"192.168.1.10:9000"
  ];
  for (NSString *host in validHosts) {
    XCTAssertTrue([FRepoInfo isValidHost:host], @"%@", host);
  }

  NSString *longHost = [@"" stringByPaddingToLength:300 withString:@"a" startingAtIndex:0];
  NSArray *invalidHosts = @[
    @"",
    @5,
    @"bad host",
    @"bad\thost",
    @"bad\nhost",
    @"localhost\n",
    @"a\"b",
    @"a%zzb",
    @"x/y",
    @"x?y",
    @"x#y",
    @"user@host",
    @"[",
    kIPv6ConfiguredHost,
    @"b\u00fccher.example",
    longHost,
    @"x:abc",
    @"localhost:123456",
    @":9000",
    @"a_b.com"
  ];
  XCTAssertFalse([FRepoInfo isValidHost:nil]);
  for (id host in invalidHosts) {
    XCTAssertFalse([FRepoInfo isValidHost:host], @"%@", host);
  }
}

// Earlier versions saved any host that the server sent. A host that can't be
// used in a URL crashed the app at every launch, so it should be discarded.
- (void)testInvalidSavedHostIsDiscarded {
  [[GULUserDefaults standardUserDefaults] setObject:@"bad host" forKey:kHostKey];

  FRepoInfo *info = [self repoInfo];

  XCTAssertEqualObjects(info.internalHost, kConfiguredHost);
  XCTAssertNil([self savedHost]);
}

- (void)testValidSavedHostIsUsed {
  [[GULUserDefaults standardUserDefaults] setObject:kServerHost forKey:kHostKey];

  FRepoInfo *info = [self repoInfo];

  XCTAssertEqualObjects(info.internalHost, kServerHost);
  XCTAssertEqualObjects([self savedHost], kServerHost);
}

- (void)testSetInternalHostSavesValidHost {
  FRepoInfo *info = [self repoInfo];

  info.internalHost = kServerHost;

  XCTAssertEqualObjects(info.internalHost, kServerHost);
  XCTAssertEqualObjects([self savedHost], kServerHost);
  XCTAssertEqualObjects([self repoInfo].internalHost, kServerHost);
}

// The property is declared copy.
- (void)testSetInternalHostCopiesHost {
  FRepoInfo *info = [self repoInfo];
  NSMutableString *host = [kServerHost mutableCopy];

  info.internalHost = host;
  [host appendString:@".example"];

  XCTAssertEqualObjects(info.internalHost, kServerHost);
}

// Setting the current host is a no-op, as before, so nothing is saved.
- (void)testSetInternalHostToCurrentHostDoesNothing {
  FRepoInfo *info = [self repoInfo];

  info.internalHost = kConfiguredHost;

  XCTAssertEqualObjects(info.internalHost, kConfiguredHost);
  XCTAssertNil([self savedHost]);
}

// The internal host comes from the server and is saved, so a host that can't
// be used in a URL should neither be used nor saved.
- (void)testSetInternalHostIgnoresInvalidHost {
  FRepoInfo *info = [self repoInfo];

  info.internalHost = @"bad host";

  XCTAssertEqualObjects(info.internalHost, kConfiguredHost);
  XCTAssertNil([self savedHost]);
}

- (void)testSetInternalHostIgnoresInvalidHostsAfterRedirect {
  FRepoInfo *info = [self repoInfo];
  info.internalHost = kServerHost;

  // E.g. a handshake without a host.
  NSString *missingHost = nil;
  info.internalHost = missingHost;
  XCTAssertEqualObjects(info.internalHost, kServerHost);
  XCTAssertEqualObjects([self savedHost], kServerHost);

  for (id host in @[ @5, @"bad host" ]) {
    info.internalHost = host;
    XCTAssertEqualObjects(info.internalHost, kServerHost, @"%@", host);
    XCTAssertEqualObjects([self savedHost], kServerHost, @"%@", host);
  }
}

// A short host can be a tagged pointer string, whose -isEqualToString: throws
// for an argument that isn't a string.
- (void)testSetInternalHostIgnoresNonStringHostWithShortHost {
  NSString *shortHost = [NSString stringWithFormat:@"%@", kShortConfiguredHost];
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:shortHost isSecure:NO withNamespace:@"db"];
  id notAHost = @5;

  XCTAssertNoThrow(info.internalHost = notAHost);

  XCTAssertEqualObjects(info.internalHost, kShortConfiguredHost);
  XCTAssertNil([[GULUserDefaults standardUserDefaults] objectForKey:kShortHostKey]);
}

- (void)testClearInternalHostCacheRestoresConfiguredHost {
  FRepoInfo *info = [self repoInfo];
  info.internalHost = kServerHost;

  [info clearInternalHostCache];

  XCTAssertEqualObjects(info.internalHost, kConfiguredHost);
  XCTAssertNil([self savedHost]);
}

// The configured host comes from the app, so it's restored even if it isn't a
// valid server host.
- (void)testClearInternalHostCacheRestoresIPv6ConfiguredHost {
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:kIPv6ConfiguredHost
                                           isSecure:NO
                                      withNamespace:@"repo-info-test"];
  XCTAssertEqualObjects(info.internalHost, kIPv6ConfiguredHost);
  info.internalHost = @"localhost:9000";

  [info clearInternalHostCache];

  XCTAssertEqualObjects(info.internalHost, kIPv6ConfiguredHost);
  XCTAssertNil([[GULUserDefaults standardUserDefaults] objectForKey:kIPv6HostKey]);
}

@end
