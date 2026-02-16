//
//  ViewController.h
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import <Cocoa/Cocoa.h>

@class SerialManager;
@class AppSettings;
@class CameraCapture;
@class OlympusCam;

@interface ViewController : NSViewController

@property (weak) IBOutlet NSTextView *outputTextView;
@property (weak) IBOutlet NSView *previewView;
@property (weak) IBOutlet NSImageView *commsLED;
@property (weak) IBOutlet NSImageView *cmdLED;

@property (nonatomic, weak) SerialManager *serialManager;       // handles serial USB comms
@property (nonatomic, weak) AppSettings *appSettings;           // contains application settings
@property (strong) CameraCapture *camera;                       // will run the photo capture via webcam
@property (strong) OlympusCam *olympusCam;                      // will run the photo capture via Olympus SLR


@property (weak) IBOutlet NSButton *btnRewind;
@property (weak) IBOutlet NSButton *btnPing;
@property (weak) IBOutlet NSButton *btnCheckSensor;
@property (weak) IBOutlet NSButton *btnNextCell;
@property (weak) IBOutlet NSButton *btnStartScan;
@property (weak) IBOutlet NSButton *btnTakePhoto;               // Take a photo - for testing and adjusting camera
@property (weak) IBOutlet NSButton *btnOpenPort;

- (IBAction)showSettingsClicked:(id)sender;
- (IBAction)nextCellClicked:(id)sender;
- (IBAction)startScanClicked:(id)sender;
- (IBAction)pingClicked:(id)sender;
- (IBAction)optoClicked:(id)sender;
- (IBAction)rewindClicked:(id)sender;
- (IBAction)takePhotoClicked:(id)sender;
- (IBAction)openPortClicked:(id)sender;

@end

