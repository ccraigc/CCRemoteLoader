//
//  CCRemoteImageLoaderQueue.m
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

#import "CCRemoteImageLoaderQueue.h"
#import "CCRemoteImageLoadOperation.h"

#define CCRemoteDefaultImageExpirationSeconds 7200
#define CCRemoteImageNotificationPrefix @"CCRemoteImage"

static CCRemoteImageLoaderQueue *__instance;

@implementation CCRemoteImageLoaderQueue
@synthesize tempCollections, queuedURLs;

+ (CCRemoteImageLoaderQueue *)currentQueue {
	@synchronized(self) {
		if(!__instance) {
			__instance = [[CCRemoteImageLoaderQueue alloc] init];
		}
	}
	
	return __instance;
}

- (id)init {
	if((self = [super init])) {
        fileCache = [EGOCache currentCache];
        
		loaderOperationQueue = [[NSOperationQueue alloc] init];
        
        self.queuedURLs = [[NSMutableArray alloc] init];
        
        self.tempCollections = [[NSMutableDictionary alloc] init];
        
        isReachable = NO;
	}
	
	return self;
}

- (UIImage *)requestImageAtURLString:(NSString *)urlString {
    return [self requestImageAtURLString:urlString forCollection:nil];
}

- (UIImage *)requestImageAtURLString:(NSString *)urlString forCollection:(NSString *)collectionName {
    // check the file cache for the object
    NSString *cacheKey = [CCRemoteImageLoaderQueue getSafeCacheKeyFromURLString:urlString];
    NSDictionary *imageDict = [self.tempCollections objectForKey:cacheKey];
    if(imageDict) {
        UIImage *memoryImage = [imageDict objectForKey:@"image"];
        if(memoryImage) {
            return memoryImage;
        }
    }
    // if the image was in memory, it has been returned.
    
    if([fileCache hasCacheForKey:cacheKey]) {
        UIImage *theImage = [fileCache imageForKey:cacheKey];
        [CCRemoteImageLoaderQueue broadcastImage:theImage forURL:[NSURL URLWithString:urlString] collectionName:collectionName];
        return theImage;
    }
    
    if(!isReachable) {
        isReachable = [self reachable];
    }
    
    if(isReachable) {

        if([self.queuedURLs containsObject:urlString] == NO) {
            CCRemoteImageLoadOperation *newOperation = [[CCRemoteImageLoadOperation alloc] initWithURL:[NSURL URLWithString:urlString] collectionName:collectionName];
            [loaderOperationQueue addOperation:newOperation];
            [self.queuedURLs addObject:urlString];
        }
    }
    return nil;
}


- (void)cacheNewImage:(UIImage *)theImage forURLString:(NSString *)urlString inCollection:(NSString *)collectionName {
    
    if(collectionName) {
        [self addImage:theImage toCollection:collectionName forKey:[CCRemoteImageLoaderQueue getSafeCacheKeyFromURLString:urlString]];
    }
    
    [fileCache setImage:theImage forKey:[CCRemoteImageLoaderQueue getSafeCacheKeyFromURLString:urlString] withTimeoutInterval:CCRemoteDefaultImageExpirationSeconds];
    [self.queuedURLs removeObject:urlString];
}

- (void)handleImageFailureWithURLString:(NSString *)urlString error:(NSError *)error {
    [self.queuedURLs removeObject:urlString];
    isReachable = NO;
}


+ (NSString *)getSafeCacheKeyFromURLString:(NSString *)urlString {
    NSString *newString = [[NSString alloc] initWithString:urlString];
    return [newString stringByReplacingOccurrencesOfString:@"/" withString:@"__"];
}

// a shortcut if you don't want to make a NSURL.
+ (void)broadcastImage:(UIImage *)readyImage forURLString:(NSString *)theURLString {
    [CCRemoteImageLoaderQueue broadcastImage:readyImage forURL:[NSURL URLWithString:theURLString] collectionName:nil];
}


+ (void)broadcastImage:(UIImage *)readyImage forURL:(NSURL *)theURL collectionName:(NSString *)collectionName {
    [CCRemoteImageLoaderQueue broadcastImage:readyImage forURL:theURL collectionName:collectionName loadedRemotely:NO];
}

