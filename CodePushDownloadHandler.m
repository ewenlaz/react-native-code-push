#import "CodePush.h"

@implementation CodePushDownloadHandler

- (id)init:(NSString *)downloadFilePath
progressCallback:(void (^)(long, long))progressCallback
doneCallback:(void (^)())doneCallback
failCallback:(void (^)(NSError *err))failCallback {
    self.outputFileStream = [NSOutputStream outputStreamToFileAtPath:downloadFilePath
                                                              append:NO];
    self.receivedContentLength = 0;
    self.progressCallback = progressCallback;
    self.doneCallback = doneCallback;
    self.failCallback = failCallback;
    return self;
}

-(void)download:(NSString*)url {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:60.0];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                  delegate:self
                                                          startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
                          forMode:NSDefaultRunLoopMode];
    [connection start];
}

#pragma mark NSURLConnection Delegate Methods

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    // Return nil to indicate not necessary to store a cached response for this connection
    return nil;
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.expectedContentLength = response.expectedContentLength;
    [self.outputFileStream open];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    self.receivedContentLength = self.receivedContentLength + [data length];
    
    NSInteger bytesLeft = [data length];
    
    do {
        NSInteger bytesWritten = [self.outputFileStream write:[data bytes]
                                                     maxLength:bytesLeft];
        if (bytesWritten == -1) {
            break;
        }
        
        bytesLeft -= bytesWritten;
    } while (bytesLeft > 0);
    
    self.progressCallback(self.expectedContentLength, self.receivedContentLength);
    
    // bytesLeft should not be negative.
    assert(bytesLeft >= 0);
    
    if (bytesLeft) {
        [self.outputFileStream close];
        [connection cancel];
        self.failCallback([self.outputFileStream streamError]);
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    [self.outputFileStream close];
    self.failCallback(error);
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // We should have received all of the bytes if this is called.
    assert(self.receivedContentLength == self.expectedContentLength);
    
    [self.outputFileStream close];
    self.doneCallback();
}

@end