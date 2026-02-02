//
//  CameraCapture.m
//  Scan3000
//
//  Handles standard webcam streaming and photo capture. I'm building this class mainly to allow me to
//  test functionality of the app. Actual capture will likely be taken through a new interface to a
//  higher resolution Olympus DSLR camera. But I'll leave this class in and we'll be able to select it
//  for usage through settings in the xcconfig file.
//
//  Created by Pius Ott on 19/1/2026.
//

#import "CameraCapture.h"
#import <AppKit/AppKit.h>

@import AVFoundation;


// Keys for notifications we're sending out to observers
NSString * const CameraInfoNotification = @"CameraInfoNotification";
NSString * const CameraInfoKey = @"CameraInfoKey";

@interface CameraCapture ()
@end

@implementation CameraCapture

// ------------------------------------------------------------------------------------------------

- (void)capturePhotoWithCompletion:(void (^)(NSData *))completion
{
    self.completion = completion;

    AVCapturePhotoSettings *settings =
        [AVCapturePhotoSettings photoSettings];

    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
}

// ------------------------------------------------------------------------------------------------

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhoto:(AVCapturePhoto *)photo
               error:(NSError *)error
{
    NSString *errorMsg;
    if (error)
    {
        errorMsg = [NSString stringWithFormat:@"❌ Photo capture error: %@", error];
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];
        
        if (self.completion)
            self.completion(nil);
        
        return;
    }

    NSData *imageData = [photo fileDataRepresentation];

    if (!imageData)
    {
        errorMsg = @"❌ fileDataRepresentation returned nil";
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];
    }

    if (self.completion)
    {
        self.completion(imageData);
    }
}

// ------------------------------------------------------------------------------------------------

- (void)startSession:(NSSize)camResolution
{
    if (self.session)
    {
        return; // already running or configured
    }

    // 1️⃣ Discover camera
    NSArray<AVCaptureDeviceType> *deviceTypes = @[
            AVCaptureDeviceTypeBuiltInWideAngleCamera,
            AVCaptureDeviceTypeContinuityCamera,
            AVCaptureDeviceTypeExternal
        ];

    AVCaptureDeviceDiscoverySession *discovery =
        [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:deviceTypes
            mediaType:AVMediaTypeVideo
            position:AVCaptureDevicePositionUnspecified];

    NSString *errorMsg;
    _videoDevice = discovery.devices.firstObject;
    if (!_videoDevice)
    {
        errorMsg = @"❌ No camera device found";
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];
        return;
    }

    if ([self setCamResolution:camResolution.width height:camResolution.height] == FALSE)
    {
        // We don't want to crash out here. Just revert to default settings.
        errorMsg = [NSString stringWithFormat:@"❌ Camera does not support: %d x %d", (int)camResolution.width, (int)camResolution.height];
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];

        [self checkAvailableResolution];    // just for info, show what resolutions are available in NSLog
    }
    else
    {
        // not really an error message...
        errorMsg = [NSString stringWithFormat:@"Camera resolution set to: %d x %d", (int)camResolution.width, (int)camResolution.height];
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];
    }
    
    // 2️⃣ Create input
    NSError *inputError = nil;
    AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&inputError];

    if (!input)
    {
        errorMsg = [NSString stringWithFormat:@"❌ Failed to create input: %@", inputError];
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];
        return;
    }

    // 3️⃣ Create session
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;

    [self.session beginConfiguration];

    // 4️⃣ Add input
    if ([self.session canAddInput:input])
    {
        [self.session addInput:input];
    }
    else
    {
        errorMsg = @"❌ Cannot add camera input";
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];

        [self.session commitConfiguration];
        self.session = nil;
        return;
    }

    // 5️⃣ Add photo output
    self.photoOutput = [[AVCapturePhotoOutput alloc] init];

    if ([self.session canAddOutput:self.photoOutput])
    {
        [self.session addOutput:self.photoOutput];
    }
    else
    {
        errorMsg = @"❌ Cannot add photo output";
        NSLog(@"%@", errorMsg);
        [self notifyView:errorMsg];
        
        [self.session commitConfiguration];
        self.session = nil;
        return;
    }

    [self.session commitConfiguration];

    // 6️⃣ Start running
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.session startRunning];
    });
}

// ------------------------------------------------------------------------------------------------

- (void)stopSession
{
    if (self.session.isRunning)
    {
        [self.session stopRunning];
    }

    self.session = nil;
    self.photoOutput = nil;
}

// ------------------------------------------------------------------------------------------------

- (void)attachPreviewToView:(NSView *)view
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.previewLayer =
            [AVCaptureVideoPreviewLayer layerWithSession:self.session];

        self.previewLayer.videoGravity =
            AVLayerVideoGravityResizeAspectFill;

        self.previewLayer.frame = view.bounds;

        [view.layer addSublayer:self.previewLayer];
    });
}

// ------------------------------------------------------------------------------------------------

- (void)dealloc
{
    NSLog(@"CameraCapture deallocated");
}

// ------------------------------------------------------------------------------------------------

- (void)checkAvailableResolution
{
    AVCaptureDevice *device = self.videoDevice;
    
    for (AVCaptureDeviceFormat *format in device.formats)
    {
        CMVideoDimensions dims =
        CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        
        NSLog(@"Format: %d x %d", dims.width, dims.height);
        
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges)
        {
            NSLog(@"  FPS: %.2f - %.2f",
                  range.minFrameRate,
                  range.maxFrameRate);
        }
    }
}

// ------------------------------------------------------------------------------------------------

- (BOOL)setCamResolution:(int)width height:(int)height
{
    AVCaptureDevice *device = self.videoDevice;

    for (AVCaptureDeviceFormat *format in device.formats)
    {
        CMVideoDimensions dims =
            CMVideoFormatDescriptionGetDimensions(format.formatDescription);

        if (dims.width == width && dims.height == height)
        {
            NSError *error = nil;
            if ([device lockForConfiguration:&error])
            {
                device.activeFormat = format;
                [device unlockForConfiguration];
                return YES;
            }
            else
            {
                NSString *errorMsg = [NSString stringWithFormat:@"Error locking device: %@", error];
                NSLog(@"%@", errorMsg);
                [self notifyView:errorMsg];

                return NO;
            }
        }
    }
    return NO;
}

// ------------------------------------------------------------------------------------------------

// send a message to the ViewController that we want it to display
- (void)notifyView:(NSString *)displayText
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:CameraInfoNotification
         object:self
         userInfo:@{ CameraInfoKey : displayText }];
    });
}

// ------------------------------------------------------------------------------------------------

@end