+ (void)broadcastImage:(UIImage *)readyImage forURL:(NSURL *)theURL collectionName:(NSString *)collectionName loadedRemotely:(BOOL)loadedRemotely {
    NSString *urlString = [theURL absoluteString];
    
    NSMutableDictionary *imageDict = [[NSMutableDictionary alloc] init];
    [imageDict setValue:readyImage forKey:@"image"];
    [imageDict setValue:theURL forKey:@"url"];
    
    if(collectionName) [imageDict setObject:collectionName forKey:@"collection"];
    [[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@%@", CCRemoteImageNotificationPrefix, urlString] object:imageDict];
    
    if(loadedRemotely)
        [[CCRemoteImageLoaderQueue currentQueue] cacheNewImage:readyImage forURLString:urlString inCollection:collectionName];
}

+ (void)broadcastFailureForURL:(NSURL *)theURL error:(NSError *)error {
    NSString *urlString = [theURL absoluteString];
    NSDictionary *imageDict = [NSDictionary dictionaryWithObjectsAndKeys:theURL, @"url", error, @"error", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:[NSString stringWithFormat:@"%@Failed%@", CCRemoteImageNotificationPrefix, urlString] object:imageDict];
    
    CCRemoteImageLoaderQueue *me = [CCRemoteImageLoaderQueue currentQueue];
    [me resetReachability];
    [me handleImageFailureWithURLString:urlString error:error];
}

- (void)prefetchImagesAtURLs:(NSArray *)urlArray withCollectionName:(NSString *)collectionName {
    for (NSString *urlString in urlArray) {
        [self prefetchImageAtURL:urlString withCollectionName:collectionName];
    }
}
- (void)prefetchImageAtURL:(NSString *)urlString withCollectionName:(NSString *)collectionName {
    NSString *cacheSafeKey = [CCRemoteImageLoaderQueue getSafeCacheKeyFromURLString:urlString];
    if([self.tempCollections objectForKey:cacheSafeKey] == nil) {
        UIImage *result = [self requestImageAtURLString:urlString forCollection:collectionName];
        NSDictionary *imageInfo;
        if(result) {
            imageInfo = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:result, collectionName, nil] forKeys:[NSArray arrayWithObjects:@"image", @"collection", nil]];
        }
        else {
            imageInfo = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:collectionName, nil] forKeys:[NSArray arrayWithObjects:@"collection", nil]];
        }
        [self.tempCollections setObject:imageInfo forKey:cacheSafeKey];
    }
}

- (void)addImage:(UIImage *)theImage toCollection:(NSString *)collectionName forKey:(NSString *)cacheKey {
    if(theImage) {
        NSDictionary *imageInfo = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:theImage, collectionName, nil] forKeys:[NSArray arrayWithObjects:@"image", @"collection", nil]];
        [self.tempCollections setObject:imageInfo forKey:cacheKey];
    }
}

- (void)dumpCollection:(NSString *)collectionName {
    
    NSMutableArray *removalKeys = [[NSMutableArray alloc] init];

    for (NSString *itemKey in self.tempCollections) {
        NSDictionary *item = [self.tempCollections objectForKey:itemKey];
        
        if([[item objectForKey:@"collection"] isEqualToString:collectionName]) {
            [removalKeys addObject:itemKey];
        }
    }
    for (NSString *key in removalKeys) {
        [self.tempCollections removeObjectForKey:key];
    }
}

- (void)resetReachability {
    isReachable = NO;
}

-(BOOL)reachable {
    Reachability *r = [Reachability reachabilityWithHostName:@"www.google.com"];
    NetworkStatus internetStatus = [r currentReachabilityStatus];
    if(internetStatus == NotReachable) {
        return NO;
    }
    return YES;
}

+ (void)stopObject:(id)object fromObservingFeedNotificationsForURL:(NSURL *)url {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:object name:[NSString stringWithFormat:@"%@%@", CCRemoteImageNotificationPrefix, [url absoluteString]] object:nil];
    [nc removeObserver:object name:[NSString stringWithFormat:@"%@Failed%@", CCRemoteImageNotificationPrefix, [url absoluteString]] object:nil];
}


@end