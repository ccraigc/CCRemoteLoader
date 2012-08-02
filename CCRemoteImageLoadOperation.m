//
//  CCRemoteImageLoadOperation.m
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

#import "CCRemoteImageLoadOperation.h"
#import "CCRemoteImageLoaderQueue.h"

@implementation CCRemoteImageLoadOperation

@synthesize targetURL, collectionName;

- (id)initWithURL:(NSURL *)url collectionName:(NSString *)collection {
    if(self = [super init]) {
        self.targetURL = url;
        self.collectionName = collection;
    }
    return self;
}

- (void)start {
    currentlyExecuting = YES;

    NSURLRequest *theRequest = [NSURLRequest requestWithURL:self.targetURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    imageConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (imageConnection != nil) {
        do {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        } while (!currentlyFinished);
    }
}

- (BOOL)isConcurrent {
    return NO;
}

- (BOOL)isExecuting {
    return currentlyExecuting;
}

- (BOOL)isFinished {
    return currentlyFinished;
}


#pragma mark -
#pragma mark NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ((([httpResponse statusCode]/100) == 2)) {
        imageData = [NSMutableData data];
    } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:
                                  NSLocalizedString(@"HTTP Error",
                                                    @"Error message displayed when receving a connection error.")
                                                             forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"HTTP" code:[httpResponse statusCode] userInfo:userInfo];

        NSLog(@"Http error: %@", error);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [imageData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    currentlyExecuting = NO;
    currentlyFinished = YES;
    
    [self broadcastFailureWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self broadcastImageData];
}

- (void)broadcastImageData {
    UIImage *loadedImage = [UIImage imageWithData:imageData];
    if(loadedImage) {
        [CCRemoteImageLoaderQueue broadcastImage:loadedImage forURL:self.targetURL collectionName:self.collectionName loadedRemotely:YES];
        currentlyExecuting = NO;
        currentlyFinished = YES;
    }
    else {
#warning GENERALIZE ERROR MESSAGE HERE
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Bad Image Data" forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:userInfo];
        [self broadcastFailureWithError:error];
    }
}
- (void)broadcastFailureWithError:(NSError *)error {
    [CCRemoteImageLoaderQueue broadcastFailureForURL:self.targetURL error:error];
    currentlyExecuting = NO;
    currentlyFinished = YES;
}

@end
