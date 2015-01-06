//
//  HIPNetworkClient.m
//  Chroma
//
//  Created by Taylan Pince on 2013-07-15.
//  Copyright (c) 2013 Change Theory. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>

#import "TMCache.h"

#import "HIPCachedObject.h"
#import "HIPNetworkClient.h"


NSString * const HIPNetworkClientErrorDomain = @"HIPNetworkClientErrorDomain";

static NSTimeInterval const HIPNetworkClientDefaultTimeoutInterval = 30.0;


static NSString * HIPEscapedQueryString(NSString *string) {
    static NSString * const kHIPCharactersToBeEscaped = @":/?&=;+!@#$()',*";
    static NSString * const kHIPCharactersToLeaveUnescaped = @"[].";
    
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kHIPCharactersToLeaveUnescaped, (__bridge CFStringRef)kHIPCharactersToBeEscaped, kCFStringEncodingUTF8);
}

static dispatch_queue_t image_request_operation_processing_queue() {
    static dispatch_queue_t hip_image_request_operation_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hip_image_request_operation_processing_queue = dispatch_queue_create("com.hipo.hipnetworking.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return hip_image_request_operation_processing_queue;
}


@interface HIPNetworkClient ()

+ (NSString *)taskKeyForIdentifier:(NSString *)identifier
                     withIndexPath:(NSIndexPath *)indexPath;

+ (NSString *)cacheKeyForURL:(NSURL *)url;

+ (NSString *)cacheKeyForURL:(NSURL *)url
                   scaleMode:(HIPNetworkClientScaleMode)scaleMode
                  targetSize:(CGSize)targetSize;

+ (UIImage *)resizedImageFromData:(NSData *)data
                     withMIMEType:(NSString *)MIMEType
                       targetSize:(CGSize)targetSize
                        scaleMode:(HIPNetworkClientScaleMode)scaleMode;

- (void)addTask:(NSURLSessionTask *)task forKey:(NSString *)key;
- (void)removeTask:(NSURLSessionTask *)task forKey:(NSString *)key;

@property (nonatomic, strong) NSMutableDictionary *activeTasks;

@end


@implementation HIPNetworkClient

#pragma mark - Init

- (id)init {
    self = [super init];
    
    if (self) {
        [self setActiveTasks:[NSMutableDictionary dictionary]];
        [self setDefaultHeaders:@{@"Accept": @"application/json",
                                  @"Accept-Encoding": @"gzip"}];
    }
    
    return self;
}

#pragma mark - Session

- (NSURLSession *)session {
    if (_session) {
        return _session;
    }
    
    return [NSURLSession sharedSession];
}

#pragma mark - Request generation

- (NSMutableURLRequest *)requestWithURL:(NSURL *)url
                                 method:(HIPNetworkClientRequestMethod)method
                                   data:(NSData *)data {

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadRevalidatingCacheData
                                                       timeoutInterval:HIPNetworkClientDefaultTimeoutInterval];
    
    switch (method) {
        case HIPNetworkClientRequestMethodGet:
            [request setHTTPMethod:@"GET"];
            break;
        case HIPNetworkClientRequestMethodPost:
            [request setHTTPMethod:@"POST"];
            break;
        case HIPNetworkClientRequestMethodPut:
            [request setHTTPMethod:@"PUT"];
            break;
        case HIPNetworkClientRequestMethodDelete:
            [request setHTTPMethod:@"DELETE"];
            break;
        case HIPNetworkClientRequestMethodPatch:
            [request setHTTPMethod:@"PATCH"];
            break;
    }
    
    if (data) {
        [request setHTTPBody:data];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[data length]] forHTTPHeaderField:@"Content-Length"];
    }
    
    if (self.defaultHeaders) {
        for (NSString *headerKey in [self.defaultHeaders allKeys]) {
            [request setValue:[self.defaultHeaders objectForKey:headerKey] forHTTPHeaderField:headerKey];
        }
    }
    
    return request;
}

- (NSMutableURLRequest *)requestWithBaseURL:(NSString *)baseURL
                                       path:(NSString *)path
                                     method:(HIPNetworkClientRequestMethod)method
                            queryParameters:(NSDictionary *)queryParameters
                                       data:(NSData *)data {

    NSMutableString *requestPath = [NSMutableString stringWithFormat:@"%@%@", baseURL, path];
    NSString *lastCharacter = [requestPath substringFromIndex:([requestPath length] - 1)];

    if (![lastCharacter isEqualToString:@"&"]) {
        [requestPath appendString:@"?"];
    }
    
    if (queryParameters != nil) {
        for (NSString *key in [queryParameters allKeys]) {
            id value = [queryParameters objectForKey:key];
            
            if ((NSNull *)value == [NSNull null]) {
                value = @"";
            }
            
            if ([value respondsToSelector:@selector(stringValue)]) {
                [requestPath appendFormat:@"%@=%@&", key, HIPEscapedQueryString([value stringValue])];
            } else {
                [requestPath appendFormat:@"%@=%@&", key, HIPEscapedQueryString((NSString *)value)];
            }
        }
    }
    
    if ([requestPath hasSuffix:@"&"]) {
        requestPath = [[requestPath substringToIndex:[requestPath length] - 1] mutableCopy];
    }
    
    return [self requestWithURL:[NSURL URLWithString:requestPath]
                         method:method
                           data:data];
}

