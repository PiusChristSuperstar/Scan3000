//
//  OlympusCam.h
//  Scan3000
//
//  Created by Pius Ott on 16/2/2026.
//

#import <gphoto2/gphoto2.h>

@interface OlympusCam : NSObject

@property (nonatomic) Camera *camera;
@property (nonatomic) GPContext *context;

- (void)CaptureImage:(NSString *)saveImagePath;
- (void)DetectCameras;
- (void)CameraExit;
- (void)DeleteCameraImage:(CameraFilePath)camera_file_path;
- (void)EnableLiveView;     // make sure camera allows live preview
//- (void)RunLivePreview;
- (NSImage *)GetPreviewImage:(CameraFile *)camFile;   // retrieve a preview image from the camera
@end
