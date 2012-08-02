//
//  CCRemoteFeedLoadOperation.m
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

#import "CCRemoteFeedLoadOperation.h"
#import "CCRemoteFeedLoaderQueue.h"

@implementation CCRemoteFeedLoadOperation

@synthesize targetURL;


- (id)initWithURL:(NSURL *)url {
    if(self = [super init]) {
        self.targetURL = url;
    }
    return self;
}

- (void)start {
    currentlyExecuting = YES;
    
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:self.targetURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    feedConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (feedConnection != nil) {
        do {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        } while (!currentlyFinished);
    }
    else {
#warning NEED TO GENERALIZE ERROR STRING HERE
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"No Connection Error" forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"URLRequest" code:0 userInfo:userInfo];
        [self broadcastFailureWithError:error];
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
        feedData = [NSMutableData data];
    } else {
#warning NEED TO GENERALIZE ERROR STRING HERE
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"HTTP Response was bad" forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:@"HTTP" code:[httpResponse statusCode] userInfo:userInfo];
        
        NSLog(@"Http error: %@", error);
        
        [self broadcastFailureWithError:error];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [feedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"connection failed with error: %@", [error localizedDescription]);
    currentlyExecuting = NO;
    currentlyFinished = YES;
    
    [self broadcastFailureWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self broadcastFeedData];
}

- (void)broadcastFeedData {
    [CCRemoteFeedLoaderQueue broadcastFeedData:feedData forURL:self.targetURL loadedRemotely:YES];
    currentlyExecuting = NO;
    currentlyFinished = YES;
}
- (void)broadcastFailureWithError:(NSError *)error {
    [CCRemoteFeedLoaderQueue broadcastFailureForURL:self.targetURL error:error];
    currentlyExecuting = NO;
    currentlyFinished = YES;
}

@end
