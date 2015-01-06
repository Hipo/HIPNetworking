//
//  HIPNetworkClient.h
//  Chroma
//
//  Created by Taylan Pince on 2013-07-15.
//  Copyright (c) 2013 Change Theory. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "UIImage+HIPImageResizing.h"


extern NSString * const HIPNetworkClientErrorDomain;


typedef enum {
    HIPNetworkClientRequestMethodGet,
    HIPNetworkClientRequestMethodPost,
    HIPNetworkClientRequestMethodPut,
    HIPNetworkClientRequestMethodDelete,
    HIPNetworkClientRequestMethodPatch,
} HIPNetworkClientRequestMethod;

typedef enum {
    HIPNetworkClientParseModeNone,
    HIPNetworkClientParseModeJSON,
    HIPNetworkClientParseModeImage,
} HIPNetworkClientParseMode;

typedef enum {
    HIPNetworkClientErrorInvalidURL = 100,
} HIPNetworkClientError;


@interface HIPNetworkClient : NSObject

/** Active session used by this network client for all requests
 */
@property (nonatomic, strong) NSURLSession *session;

/** Default headers that will be added to all outgoing requests
 */
@property (nonatomic, strong) NSDictionary *defaultHeaders;

/** Determines whether request logging is enabled or not
 */
@property (nonatomic, assign, getter=isLoggingEnabled) BOOL loggingEnabled;

/** Request generator
 
 Method for generating an NSURLRequest from an NSURL to be fed to the session
 
 @param url URL for the request
 @param method Request method
 @param data Body data to be sent with the request
 */
- (NSMutableURLRequest *)requestWithURL:(NSURL *)url
                                 method:(HIPNetworkClientRequestMethod)method
                                   data:(NSData *)data;

/** Request generator using base URL, path and query string
 
 Method for generating an NSURLRequest from a base URL, path, and query string 
 to be fed to the session
 
 @param baseURL Base URL for the request
 @param path Path to be appended to the base URL
 @param method Request method
 @param queryParameters Query parameters that should be appended to the URL
 @param data Body data to be sent with the request
 */
- (NSMutableURLRequest *)requestWithBaseURL:(NSString *)baseURL
                                       path:(NSString *)path
                                     method:(HIPNetworkClientRequestMethod)method
                            queryParameters:(NSDictionary *)queryParameters
                                       data:(NSData *)data;

/** Request performer
 
 Method for performing a request using the given NSURLRequest instance
 
 @param request NSURLRequest instance to perform the request with
 @param parseMode Determines what kind of parsing should be applied to the response data
 @param identifier A unique group identifier for this task, it can be the controller's name or path
 @param indexPath An optional index path that uniquely identifies this request within its group
 @param cache Flag for determining whether the response should be cached if successful
 @param completionHandler Handler block that will be called when the request is performed
 */
- (void)performRequest:(NSURLRequest *)request
         withParseMode:(HIPNetworkClientParseMode)parseMode
            identifier:(NSString *)identifier
             indexPath:(NSIndexPath *)indexPath
          cacheResults:(BOOL)cache
     completionHandler:(void (^)(id parsedData, NSURLResponse *response, NSError *error))completionHandler;

/** Image loader and processor
 
 Loads and processes an image from the given URL
 
 @param url NSURL to load the image from
 @param scaleMode Determines what kind of scaling should be applied to the image
 @param targetSize Target size for the image
 @param identifier A unique group identifier for this task, it can be the controller's name or path
 @param indexPath An optional index path that uniquely identifies this request within its group
 @param completionHandler Handler block that will be called when the image is ready
 */
- (void)loadImageFromURL:(NSURL *)url
           withScaleMode:(HIPNetworkClientScaleMode)scaleMode
              targetSize:(CGSize)targetSize
              identifier:(NSString *)identifier
               indexPath:(NSIndexPath *)indexPath
       completionHandler:(void (^)(UIImage *image, NSURL *url, NSError *error))completionHandler;

/** Task cancellation
 
 Cancels a task with the given identifier and index path
 
 @param identifier Unique group identifier for the task
 @param indexPath Optional index path for the task
 */
- (void)cancelTaskWithIdentifier:(NSString *)identifier
                       indexPath:(NSIndexPath *)indexPath;

/** Batch task cancellation
 
 Cancels tasks with the given group identifier
 
 @param identifier Unique group identifier for the task
 */
- (void)cancelTasksWithIdentifier:(NSString *)identifier;

@end
