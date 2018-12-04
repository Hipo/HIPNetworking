//
//  HIPNetworkClient.m
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
static NSTimeInterval const HIPNetworkClientCacheLifetime = 60.0 * 60.0 * 24.0;


extern NSString * HIPEscapedQueryString(NSString *string) {
    NSCharacterSet *allowedCharset = [[NSCharacterSet characterSetWithCharactersInString:@":/?&=;+!@#$()',* "] invertedSet];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharset];
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

@property (nonatomic, strong) dispatch_queue_t taskOperationQueue;

+ (NSString *)taskKeyForIdentifier:(NSString *)identifier
                     withIndexPath:(NSIndexPath *)indexPath;

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

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _activeTasks = [NSMutableDictionary dictionary];
        _defaultHeaders = @{@"Accept": @"application/json",
                            @"Accept-Encoding": @"gzip"};
        
        _taskOperationQueue = dispatch_queue_create("com.hipo.hipnetworking.task_operation_queue", DISPATCH_QUEUE_SERIAL);
        
        [[TMCache sharedCache] trimToDate:[NSDate dateWithTimeIntervalSinceNow:-HIPNetworkClientCacheLifetime]];
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

- (NSURLRequest *)requestWithURL:(NSURL *)url
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

- (NSURLRequest *)requestWithBaseURL:(NSString *)baseURL
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
    
    if ([self isLoggingEnabled] && request.URL != nil && parseMode == HIPNetworkClientParseModeJSON) {
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
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(responseBody, response, nil);
            });
            
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
                        case HIPNetworkClientParseModeJSON: {
                            responseBody = [NSJSONSerialization
                                            JSONObjectWithData:data
                                            options:0
                                            error:nil];
                            break;
                        }
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
                
                if (taskKey &&
                    [taskKey isKindOfClass:[NSString class]]) {
                    [self removeTask:task forKey:taskKey];
                }
            }];
    
    if (taskKey) {
        if (![taskKey isKindOfClass:[NSString class]]) {
            NSLog(@"TASK KEY NOT STRING");
            
            return;
        }
        
        [self addTask:task forKey:taskKey];
    }
    
    [task resume];
}

#pragma mark - Task management

- (void)addTask:(NSURLSessionTask *)task forKey:(NSString *)key {
    dispatch_async(self.taskOperationQueue, ^{
        
        NSArray *currentTasks = [self.activeTasks objectForKey:key];
        NSMutableArray *newTasks = nil;
        
        if (currentTasks == nil) {
            newTasks = [NSMutableArray array];
        } else if ([currentTasks isKindOfClass:[NSArray class]]) { // Just defensive code.
            newTasks = [currentTasks mutableCopy];
        } else {
            [self.activeTasks removeObjectForKey:key]; // Remove unwanted key-value pair from active tasks.
            
            newTasks = [NSMutableArray array];
        }
        
        [newTasks addObject:task];
        
        [self.activeTasks setObject:newTasks forKey:key];
    });
}

- (void)removeTask:(NSURLSessionTask *)task forKey:(NSString *)key {
    dispatch_async(self.taskOperationQueue, ^{
        
        NSArray *currentTasks = [self.activeTasks objectForKey:key];
        
        if (currentTasks == nil) {
            return;
        } else if (![currentTasks isKindOfClass:[NSArray class]]) { // Defensive check.
            [self.activeTasks removeObjectForKey:key]; // Remove unwanted key-value pair from active tasks.
            
            return;
        }
        
        NSMutableArray *newTasks = [currentTasks mutableCopy];
        
        [newTasks removeObject:task];
        
        if ([newTasks count] == 0) { // No need to hold any value for the key in active tasks.
            [self.activeTasks removeObjectForKey:key];
        } else {
            [self.activeTasks setObject:newTasks forKey:key];
        }
    });
}

#pragma mark - Cancellation

- (void)cancelTaskWithIdentifier:(NSString *)identifier
                       indexPath:(NSIndexPath *)indexPath {
    
    NSString *taskKey = [HIPNetworkClient taskKeyForIdentifier:identifier
                                                 withIndexPath:indexPath];
    
    [self cancelTasksWithIdentifier:taskKey];
}

