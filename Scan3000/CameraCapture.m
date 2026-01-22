//
//  CameraCapture.m
//  Scan3000
//
//  Created by Pius Ott on 19/1/2026.
//

#import "CameraCapture.h"
#import <AppKit/AppKit.h>

@import AVFoundation;

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
    if (error)
    {
        NSLog(@"❌ Photo capture error: %@", error);
        if (self.completion) self.completion(nil);
        return;
    }

    NSData *imageData = [photo fileDataRepresentation];

    if (!imageData)
    {
        NSLog(@"❌ fileDataRepresentation returned nil");
    }

    if (self.completion)
    {
        self.completion(imageData);
    }
}

// ------------------------------------------------------------------------------------------------

- (void)startSession
{
    if (self.session)
    {
        return; // already running or configured
    }

    // 1️⃣ Discover camera
    NSArray<AVCaptureDeviceType> *deviceTypes;
    if (@available(macOS 14.0, *))
    {
        deviceTypes = @[
            AVCaptureDeviceTypeBuiltInWideAngleCamera,
            AVCaptureDeviceTypeContinuityCamera,
            AVCaptureDeviceTypeExternal
        ];
    }
    else
    {
        deviceTypes = @[
            AVCaptureDeviceTypeBuiltInWideAngleCamera,
            AVCaptureDeviceTypeContinuityCamera,
            AVCaptureDeviceTypeExternalUnknown
        ];
    }

    AVCaptureDeviceDiscoverySession *discovery =
        [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:deviceTypes
            mediaType:AVMediaTypeVideo
            position:AVCaptureDevicePositionUnspecified];

    AVCaptureDevice *camera = discovery.devices.firstObject;
    if (!camera)
    {
        NSLog(@"❌ No camera device found");
        return;
    }

    // 2️⃣ Create input
    NSError *inputError = nil;
    AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:camera error:&inputError];

    if (!input)
    {
        NSLog(@"❌ Failed to create input: %@", inputError);
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
        NSLog(@"❌ Cannot add camera input");
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
        NSLog(@"❌ Cannot add photo output");
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

@end

