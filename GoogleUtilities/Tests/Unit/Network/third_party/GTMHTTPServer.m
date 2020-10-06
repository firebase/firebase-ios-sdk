/* Copyright 2010 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  Based a little on HTTPServer, part of the CocoaHTTPServer sample code found at
//  https://opensource.apple.com/source/HTTPServer/HTTPServer-11/CocoaHTTPServer/
//  License for the CocoaHTTPServer sample code:
//
//  Software License Agreement (BSD License)
//
//  Copyright (c) 2011, Deusty, LLC
//  All rights reserved.
//
//  Redistribution and use of this software in source and binary forms,
//  with or without modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above
//  copyright notice, this list of conditions and the
//  following disclaimer.
//
//  * Neither the name of Deusty nor the names of its
//  contributors may be used to endorse or promote products
//  derived from this software without specific prior
//  written permission of Deusty, LLC.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>

#define GTMHTTPSERVER_DEFINE_GLOBALS
#import "GoogleUtilities/Tests/Unit/Network/third_party/GTMHTTPServer.h"

// avoid some of GTM's promiscuous dependencies
#ifndef _GTMDevLog
#define _GTMDevLog NSLog
#endif

#ifndef GTM_STATIC_CAST
#define GTM_STATIC_CAST(type, object) ((type *)(object))
#endif

#ifndef GTMCFAutorelease
#define GTMCFAutorelease(x) ([(id)x autorelease])
#endif

@interface GTMHTTPServer (PrivateMethods)
- (void)acceptedConnectionNotification:(NSNotification *)notification;
- (NSMutableDictionary *)connectionWithFileHandle:(NSFileHandle *)fileHandle;
- (void)dataAvailableNotification:(NSNotification *)notification;
- (NSMutableDictionary *)lookupConnection:(NSFileHandle *)fileHandle;
- (void)closeConnection:(NSMutableDictionary *)connDict;
- (void)sendResponseOnNewThread:(NSMutableDictionary *)connDict;
- (void)sentResponse:(NSMutableDictionary *)connDict;
@end

// keys for our connection dictionaries
static NSString *kFileHandle = @"FileHandle";
static NSString *kRequest = @"Request";
static NSString *kResponse = @"Response";

@interface GTMHTTPRequestMessage (PrivateHelpers)
- (BOOL)isHeaderComplete;
- (BOOL)appendData:(NSData *)data;
- (NSString *)headerFieldValueForKey:(NSString *)key;
- (UInt32)contentLength;
- (void)setBody:(NSData *)body;
@end

@interface GTMHTTPResponseMessage ()
- (id)initWithBody:(NSData *)body contentType:(NSString *)contentType statusCode:(int)statusCode;
- (NSData *)serializedData;
@end

@implementation GTMHTTPServer

- (id)init {
  return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id)delegate {
  self = [super init];
  if (self) {
    if (!delegate) {
      _GTMDevLog(@"missing delegate");
      [self release];
      return nil;
    }
    delegate_ = delegate;

#ifndef NS_BLOCK_ASSERTIONS
    BOOL isDelegateOK = [delegate_ respondsToSelector:@selector(httpServer:handleRequest:)];
    NSAssert(isDelegateOK, @"GTMHTTPServer delegate lacks handleRequest sel");
#endif

    localhostOnly_ = YES;
    connections_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self stop];
  [connections_ release];
  [super dealloc];
}

- (id)delegate {
  return delegate_;
}

- (uint16_t)port {
  return port_;
}

- (void)setPort:(uint16_t)port {
  port_ = port;
}

- (BOOL)reusePort {
  return reusePort_;
}

- (void)setReusePort:(BOOL)yesno {
  reusePort_ = yesno;
}

- (BOOL)localhostOnly {
  return localhostOnly_;
}

- (void)setLocalhostOnly:(BOOL)yesno {
  localhostOnly_ = yesno;
}

- (BOOL)start:(NSError **)error {
  NSAssert(listenHandle_ == nil, @"start called when we already have a listenHandle_");

  if (error) *error = NULL;

  NSInteger startFailureCode = 0;
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd <= 0) {
    // COV_NF_START - we'd need to use up *all* sockets to test this?
    startFailureCode = kGTMHTTPServerSocketCreateFailedError;
    goto startFailed;
    // COV_NF_END
  }

  // enable address reuse quicker after we are done w/ our socket
  int yes = 1;
  int sock_opt = reusePort_ ? SO_REUSEPORT : SO_REUSEADDR;
  if (setsockopt(fd, SOL_SOCKET, sock_opt, (void *)&yes, (socklen_t)sizeof(yes)) != 0) {
    _GTMDevLog(@"failed to mark the socket as reusable");  // COV_NF_LINE
  }

  // bind
  struct sockaddr_in addr;
  bzero(&addr, sizeof(addr));
  addr.sin_len = sizeof(addr);
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port_);
  if (localhostOnly_) {
    addr.sin_addr.s_addr = htonl(0x7F000001);
  } else {
    // COV_NF_START - testing this could cause a leopard firewall prompt during tests.
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    // COV_NF_END
  }
  if (bind(fd, (struct sockaddr *)(&addr), (socklen_t)sizeof(addr)) != 0) {
    startFailureCode = kGTMHTTPServerBindFailedError;
    goto startFailed;
  }

  // collect the port back out
  if (port_ == 0) {
    socklen_t len = (socklen_t)sizeof(addr);
    if (getsockname(fd, (struct sockaddr *)(&addr), &len) == 0) {
      port_ = ntohs(addr.sin_port);
    }
  }

  // tell it to listen for connections
  if (listen(fd, 5) != 0) {
    // COV_NF_START
    startFailureCode = kGTMHTTPServerListenFailedError;
    goto startFailed;
    // COV_NF_END
  }

  // now use a filehandle to accept connections
  listenHandle_ = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
  if (listenHandle_ == nil) {
    // COV_NF_START - we'd need to run out of memory to test this?
    startFailureCode = kGTMHTTPServerHandleCreateFailedError;
    goto startFailed;
    // COV_NF_END
  }

  // setup notifications for connects
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self
             selector:@selector(acceptedConnectionNotification:)
                 name:NSFileHandleConnectionAcceptedNotification
               object:listenHandle_];
  [listenHandle_ acceptConnectionInBackgroundAndNotify];

  // TODO: maybe hit the delegate incase it wants to register w/ NSNetService,
  // or just know we're up and running?

  return YES;

startFailed:
  if (error) {
    *error = [[[NSError alloc] initWithDomain:kGTMHTTPServerErrorDomain
                                         code:startFailureCode
                                     userInfo:nil] autorelease];
  }
  if (fd > 0) {
    close(fd);
  }
  return NO;
}

- (void)stop {
  if (listenHandle_) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self
                      name:NSFileHandleConnectionAcceptedNotification
                    object:listenHandle_];
    [listenHandle_ release];
    listenHandle_ = nil;
    // TODO: maybe hit the delegate in case it wants to unregister w/
    // NSNetService, or just know we've stopped running?
  }
  [connections_ removeAllObjects];
}

- (NSUInteger)activeRequestCount {
  return [connections_ count];
}

- (NSString *)description {
  NSString *result =
      [NSString stringWithFormat:@"%@<%p>{ port=%d localHostOnly=%@ status=%@ }", [self class],
                                 self, port_, (localhostOnly_ ? @"YES" : @"NO"),
                                 (listenHandle_ != nil ? @"Started" : @"Stopped")];
  return result;
}

@end

@implementation GTMHTTPServer (PrivateMethods)

- (void)acceptedConnectionNotification:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  NSFileHandle *newConnection = [userInfo objectForKey:NSFileHandleNotificationFileHandleItem];
  NSAssert1(newConnection != nil, @"failed to get the connection in the notification: %@",
            notification);

  // make sure we accept more...
  [listenHandle_ acceptConnectionInBackgroundAndNotify];

  // TODO: could let the delegate look at the address, before we start working
  // on it.

  NSMutableDictionary *connDict = [self connectionWithFileHandle:newConnection];
  [connections_ addObject:connDict];
}

- (NSMutableDictionary *)connectionWithFileHandle:(NSFileHandle *)fileHandle {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];

  [result setObject:fileHandle forKey:kFileHandle];

  GTMHTTPRequestMessage *request = [[[GTMHTTPRequestMessage alloc] init] autorelease];
  [result setObject:request forKey:kRequest];

  // setup for data notifications
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self
             selector:@selector(dataAvailableNotification:)
                 name:NSFileHandleReadCompletionNotification
               object:fileHandle];
  [fileHandle readInBackgroundAndNotify];

  return result;
}

- (void)dataAvailableNotification:(NSNotification *)notification {
  NSFileHandle *connectionHandle = GTM_STATIC_CAST(NSFileHandle, [notification object]);
  NSMutableDictionary *connDict = [self lookupConnection:connectionHandle];
  if (connDict == nil) return;  // we are no longer tracking this one

  NSDictionary *userInfo = [notification userInfo];
  NSData *readData = [userInfo objectForKey:NSFileHandleNotificationDataItem];
  if ([readData length] == 0) {
    // remote side closed
    [self closeConnection:connDict];
    return;
  }

  // Use a local pool to keep memory down incase the runloop we're in doesn't
  // drain until it gets a UI event.
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  @try {
    // Like Apple's sample, we just keep adding data until we get a full header
    // and any referenced body.

    GTMHTTPRequestMessage *request = [connDict objectForKey:kRequest];
    [request appendData:readData];

    // Is the header complete yet?
    if (![request isHeaderComplete]) {
      // more data...
      [connectionHandle readInBackgroundAndNotify];
    } else {
      // Do we have all the body?
      UInt32 contentLength = [request contentLength];
      NSData *body = [request body];
      NSUInteger bodyLength = [body length];
      if (contentLength > bodyLength) {
        // need more data...
        [connectionHandle readInBackgroundAndNotify];
      } else {
        if (contentLength < bodyLength) {
          // We got extra (probably someone trying to pipeline on us), trim
          // and let the extra data go...
          NSData *newBody = [NSData dataWithBytes:[body bytes] length:contentLength];
          [request setBody:newBody];
          _GTMDevLog(@"Got %lu extra bytes on http request, ignoring them",
                     (unsigned long)(bodyLength - contentLength));
        }

        GTMHTTPResponseMessage *response = nil;
        @try {
          // Off to the delegate
          response = [delegate_ httpServer:self handleRequest:request];
        } @catch (NSException *e) {
          _GTMDevLog(@"Exception trying to handle http request: %@", e);
        }  // COV_NF_LINE - radar 5851992 only reachable w/ an uncaught exception which isn't
           // testable

        if (response) {
          // We don't support connection reuse, so we add (force) the header to
          // close every connection.
          [response setValue:@"close" forHeaderField:@"Connection"];

          // spawn thread to send reply (since we do a blocking send)
          [connDict setObject:response forKey:kResponse];
          [NSThread detachNewThreadSelector:@selector(sendResponseOnNewThread:)
                                   toTarget:self
                                 withObject:connDict];
        } else {
          // No response, shut it down
          [self closeConnection:connDict];
        }
      }
    }
  } @catch (NSException *e) {  // COV_NF_START
    _GTMDevLog(@"exception while read data: %@", e);
    // exception while dealing with the connection, close it
  }  // COV_NF_END
  @finally {
    [pool drain];
  }
}

- (NSMutableDictionary *)lookupConnection:(NSFileHandle *)fileHandle {
  NSMutableDictionary *result = nil;
  for (NSMutableDictionary *connDict in connections_) {
    if (fileHandle == [connDict objectForKey:kFileHandle]) {
      result = connDict;
      break;
    }
  }
  return result;
}

- (void)closeConnection:(NSMutableDictionary *)connDict {
  // remove the notification
  NSFileHandle *connectionHandle = [connDict objectForKey:kFileHandle];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self name:NSFileHandleReadCompletionNotification object:connectionHandle];
  // in a non GC world, we're fine just letting the connect get closed when
  // the object is release when it comes out of connections_, but in a GC world
  // it won't get cleaned up
  [connectionHandle closeFile];

  // remove it from the list
  [connections_ removeObject:connDict];
}

- (void)sendResponseOnNewThread:(NSMutableDictionary *)connDict {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  @try {
    GTMHTTPResponseMessage *response = [connDict objectForKey:kResponse];
    NSFileHandle *connectionHandle = [connDict objectForKey:kFileHandle];
    NSData *serialized = [response serializedData];
    [connectionHandle writeData:serialized];
  } @catch (NSException *e) {  // COV_NF_START - causing an exception here is to hard in a test
    // TODO: let the delegate know about the exception (but do it on the main
    // thread)
    _GTMDevLog(@"exception while sending reply: %@", e);
  }  // COV_NF_END

  // back to the main thread to close things down
  [self performSelectorOnMainThread:@selector(sentResponse:) withObject:connDict waitUntilDone:NO];

  [pool release];
}

- (void)sentResponse:(NSMutableDictionary *)connDict {
  // make sure we're still tracking this connection (in case server was stopped)
  NSFileHandle *connection = [connDict objectForKey:kFileHandle];
  NSMutableDictionary *connDict2 = [self lookupConnection:connection];
  if (connDict != connDict2) return;

  // TODO: message the delegate that it was sent

  // close it down
  [self closeConnection:connDict];
}

@end

#pragma mark -

@implementation GTMHTTPRequestMessage

- (id)init {
  self = [super init];
  if (self) {
    message_ = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, YES);
  }
  return self;
}

- (void)dealloc {
  if (message_) {
    CFRelease(message_);
  }
  [super dealloc];
}

- (NSString *)version {
  return GTMCFAutorelease(CFHTTPMessageCopyVersion(message_));
}

- (NSURL *)URL {
  return GTMCFAutorelease(CFHTTPMessageCopyRequestURL(message_));
}

- (NSString *)method {
  return GTMCFAutorelease(CFHTTPMessageCopyRequestMethod(message_));
}

- (NSData *)body {
  return GTMCFAutorelease(CFHTTPMessageCopyBody(message_));
}

- (NSDictionary *)allHeaderFieldValues {
  return GTMCFAutorelease(CFHTTPMessageCopyAllHeaderFields(message_));
}

- (NSString *)description {
  CFStringRef desc = CFCopyDescription(message_);
  NSString *result = [NSString stringWithFormat:@"%@<%p>{ message=%@ }", [self class], self, desc];
  CFRelease(desc);
  return result;
}

@end

@implementation GTMHTTPRequestMessage (PrivateHelpers)

- (BOOL)isHeaderComplete {
  return CFHTTPMessageIsHeaderComplete(message_) ? YES : NO;
}

- (BOOL)appendData:(NSData *)data {
  return CFHTTPMessageAppendBytes(message_, [data bytes], (CFIndex)[data length]) ? YES : NO;
}

- (NSString *)headerFieldValueForKey:(NSString *)key {
  CFStringRef value = NULL;
  if (key) {
    value = CFHTTPMessageCopyHeaderFieldValue(message_, (CFStringRef)key);
  }
  return GTMCFAutorelease(value);
}

- (UInt32)contentLength {
  return (UInt32)[[self headerFieldValueForKey:@"Content-Length"] intValue];
}

- (void)setBody:(NSData *)body {
  if (!body) {
    body = [NSData data];  // COV_NF_LINE - can only happen in we fail to make the new data object
  }
  CFHTTPMessageSetBody(message_, (CFDataRef)body);
}

@end

#pragma mark -

@implementation GTMHTTPResponseMessage

- (id)init {
  return [self initWithBody:nil contentType:nil statusCode:0];
}

- (id)initWithBody:(NSData *)body contentType:(NSString *)contentType statusCode:(int)statusCode {
  self = [super init];
  if (self) {
    if ((statusCode < 100) || (statusCode > 599)) {
      [self release];
      return nil;
    }
    message_ =
        CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, NULL, kCFHTTPVersion1_0);
    if (!message_) {
      // COV_NF_START
      [self release];
      return nil;
      // COV_NF_END
    }
    NSUInteger bodyLength = 0;
    if (body) {
      bodyLength = [body length];
      CFHTTPMessageSetBody(message_, (CFDataRef)body);
    }
    if ([contentType length] == 0) {
      contentType = @"text/html";
    }
    NSString *bodyLenStr = [NSString stringWithFormat:@"%lu", (unsigned long)bodyLength];
    [self setValue:bodyLenStr forHeaderField:@"Content-Length"];
    [self setValue:contentType forHeaderField:@"Content-Type"];
  }
  return self;
}

- (void)dealloc {
  if (message_) {
    CFRelease(message_);
  }
  [super dealloc];
}

+ (instancetype)responseWithString:(NSString *)plainText {
  NSData *body = [plainText dataUsingEncoding:NSUTF8StringEncoding];
  return [self responseWithBody:body contentType:@"text/plain; charset=UTF-8" statusCode:200];
}

+ (instancetype)responseWithHTMLString:(NSString *)htmlString {
  return [self responseWithBody:[htmlString dataUsingEncoding:NSUTF8StringEncoding]
                    contentType:@"text/html; charset=UTF-8"
                     statusCode:200];
}

+ (instancetype)responseWithBody:(NSData *)body
                     contentType:(NSString *)contentType
                      statusCode:(int)statusCode {
  return [[[[self class] alloc] initWithBody:body contentType:contentType statusCode:statusCode]
      autorelease];
}

+ (instancetype)emptyResponseWithCode:(int)statusCode {
  return
      [[[[self class] alloc] initWithBody:nil contentType:nil statusCode:statusCode] autorelease];
}

- (void)setValue:(NSString *)value forHeaderField:(NSString *)headerField {
  if ([headerField length] == 0) return;
  if (value == nil) {
    value = @"";
  }
  CFHTTPMessageSetHeaderFieldValue(message_, (CFStringRef)headerField, (CFStringRef)value);
}

- (void)setHeaderValuesFromDictionary:(NSDictionary *)dict {
  for (id key in dict) {
    id value = [dict valueForKey:key];
    [self setValue:value forHeaderField:key];
  }
}

- (NSString *)description {
  CFStringRef desc = CFCopyDescription(message_);
  NSString *result = [NSString stringWithFormat:@"%@<%p>{ message=%@ }", [self class], self, desc];
  CFRelease(desc);
  return result;
}

- (NSData *)serializedData {
  return GTMCFAutorelease(CFHTTPMessageCopySerializedMessage(message_));
}

@end