#pragma mark - Request performing

- (void)performRequest:(NSURLRequest *)request
         withParseMode:(HIPNetworkClientParseMode)parseMode
            identifier:(NSString *)identifier
             indexPath:(NSIndexPath *)indexPath
          cacheResults:(BOOL)cache
     completionHandler:(void (^)(id, NSURLResponse*, NSError *))completionHandler {
    
    if ([self isLoggingEnabled] && request.URL != nil) {
        NSLog(@"%@ %@", request.HTTPMethod, [request.URL absoluteString]);
    }
    
    if (cache) {
        HIPCachedObject *cachedObject = [[TMCache sharedCache] objectForKey:
                                         [HIPNetworkClient cacheKeyForURL:request.URL]];
        
        if (cachedObject) {
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                                MIMEType:cachedObject.MIMEType
                                                   expectedContentLength:[cachedObject.cacheData length]
                                                        textEncodingName:@"UTF8"];
            
            id responseBody = nil;
            
            switch (parseMode) {
                case HIPNetworkClientParseModeImage:
                    responseBody = [UIImage imageWithData:cachedObject.cacheData];
                    break;
                case HIPNetworkClientParseModeJSON:
                    responseBody = [NSJSONSerialization
                                    JSONObjectWithData:cachedObject.cacheData
                                    options:0
                                    error:nil];
                    break;
                case HIPNetworkClientParseModeNone:
                    responseBody = cachedObject.cacheData;
                    break;
            }
            
            completionHandler(responseBody, response, nil);
            return;
        }
    }
    
    NSURLSessionDataTask *task;
    NSString *taskKey = nil;
    
    if (identifier) {
        taskKey = [HIPNetworkClient taskKeyForIdentifier:identifier
                                           withIndexPath:indexPath];
    }
    
    task = [self.session
            dataTaskWithRequest:request
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                id responseBody = nil;
                NSInteger statusCode = 0;
                
                if ([response respondsToSelector:@selector(statusCode)]) {
                    statusCode = [(NSHTTPURLResponse *)response statusCode];
                }
                
                if (error == nil) {
                    switch (parseMode) {
                        case HIPNetworkClientParseModeImage:
                            responseBody = [UIImage imageWithData:data];
                            break;
                        case HIPNetworkClientParseModeJSON:
                            responseBody = [NSJSONSerialization
                                            JSONObjectWithData:data
                                            options:0
                                            error:nil];
                            break;
                        case HIPNetworkClientParseModeNone:
                            responseBody = data;
                            break;
                    }
                    
                    if (statusCode >= 400) {
                        error = [NSError errorWithDomain:HIPNetworkClientErrorDomain
                                                    code:statusCode
                                                userInfo:nil];
                    }
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(responseBody, response, error);
                });
                
                if (cache && responseBody != nil && error == nil) {
                    HIPCachedObject *cachedObject = [[HIPCachedObject alloc]
                                                     initWithData:data
                                                     MIMEType:[response MIMEType]];
                    
                    [[TMCache sharedCache] setObject:cachedObject
                                              forKey:[HIPNetworkClient cacheKeyForURL:request.URL]];
                }
                
                if (taskKey) {
                    [self removeTask:task forKey:taskKey];
                }
            }];
    
    if (taskKey) {
        [self addTask:task forKey:taskKey];
    }
    
    [task resume];
}

#pragma mark - Task management

- (void)addTask:(NSURLSessionTask *)task forKey:(NSString *)key {
    NSArray *currentTasks = [self.activeTasks objectForKey:key];
    NSMutableArray *newTasks = nil;
    
    if (currentTasks == nil) {
        newTasks = [NSMutableArray array];
    } else {
        newTasks = [currentTasks mutableCopy];
    }
    
    [newTasks addObject:task];
    
    [self.activeTasks setObject:newTasks forKey:key];
}

- (void)removeTask:(NSURLSessionTask *)task forKey:(NSString *)key {
    NSArray *currentTasks = [self.activeTasks objectForKey:key];
    
    if (currentTasks == nil) {
        return;
    } else if ([currentTasks count] == 1) {
        [self.activeTasks removeObjectForKey:key];
        
        return;
    }

    NSMutableArray *newTasks = [currentTasks mutableCopy];
    
    [newTasks removeObject:task];
    
    [self.activeTasks setObject:newTasks forKey:key];
}

#pragma mark - Cancellation

- (void)cancelTaskWithIdentifier:(NSString *)identifier
                       indexPath:(NSIndexPath *)indexPath {
    NSString *taskKey = [HIPNetworkClient taskKeyForIdentifier:identifier
                                                 withIndexPath:indexPath];
    
    NSArray *tasks = [self.activeTasks objectForKey:taskKey];
    
    if (tasks) {
        for (NSURLSessionTask *task in tasks) {
            [task cancel];
        }
    }
}

