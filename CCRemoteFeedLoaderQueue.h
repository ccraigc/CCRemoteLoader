//
//  CCRemoteFeedLoaderQueue.h
//  ccraigc
//
//  Created by Craig Coffman on 7/2/12.
//  Copyright (c) 2012 ccraigc
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import "EGOCache.h"
#import "Reachability.h"

@interface CCRemoteFeedLoaderQueue : NSObject <NSURLConnectionDelegate> {
@private
    EGOCache *fileCache;
    NSOperationQueue *loaderOperationQueue;
    NSMutableArray *queuedURLs;
    NSMutableDictionary *queuedTimeouts;
    
    BOOL isReachable;
}

+ (CCRemoteFeedLoaderQueue*)currentQueue;

- (NSData *)requestFeedAtURLString:(NSString *)urlString;
- (NSData *)requestFeedAtURLString:(NSString *)urlString withTimeout:(NSTimeInterval)expires;
- (NSData *)requestFeedAtURLString:(NSString *)urlString withTimeout:(NSTimeInterval)expires forceRemote:(BOOL)forceRemote;

+ (void)broadcastFeedData:(NSData *)feedData forURLString:(NSString *)theURLString;
+ (void)broadcastFeedData:(NSData *)feedData forURL:(NSURL *)theURL;
+ (void)broadcastFeedData:(NSData *)feedData forURL:(NSURL *)theURL loadedRemotely:(BOOL)loadedRemotely;

+ (void)broadcastFailureForURLString:(NSString *)URLString error:(NSError *)error;
+ (void)broadcastFailureForURL:(NSURL *)theURL error:(NSError *)error;


+ (NSString *)getSafeCacheKeyFromURLString:(NSString *)urlString;

- (void)cacheFeedData:(NSData *)theData forURLString:(NSString *)urlString;
- (void)handleFeedFailureWithURLString:(NSString *)urlString error:(NSError *)error;

+ (id)parseJSONData:(NSData *)theData;
+ (void)stopObject:(id)object fromObservingFeedNotificationsForURL:(NSURL *)url;

- (void)resetReachability;

@property (retain) NSMutableArray *queuedURLs;
@property (retain) NSMutableDictionary *queuedTimeouts;

@end
