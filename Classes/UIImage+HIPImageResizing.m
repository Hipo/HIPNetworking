//
//  UIImage+HIPImageResizing.m
//  Chroma
//
//  Created by Taylan Pince on 2/17/2014.
//  Copyright (c) 2014 Change Theory. All rights reserved.
//

#import "UIImage+HIPImageResizing.h"


static inline double radians (double degrees) {return degrees * M_PI/180;}


@implementation UIImage (HIPImageResizing)

- (UIImage *)resizedImageWithTargetSize:(CGSize)targetSize
                              scaleMode:(HIPNetworkClientScaleMode)scaleMode {
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGImageRef imageRef = [self CGImage];
    CGSize originalSize = self.size;
    
    switch (self.imageOrientation) {
        case UIImageOrientationRight:
        case UIImageOrientationLeft:
            originalSize = CGSizeMake(self.size.height, self.size.width);
            break;
        default:
            break;
    }
    
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    size_t bytesPerRow = 0;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    if (CGColorSpaceGetNumberOfComponents(colorSpace) == 3) {
        int alpha = (bitmapInfo & kCGBitmapAlphaInfoMask);
        
        if (alpha == kCGImageAlphaNone) {
            bitmapInfo &= ~kCGBitmapAlphaInfoMask;
            bitmapInfo |= kCGImageAlphaNoneSkipFirst;
        } else if (!(alpha == kCGImageAlphaNoneSkipFirst || alpha == kCGImageAlphaNoneSkipLast)) {
            bitmapInfo &= ~kCGBitmapAlphaInfoMask;
            bitmapInfo |= kCGImageAlphaPremultipliedFirst;
        }
    }
    
    CGFloat imageScale = 1.0;
    CGSize imageTargetSize = CGSizeMake(targetSize.width * scale, targetSize.height * scale);
    
    switch (scaleMode) {
        case HIPNetworkClientScaleModeTop:
        case HIPNetworkClientScaleModeSizeToFill:
            imageScale = fmaxf(imageTargetSize.width / originalSize.width,
                               imageTargetSize.height / originalSize.height);
            break;
        case HIPNetworkClientScaleModeCenter:
            imageScale = 1.0;
            break;
        default:
            imageScale = fminf(imageTargetSize.width / originalSize.width,
                               imageTargetSize.height / originalSize.height);
            break;
    }
    
    CGSize imageSize = CGSizeMake(ceil(originalSize.width * imageScale), ceil(originalSize.height * imageScale));
    CGRect targetRect = CGRectZero;
    
    switch (scaleMode) {
        case HIPNetworkClientScaleModeTop:
            targetRect = CGRectMake(imageTargetSize.width - imageSize.width,
                                    imageTargetSize.height - imageSize.height,
                                    imageSize.width, imageSize.height);
            break;
        case HIPNetworkClientScaleModeSizeToFill:
            targetRect = CGRectMake(floor((imageTargetSize.width - imageSize.width) / 2),
                                    floor((imageTargetSize.height - imageSize.height) / 2),
                                    imageSize.width, imageSize.height);
            break;
        case HIPNetworkClientScaleModeCenter:
            targetRect = CGRectMake(floor((imageTargetSize.width - imageSize.width) / 2),
                                    floor((imageTargetSize.height - imageSize.height) / 2),
                                    imageSize.width, imageSize.height);
            break;
        default:
            imageTargetSize = imageSize;
            targetRect = CGRectMake(0.0, 0.0, imageSize.width, imageSize.height);
            break;
    }
    
    CGSize contextSize = imageTargetSize;
    
    switch (self.imageOrientation) {
        case UIImageOrientationRight:
        case UIImageOrientationLeft:
            contextSize = CGSizeMake(imageTargetSize.height, imageTargetSize.width);
            break;
        default:
            break;
    }
    
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 contextSize.width,
                                                 contextSize.height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    if (!context) {
        return nil;
    }
    
    switch (self.imageOrientation) {
        case UIImageOrientationLeft: {
            CGContextRotateCTM(context, radians(90.0));
            CGContextTranslateCTM(context, 0.0, -1.0 * imageTargetSize.height);
            
            break;
        }
        case UIImageOrientationRight: {
            CGContextRotateCTM(context, radians(-90.0));
            CGContextTranslateCTM(context, -1.0 * imageTargetSize.width, 0.0);
            
            break;
        }
        case UIImageOrientationDown: {
            CGContextTranslateCTM(context, imageTargetSize.width, imageTargetSize.height);
            CGContextRotateCTM(context, radians(-180.0));
            
            break;
        }
        default:
            break;
    }
    
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, targetRect, imageRef);
    
    CGImageRef inflatedImageRef = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    
    UIImage *inflatedImage = [[UIImage alloc] initWithCGImage:inflatedImageRef
                                                        scale:scale
                                                  orientation:UIImageOrientationUp];
    
    CGImageRelease(inflatedImageRef);
    
    return inflatedImage;
}

@end