- (void)cancelTasksWithIdentifier:(NSString *)identifier {
    for (NSString *taskKey in [self.activeTasks allKeys]) {
        if (![taskKey hasPrefix:identifier]) {
            continue;
        }

        NSArray *tasks = [self.activeTasks objectForKey:taskKey];
        
        if (tasks) {
            for (NSURLSessionTask *task in tasks) {
                [task cancel];
            }
        }
    }
}

#pragma mark - Cache key generation

+ (NSString *)taskKeyForIdentifier:(NSString *)identifier
                     withIndexPath:(NSIndexPath *)indexPath {

    if (indexPath) {
        return [NSString stringWithFormat:@"%@_%ld_%ld",
                identifier, (long)indexPath.section, (long)indexPath.row];
    } else {
        return identifier;
    }
}

+ (NSString *)cacheKeyForURL:(NSURL *)url {
    NSString *absoluteURL = [url absoluteString];
    const char *cString = [absoluteURL cStringUsingEncoding:NSUTF8StringEncoding];
	NSData *stringData = [NSData dataWithBytes:cString length:[absoluteURL length]];
	
	uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1([stringData bytes], (CC_LONG)[stringData length], digest);
	
	NSMutableString *hashedURL = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
	
	for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
		[hashedURL appendFormat:@"%02x", digest[i]];
	}
    
    return hashedURL;
}

+ (NSString *)cacheKeyForURL:(NSURL *)url
                   scaleMode:(HIPNetworkClientScaleMode)scaleMode
                  targetSize:(CGSize)targetSize {
    
    NSString *lastComponent = [[url absoluteString] lastPathComponent];
    NSString *extension = [lastComponent pathExtension];
    NSString *hashedURL = [HIPNetworkClient cacheKeyForURL:url];
    
    return [NSString stringWithFormat:@"%@_%1.0f_%1.0f_%d.%@",
            hashedURL, targetSize.width, targetSize.height, scaleMode, extension];
}

#pragma mark - Image loading

- (void)loadImageFromURL:(NSURL *)url
           withScaleMode:(HIPNetworkClientScaleMode)scaleMode
              targetSize:(CGSize)targetSize
              identifier:(NSString *)identifier
               indexPath:(NSIndexPath *)indexPath
       completionHandler:(void (^)(UIImage *, NSURL *, NSError *))completionHandler {
    
    if (url == nil) {
        completionHandler(nil, nil, [NSError errorWithDomain:HIPNetworkClientErrorDomain
                                                        code:HIPNetworkClientErrorInvalidURL
                                                    userInfo:nil]);
        
        return;
    }
    
    if ([self isLoggingEnabled]) {
        NSLog(@"LOAD %@", [url absoluteString]);
    }

    NSString *cacheKey = [HIPNetworkClient cacheKeyForURL:url
                                                scaleMode:scaleMode
                                               targetSize:targetSize];
    
    UIImage *image = [[TMCache sharedCache] objectForKey:cacheKey];

    if (image) {
        completionHandler(image, url, nil);
        return;
    }
    
    NSURLRequest *request = [self requestWithURL:url
                                          method:HIPNetworkClientRequestMethodGet
                                            data:nil];
    
    [self performRequest:request
           withParseMode:HIPNetworkClientParseModeNone
              identifier:identifier
               indexPath:indexPath
            cacheResults:YES
       completionHandler:^(id data, NSURLResponse *response, NSError *error) {
           if (error != nil || response == nil) {
               if (error.code == NSURLErrorCancelled) {
                   return;
               }

               completionHandler(nil, response.URL, error);
           } else {
               NSData *imageData = (NSData *)data;
               
               if (imageData == nil || [imageData length] <= 0) {
                   completionHandler(nil, response.URL, nil);
                   return;
               }
               
               dispatch_async(image_request_operation_processing_queue(), ^{
                   UIImage *image = [HIPNetworkClient resizedImageFromData:imageData
                                                              withMIMEType:[response MIMEType]
                                                                targetSize:targetSize
                                                                 scaleMode:scaleMode];
                   
                   dispatch_async(dispatch_get_main_queue(), ^{
                       completionHandler(image, response.URL, nil);
                       
                       if (image) {
                           [[TMCache sharedCache] setObject:image
                                                     forKey:cacheKey];
                       }
                   });
               });
           }
       }];
}

#pragma mark - Image resize

+ (UIImage *)resizedImageFromData:(NSData *)data
                     withMIMEType:(NSString *)MIMEType
                       targetSize:(CGSize)targetSize
                        scaleMode:(HIPNetworkClientScaleMode)scaleMode {

    if (!data || [data length] == 0) {
        return nil;
    }

    UIImage *image = [[UIImage alloc] initWithData:data];
    
    if (image == nil) {
        return nil;
    }
    
    UIImage *inflatedImage = [image resizedImageWithTargetSize:targetSize
                                                     scaleMode:scaleMode];
    
    if (inflatedImage == nil) {
        inflatedImage = [[UIImage alloc] initWithData:data];
    }
    
    return inflatedImage;
}

@end
