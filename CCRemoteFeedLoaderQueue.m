//
//  CCRemoteFeedLoaderQueue.m
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

#import "CCRemoteFeedLoaderQueue.h"
#import "CCRemoteFeedLoadOperation.h"

#define CCRemoteDefaultFeedExpirationSeconds 7200
#define CCRemoteNotificationPrefix @"CCRemote"

static CCRemoteFeedLoaderQueue *__instance;

@implementation CCRemoteFeedLoaderQueue

@synthesize queuedURLs, queuedTimeouts;

+ (CCRemoteFeedLoaderQueue *)currentQueue {
	@synchronized(self) {
		if(!__instance) {
			__instance = [[CCRemoteFeedLoaderQueue alloc] init];
		}
	}
	
	return __instance;
}

- (id)init {
	if((self = [super init])) {
        fileCache = [EGOCache currentCache];
        
		loaderOperationQueue = [[NSOperationQueue alloc] init];
        
        self.queuedURLs = [[NSMutableArray alloc] init];
        self.queuedTimeouts = [[NSMutableDictionary alloc] init];
        
        isReachable = NO;
	}
	
	return self;
}

- (NSData *)requestFeedAtURLString:(NSString *)urlString {
    return [self requestFeedAtURLString:urlString withTimeout:CCRemoteDefaultFeedExpirationSeconds];
}

- (NSData *)requestFeedAtURLString:(NSString *)urlString withTimeout:(NSTimeInterval)expires {
    return [self requestFeedAtURLString:urlString withTimeout:expires forceRemote:NO];
}

- (NSData *)requestFeedAtURLString:(NSString *)urlString withTimeout:(NSTimeInterval)expires forceRemote:(BOOL)forceRemote {
    NSLog(@"requesting url: %@", urlString);
    
    // check the file cache for the object
    NSString *cacheKey = [CCRemoteFeedLoaderQueue getSafeCacheKeyFromURLString:urlString];
    
    if(!forceRemote && [fileCache hasCacheForKey:cacheKey]) {
        NSData *theFeedData = [fileCache dataForKey:cacheKey];
        [CCRemoteFeedLoaderQueue broadcastFeedData:theFeedData forURLString:urlString];
        return theFeedData;
    }
    
    if(!isReachable) {
        isReachable = [self reachable];
    }
    
    if(isReachable) {
        if([self.queuedURLs containsObject:urlString] == NO) {
            CCRemoteFeedLoadOperation *newOperation = [[CCRemoteFeedLoadOperation alloc] initWithURL:[NSURL URLWithString:urlString]];
            [loaderOperationQueue addOperation:newOperation];
            [self.queuedURLs addObject:urlString];
            [self.queuedTimeouts setObject:[NSNumber numberWithInt:expires] forKey:urlString];
        }
    }
    else if([fileCache hasCacheForKey:cacheKey]) {
        NSData *theFeedData = [fileCache dataForKey:cacheKey];
        [CCRemoteFeedLoaderQueue broadcastFeedData:theFeedData forURLString:urlString];
        return theFeedData;
    }
    else {
#warning NEED TO HANDLE ERROR IN PROJECT-AGNOSTIC WAY
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"No Connection Error String" forKey:NSLocalizedDescriptionKey];
        NSError *noConnectionError = [NSError errorWithDomain:NSCocoaErrorDomain code:kCFURLErrorNotConnectedToInternet userInfo:userInfo];
        [CCRemoteFeedLoaderQueue broadcastFailureForURLString:urlString error:noConnectionError];
    }
    return nil;
}

- (void)cacheFeedData:(NSData *)theData forURLString:(NSString *)urlString {
    // cache this info
    NSNumber *timeout = [self.queuedTimeouts objectForKey:urlString];
    if(timeout == nil) timeout = [NSNumber numberWithInt:CCRemoteDefaultFeedExpirationSeconds];
    
    [fileCache setData:theData forKey:[CCRemoteFeedLoaderQueue getSafeCacheKeyFromURLString:urlString] withTimeoutInterval:[timeout intValue]];
    [self.queuedURLs removeObject:urlString];
    [self.queuedTimeouts removeObjectForKey:urlString];
}

