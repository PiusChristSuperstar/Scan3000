//
//  CameraCapture.h
//  Runs still image capture from a USB webcam.
//
//  Created by Pius Ott on 19/1/2026.
//

#import <Foundation/Foundation.h>

@interface CameraCapture : NSObject

@property (nonatomic, copy) void (^completion)(NSData *);

- (void)capturePhotoWithCompletion:(void (^)(NSData *imageData))completion;

@end
