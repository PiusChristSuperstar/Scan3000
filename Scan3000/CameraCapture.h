//
//  CameraCapture.h
//  Runs still image capture from a USB webcam.
//
//  Created by Pius Ott on 19/1/2026.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@class NSView;

@interface CameraCapture : NSObject <AVCapturePhotoCaptureDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, copy) void (^completion)(NSData *);

- (void)startSession;
- (void)stopSession;
- (void)capturePhotoWithCompletion:(void (^)(NSData *imageData))completion;
- (void)attachPreviewToView:(NSView *)view;

@end

