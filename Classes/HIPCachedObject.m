//
//  HIPCachedObject.m
//  Chroma
//
//  Created by Taylan Pince on 2013-07-16.
//  Copyright (c) 2013 Change Theory. All rights reserved.
//

#import "HIPCachedObject.h"


static NSString * const HIPCachedObjectDataKey = @"data";
static NSString * const HIPCachedObjectMIMETypeKey = @"mimetype";


@implementation HIPCachedObject

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_cacheData forKey:HIPCachedObjectDataKey];
    [aCoder encodeObject:_MIMEType forKey:HIPCachedObjectMIMETypeKey];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSData *data = [aDecoder decodeObjectForKey:HIPCachedObjectDataKey];
    NSString *MIMEType = [aDecoder decodeObjectForKey:HIPCachedObjectMIMETypeKey];
    
    return [self initWithData:data MIMEType:MIMEType];
}

- (id)initWithData:(NSData *)data MIMEType:(NSString *)MIMEType {
    self = [super init];
    
    if (self) {
        _cacheData = data;
        _MIMEType = MIMEType;
    }
    
    return self;
}

@end
