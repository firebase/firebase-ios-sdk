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

#import <GoogleUtilities/GULUserDefaults.h>

#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@interface FRepoInfo ()

@property(nonatomic, strong) NSString *domain;

@end

@implementation FRepoInfo

@synthesize internalHost;

+ (BOOL)isValidHost:(id)host {
    if (![host isKindOfClass:[NSString class]]) {
        return NO;
    }
    // A host name or IPv4 address, with an optional port. IPv6 literals and
    // '_' are rejected. Use \z rather than $, which also matches before a
    // trailing newline.
    static NSRegularExpression *hostRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      hostRegex = [NSRegularExpression
          regularExpressionWithPattern:@"^[A-Za-z0-9.-]{1,253}(:[0-9]{1,5})?\\z"
                               options:0
                                 error:NULL];
    });
    NSString *hostString = host;
    if ([hostRegex
            numberOfMatchesInString:hostString
                            options:0
                              range:NSMakeRange(0, hostString.length)] == 0) {
        return NO;
    }
    // Defense in depth: NSURL must accept the host too. This parses only
    // wss://<host>/, and no host that matches the regex is known to fail it,
    // with either the old NSURL parser or the one in iOS 17 and later.
    NSURL *url = [NSURL
        URLWithString:[NSString stringWithFormat:@"wss://%@/", hostString]];
    return url.host.length > 0;
}

- (instancetype)init {
    [NSException
         raise:@"FIRDatabaseInvalidInitializer"
        format:@"Invalid initializer invoked. This is probably a bug in RTDB."];
    abort();
}

- (instancetype)initWithHost:(NSString *)aHost
                    isSecure:(BOOL)isSecure
               withNamespace:(NSString *)aNamespace {
    self = [super init];
    if (self) {
        _host = [aHost copy];
        _domain =
            [_host containsString:@"."]
                ? [_host
                      substringFromIndex:[_host rangeOfString:@"."].location +
                                         1]
                : _host;
        _secure = isSecure;
        _namespace = aNamespace;

        // Get cached internal host if it exists
        NSString *internalHostKey =
            [NSString stringWithFormat:@"firebase:host:%@", _host];
        NSString *cachedInternalHost = [[GULUserDefaults standardUserDefaults]
            stringForKey:internalHostKey];
        if (cachedInternalHost != nil &&
            ![FRepoInfo isValidHost:cachedInternalHost]) {
            // Earlier versions saved any host that the server sent, and a host
            // that can't be used in a URL crashed the app at every launch.
            FFWarn(@"I-RDB039001", @"Ignoring invalid saved database host: %@",
                   cachedInternalHost);
            [[GULUserDefaults standardUserDefaults]
                removeObjectForKey:internalHostKey];
            cachedInternalHost = nil;
        }
        if (cachedInternalHost != nil) {
            internalHost = cachedInternalHost;
        } else {
            internalHost = [_host copy];
        }
    }
    return self;
}

- (instancetype)initWithInfo:(FRepoInfo *)info emulatedHost:(NSString *)host {
    self = [self initWithHost:host isSecure:NO withNamespace:info.namespace];
    return self;
}

- (NSString *)description {
    // The namespace is encoded in the hostname, so we can just return this.
    return [NSString
        stringWithFormat:@"http%@://%@", (_secure ? @"s" : @""), _host];
}

- (void)setInternalHost:(NSString *)newHost {
    // A handshake might not include a host. Keep the current one, without a
    // warning.
    if (newHost == nil) {
        return;
    }
    // An unchanged host is a no-op. Check that it's a string first, since
    // -isEqualToString: can throw for an argument that isn't a string.
    if ([newHost isKindOfClass:[NSString class]] &&
        [internalHost isEqualToString:newHost]) {
        return;
    }
    // The host comes from the server and is saved across launches, so ignore
    // a host that can't be used in a URL.
    if (![FRepoInfo isValidHost:newHost]) {
        FFWarn(@"I-RDB039002", @"Ignoring invalid database host: %@", newHost);
        return;
    }
    internalHost = [newHost copy];

    // Cache the internal host so we don't need to redirect later on
    NSString *internalHostKey =
        [NSString stringWithFormat:@"firebase:host:%@", self.host];
    GULUserDefaults *cache = [GULUserDefaults standardUserDefaults];
    [cache setObject:internalHost forKey:internalHostKey];
}

- (void)clearInternalHostCache {
    // Assign the ivar rather than use the setter: the configured host must
    // always be accepted, even if it doesn't pass +isValidHost: (e.g. an IPv6
    // emulator host).
    internalHost = self.host;

    // Remove the cached entry
    NSString *internalHostKey =
        [NSString stringWithFormat:@"firebase:host:%@", self.host];
    GULUserDefaults *cache = [GULUserDefaults standardUserDefaults];
    [cache removeObjectForKey:internalHostKey];
}

- (BOOL)isDemoHost {
    return [self.domain isEqualToString:@"firebaseio-demo.com"];
}

- (BOOL)isCustomHost {
    return ![self.domain isEqualToString:@"firebaseio-demo.com"] &&
           ![self.domain isEqualToString:@"firebaseio.com"];
}

- (NSString *)connectionURL {
    return [self connectionURLWithLastSessionID:nil];
}

- (NSString *)connectionURLWithLastSessionID:(NSString *)lastSessionID {
    NSString *scheme;
    if (self.secure) {
        scheme = @"wss";
    } else {
        scheme = @"ws";
    }
    NSString *url =
        [NSString stringWithFormat:@"%@://%@/.ws?%@=%@&ns=%@", scheme,
                                   self.internalHost, kWireProtocolVersionParam,
                                   kWebsocketProtocolVersion, self.namespace];

    if (lastSessionID != nil) {
        url = [NSString stringWithFormat:@"%@&ls=%@", url, lastSessionID];
    }
    return url;
}

- (id)copyWithZone:(NSZone *)zone {
    return self; // Immutable
}

- (NSUInteger)hash {
    NSUInteger result = _host.hash;
    result = 31 * result + (_secure ? 1 : 0);
    result = 31 * result + _namespace.hash;
    result = 31 * result + _host.hash;
    return result;
}

- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[FRepoInfo class]]) {
        return NO;
    }
    FRepoInfo *other = (FRepoInfo *)anObject;
    return _secure == other.secure && [_host isEqualToString:other.host] &&
           [_namespace isEqualToString:other.namespace];
}

@end