- (void)handleFeedFailureWithURLString:(NSString *)urlString error:(NSError *)error {
    [self.queuedURLs removeObject:urlString];
    [self.queuedTimeouts removeObjectForKey:urlString];
    [self resetReachability];
    
    [self displayError:error];
}


+ (NSString *)getSafeCacheKeyFromURLString:(NSString *)urlString {
    NSString *newString = [[NSString alloc] initWithString:urlString];
    return [newString stringByReplacingOccurrencesOfString:@"/" withString:@"__"];
}

+ (void)broadcastFeedData:(NSData *)feedData forURLString:(NSString *)theURLString {
    [CCRemoteFeedLoaderQueue broadcastFeedData:feedData forURL:[NSURL URLWithString:theURLString]];
}


+ (void)broadcastFeedData:(NSData *)feedData forURL:(NSURL *)theURL {
    [CCRemoteFeedLoaderQueue broadcastFeedData:feedData forURL:theURL loadedRemotely:NO];
}

+ (void)broadcastFeedData:(NSData *)feedData forURL:(NSURL *)theURL loadedRemotely:(BOOL)loadedRemotely {
    NSMutableDictionary *feedDict = [[NSMutableDictionary alloc] init];
    [feedDict setValue:feedData forKey:@"feedData"];
    [feedDict setValue:theURL forKey:@"url"];
    NSString *urlString = [theURL absoluteString];
    [[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@%@", CCRemoteNotificationPrefix, urlString] object:feedDict];
    
    // internal handling
    if(loadedRemotely)
        [[CCRemoteFeedLoaderQueue currentQueue] cacheFeedData:feedData forURLString:urlString];
}

+ (void)broadcastFailureForURLString:(NSString *)URLString error:(NSError *)error {
    [CCRemoteFeedLoaderQueue broadcastFailureForURL:[NSURL URLWithString:URLString] error:error];
}

+ (void)broadcastFailureForURL:(NSURL *)theURL error:(NSError *)error {

    NSDictionary *feedDict = [NSDictionary dictionaryWithObjectsAndKeys:theURL, @"url", error, @"error", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@Failed%@", CCRemoteNotificationPrefix, [theURL absoluteString]] object:feedDict];
    
    // internal handling
    CCRemoteFeedLoaderQueue *me = [CCRemoteFeedLoaderQueue currentQueue];
    [me handleFeedFailureWithURLString:[theURL absoluteString] error:error];
}

- (void)resetReachability {
    isReachable = NO;
}

-(BOOL)reachable {
    NSLog(@"feedloadop reachability check");
    /*Reachability *r = [Reachability reachabilityWithHostName:@"www.google.com"];
    NetworkStatus internetStatus = [r currentReachabilityStatus];
    if(internetStatus == NotReachable) {
        return NO;
    }
    else {
        return YES;
    }*/
}

+ (id)parseJSONData:(NSData *)theData {
    NSError *jsonError = nil;
    NSArray *jsonObject = [NSJSONSerialization JSONObjectWithData:theData options:0 error:&jsonError];
    
    if(jsonError) return nil;
    else return jsonObject;
}

+ (void)stopObject:(id)object fromObservingFeedNotificationsForURL:(NSURL *)url {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:object name:[NSString stringWithFormat:@"%@%@", CCRemoteNotificationPrefix, [url absoluteString]] object:nil];
    [nc removeObserver:object name:[NSString stringWithFormat:@"%@Failed%@", CCRemoteNotificationPrefix, [url absoluteString]] object:nil];
}

- (void)displayError:(NSError *)error {
    NSString *errorMessage = [error localizedDescription];

    UIAlertView *alertView =
    [[UIAlertView alloc] initWithTitle:@"Loading Error" message:errorMessage delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
    [alertView show];
}



@end