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

#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"

@interface FRepoInfo ()

@property(nonatomic, strong) NSString *domain;

@end

@implementation FRepoInfo

- (instancetype)initWithHost:(NSString *)aHost
                    isSecure:(BOOL)isSecure
               withNamespace:(NSString *)aNamespace
              underlyingHost:(NSString *)underlyingHost {
    self = [super init];
    if (self) {
        _underlyingHost = [underlyingHost copy];
        _host = [aHost copy];
        _domain =
            [_host containsString:@"."]
                ? [_host
                      substringFromIndex:[host rangeOfString:@"."].location + 1]
                : _host;
        _secure = isSecure;
        _namespace = aNamespace;

        // Get cached internal host if it exists
        NSString *internalHostKey =
            [NSString stringWithFormat:@"firebase:host:%@", _host];
        NSString *cachedInternalHost = [[NSUserDefaults standardUserDefaults]
            stringForKey:internalHostKey];
        if (cachedInternalHost != nil) {
            _internalHost = cachedInternalHost;
        } else {
            _internalHost = self.host;
        }
    }
    return self;
}

- (instancetype)initWithHost:(NSString *)host
                    isSecure:(BOOL)secure
               withNamespace:(NSString *)namespace {
    return [self initWithHost:host
                     isSecure:secure
                withNamespace:namespace
               underlyingHost:nil];
}

- (instancetype)initWithInfo:(FRepoInfo *)info emulatedHost:(NSString *)host {
    return [self initWithHost:host
                     isSecure:info.secure
                withNamespace:info.namespace
               underlyingHost:info.host];
}

- (NSString *)description {
    // The namespace is encoded in the hostname, so we can just return this.
    return [NSString
        stringWithFormat:@"http%@://%@", (self.secure ? @"s" : @""), self.host];
}

- (void)setInternalHost:(NSString *)newHost {
    if (![self.internalHost isEqualToString:newHost]) {
        self.internalHost = [newHost copy];

        // Cache the internal host so we don't need to redirect later on
        NSString *internalHostKey =
            [NSString stringWithFormat:@"firebase:host:%@", self.host];
        NSUserDefaults *cache = [NSUserDefaults standardUserDefaults];
        [cache setObject:internalHost forKey:internalHostKey];
        [cache synchronize];
    }
}

- (void)clearInternalHostCache {
    self.internalHost = self.host;

    // Remove the cached entry
    NSString *internalHostKey =
        [NSString stringWithFormat:@"firebase:host:%@", self.host];
    NSUserDefaults *cache = [NSUserDefaults standardUserDefaults];
    [cache removeObjectForKey:internalHostKey];
    [cache synchronize];
}

- (BOOL)isCustomHost {
    NSString *host = self.underlyingHost ?: self.host;
    NSRange resultRange = [host rangeOfString:@".firebaseio.com"];
    if (resultRange.location == NSNotFound) {
        return NO;
    }
    return !(resultRange.length + resultRange.location == host.length);
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
    NSUInteger result = host.hash;
    result = 31 * result + (secure ? 1 : 0);
    result = 31 * result + namespace.hash;
    result = 31 * result + host.hash;
    return result;
}

- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[FRepoInfo class]]) {
        return NO;
    }
    FRepoInfo *other = (FRepoInfo *)anObject;
    return secure == other.secure && [self.host isEqualToString:other.host] &&
           [namespace isEqualToString:other.namespace];
}

@end
