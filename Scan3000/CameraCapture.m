//
//  CameraCapture.m
//  Scan3000
//
//  Created by Pius Ott on 19/1/2026.
//

#import "CameraCapture.h"
@import AVFoundation;

@interface CameraCapture ()
@property AVCaptureSession *session;
@property AVCapturePhotoOutput *photoOutput;
@end

@implementation CameraCapture

- (void)capturePhotoWithCompletion:(void (^)(NSData *))completion
{
    /*
    // - The below is temp debugging code. Remove this again
     AVCaptureDeviceDiscoverySession *discovery =
         [AVCaptureDeviceDiscoverySession
             discoverySessionWithDeviceTypes:@[
                 AVCaptureDeviceTypeExternalUnknown,
                 AVCaptureDeviceTypeBuiltInWideAngleCamera,
                 AVCaptureDeviceTypeContinuityCamera
             ]
             mediaType:AVMediaTypeVideo
             position:AVCaptureDevicePositionUnspecified];

     NSLog(@"Found %lu devices", discovery.devices.count);

     for (AVCaptureDevice *device in discovery.devices)
     {
         NSLog(@"Device: %@ | uniqueID: %@ | connected: %d",
               device.localizedName,
               device.uniqueID,
               device.connected);
     }
    // - The above is temp debugging code. Remove this again
*/
    
    self.completion = completion;

    AVCaptureDevice *camera =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:camera error:nil];

    self.photoOutput = [[AVCapturePhotoOutput alloc] init];

    self.session = [[AVCaptureSession alloc] init];
    [self.session addInput:input];
    [self.session addOutput:self.photoOutput];

    [self.session startRunning];

    AVCapturePhotoSettings *settings =
        [AVCapturePhotoSettings photoSettings];

    [self.photoOutput capturePhotoWithSettings:settings delegate:self];
}

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

    // Stop session after capture
    [self.session stopRunning];
}

- (void)dealloc
{
    NSLog(@"CameraCapture deallocated");
}

@end

