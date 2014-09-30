//
//  UIImage+HIPImageResizing.h
//  Chroma
//
//  Created by Taylan Pince on 2/17/2014.
//  Copyright (c) 2014 Change Theory. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    HIPNetworkClientScaleModeNone,
    HIPNetworkClientScaleModeSizeToFit,
    HIPNetworkClientScaleModeSizeToFill,
    HIPNetworkClientScaleModeCenter,
    HIPNetworkClientScaleModeTop,
} HIPNetworkClientScaleMode;


@interface UIImage (HIPImageResizing)

/** Image resizing
 
 Resizes the image to a target size using the provided scale mode
 
 @param targetSize Target size for the final image
 @param scaleMode Scale mode to use during resizing
 */
- (UIImage *)resizedImageWithTargetSize:(CGSize)targetSize
                              scaleMode:(HIPNetworkClientScaleMode)scaleMode;

@end
