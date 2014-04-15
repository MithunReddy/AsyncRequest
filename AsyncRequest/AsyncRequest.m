//
//  AsynchronousRequest.m
//  CallCenterMobile
//
//  Created by Bruno Capezzali on 06/05/13.
//
//

#import "AsyncRequest.h"

// helper function: get the url encoded string form of any object
extern NSString *urlEncode(id object) {
    NSString *string = [NSString stringWithFormat:@"%@", object];
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL,
                                                                                 CFSTR("!*'\"();:@&=+$,/?%#[]% "), kCFStringEncodingUTF8));
}

@implementation AsyncRequest

@synthesize timeoutInterval = _timeoutInterval;
@synthesize completed = _completed;

+ (NSString *)encodedURL:(NSString *)page withParams:(NSDictionary *)params {
    if ( params && [params count] > 0 ) {
        // Generate the GET request with all the parameters
        NSMutableArray *parts = [NSMutableArray array];
        for (id key in params) {
            id value = [params objectForKey: key];
            NSString *part = [NSString stringWithFormat: @"%@=%@", urlEncode(key), urlEncode(value)];
            [parts addObject: part];
        }
        return [page stringByAppendingFormat:@"?%@", [parts componentsJoinedByString: @"&"]];
    }
    return page;
}

+ (id)requestWithURL:(NSString *)page
             params:(NSDictionary *)params
          onSuccess:(void (^)(NSData *data))success
           onErrror:(void (^)(NSError *error))error {
    
    return [[self alloc] initRequestWithURL:page params:params onSuccess:success onErrror:error];
}

- (id)initRequestWithURL:(NSString *)page
                 params:(NSDictionary *)params
              onSuccess:(void (^)(NSData *data))success
               onErrror:(void (^)(NSError *error))error {
    
    if ( (self = [super init]) ) {
        
        _successBlock = [success copy];
        _errorBlock = [error copy];
        _timeoutInterval = 0; // no timeout
        _requestURL = [AsyncRequest encodedURL:page withParams:params];
        _completed = NO;
    }
    
    return self;
}

- (void)start {
    // Create the GET request
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_requestURL]];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [request setHTTPMethod:@"GET"];
//    NSLog(@"Request GET:\n%@", _requestURL);
    
    // If we need to have a timeout then set it to the request
    if ( _timeoutInterval > 0 ) {
        [request setTimeoutInterval:_timeoutInterval];
//        NSLog(@"timeout: %f", request.timeoutInterval);
    }
    
    _request = [NSURLConnection connectionWithRequest:request delegate:self];
    if ( _request ) {
        _receivedData = [[NSMutableData alloc] init];
    } else {
        _errorBlock(nil);
    }
}

- (void)cancel {
    if ( !_completed && _request ) {
        [_request cancel];
        _completed = YES;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    [_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    _completed = YES;
    if ( _errorBlock ) {
        _errorBlock(error);
    }
    _receivedData = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    _completed = YES;
    if ( _successBlock ) {
        _successBlock(_receivedData);
    }
    _receivedData = nil;
}

- (void)dealloc {
    _requestURL = nil;
    _errorBlock = nil;
    _successBlock = nil;
}

@end