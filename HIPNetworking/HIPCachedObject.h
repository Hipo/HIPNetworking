//
//  HIPCachedObject.h
//  Chroma
//
//  Created by Taylan Pince on 2013-07-16.
//  Copyright (c) 2013 Change Theory. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface HIPCachedObject : NSObject <NSCoding>

/** NSData instance with the contents of the cache
 */
@property (nonatomic, strong, readonly) NSData *cacheData;

/** MIME type for the stored file
 */
@property (nonatomic, strong, readonly) NSString *MIMEType;

/** Initialization
 
 @param data NSData instance that will be stored in this cached object
 @param MIMEType MIME type for the given data
 */
- (id)initWithData:(NSData *)data
          MIMEType:(NSString *)MIMEType;

@end
