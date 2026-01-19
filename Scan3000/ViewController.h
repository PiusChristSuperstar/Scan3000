//
//  ViewController.h
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import <Cocoa/Cocoa.h>

@class SerialManager;
@class AppSettings;

@interface ViewController : NSViewController

@property (weak) IBOutlet NSTextView *outputTextView;
@property (weak) IBOutlet NSImageView *commsLED;
@property (weak) IBOutlet NSImageView *cmdLED;

@property (nonatomic, weak) SerialManager *serialManager;       // handles serial USB comms
@property (nonatomic, weak) AppSettings *appSettings;           // contains application settings

@property (weak) IBOutlet NSButton *btnRewind;
@property (weak) IBOutlet NSButton *btnPing;
@property (weak) IBOutlet NSButton *btnCheckSensor;
@property (weak) IBOutlet NSButton *btnNextCell;
@property (weak) IBOutlet NSButton *btnStartScan;

- (IBAction)showSettingsClicked:(id)sender;
- (IBAction)nextCellClicked:(id)sender;
- (IBAction)startScanClicked:(id)sender;
- (IBAction)pingClicked:(id)sender;
- (IBAction)optoClicked:(id)sender;
- (IBAction)rewindClicked:(id)sender;
@end