- (void)cancelTasksWithIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return;
    }
    
    dispatch_async(self.taskOperationQueue, ^{
        NSDictionary *frozenTasks = [self.activeTasks copy];
        NSArray *tasks = [frozenTasks objectForKey:identifier];
        NSMutableArray *unwantedTaskKeys = [NSMutableArray array];
        
        if (tasks) {
            if ([tasks isKindOfClass:[NSArray class]]) { // For some reason, the object for task key may be an unknown object which causes crash. Remove the key-value pair if values does not have array value.
                for (NSURLSessionTask *task in tasks) {
                    [task cancel];
                }
            } else {
                [unwantedTaskKeys addObject:identifier];
            }
        }
        
        for (NSString *taskKey in unwantedTaskKeys) {
            [self.activeTasks removeObjectForKey:taskKey];
        }
    });
}

- (void)cancelAllTasks {
    dispatch_async(self.taskOperationQueue, ^{
        for (NSString *key in self.activeTasks) {
            NSArray *tasks = self.activeTasks[key];
            
            if ([tasks isKindOfClass:[NSArray class]]) {
                for (NSURLSessionTask *task in tasks) {
                    [task cancel];
                }
            }
        }
        
        [self.activeTasks removeAllObjects];
    });
}

#pragma mark - Cache key generation

+ (void)clearCacheForKey:(NSString *)cacheKey {
    [[TMCache sharedCache] removeObjectForKey:cacheKey];
}

+ (NSString *)taskKeyForIdentifier:(NSString *)identifier
                     withIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath) {
        if (identifier == nil ||
            ![identifier isKindOfClass:[NSString class]]) {
            return nil;
        }
        
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
    
    [self loadImageFromURL:url
             withScaleMode:scaleMode
                targetSize:targetSize
                identifier:identifier
                 indexPath:indexPath
            notifyOnCancel:NO
         completionHandler:completionHandler];
}

- (void)loadImageFromURL:(NSURL *)url
           withScaleMode:(HIPNetworkClientScaleMode)scaleMode
              targetSize:(CGSize)targetSize
              identifier:(NSString *)identifier
               indexPath:(NSIndexPath *)indexPath
          notifyOnCancel:(BOOL)notifyOnCancel
       completionHandler:(void (^)(UIImage *, NSURL *, NSError *))completionHandler {
    
    if (url == nil) {
        completionHandler(nil, nil, [NSError errorWithDomain:HIPNetworkClientErrorDomain
                                                        code:HIPNetworkClientErrorInvalidURL
                                                    userInfo:nil]);
        
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSString *cacheKey = [HIPNetworkClient cacheKeyForURL:url
                                                    scaleMode:scaleMode
                                                   targetSize:targetSize];
        
        UIImage *cachedImage = [[TMCache sharedCache] objectForKey:cacheKey];
        
        if (cachedImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(cachedImage, url, nil);
            });
            
            return;
        }
        
        NSURLRequest *request = [self requestWithURL:url
                                              method:HIPNetworkClientRequestMethodGet
                                                data:nil];
        
        [self performRequest:request
               withParseMode:HIPNetworkClientParseModeNone
                  identifier:identifier
                   indexPath:indexPath
                cacheResults:NO
           completionHandler:^(id data, NSURLResponse *response, NSError *error) {
               if (error != nil || response == nil) {
                   if (error.code == NSURLErrorCancelled && !notifyOnCancel) {
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
                       UIImage *resizedImage;
                       
                       if (scaleMode == HIPNetworkClientScaleModeNone) {
                           resizedImage = [[UIImage alloc] initWithData:imageData];
                       } else {
                           resizedImage = [HIPNetworkClient resizedImageFromData:imageData
                                                                    withMIMEType:[response MIMEType]
                                                                      targetSize:targetSize
                                                                       scaleMode:scaleMode];
                       }
                       
                       if (resizedImage) {
                           [[TMCache sharedCache] setObject:resizedImage
                                                     forKey:cacheKey];
                       }
                       
                       dispatch_async(dispatch_get_main_queue(), ^{
                           completionHandler(resizedImage, url, nil);
                       });
                   });
               }
           }];
    });
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
