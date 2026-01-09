//
//  ViewController.h
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import <Cocoa/Cocoa.h>

@class SerialBuffer;

@interface ViewController : NSViewController

@property (nonatomic, strong) SerialBuffer *receiveBuffer;
@property (nonatomic, assign) int usb;
@property (nonatomic, strong) NSMutableData *rawBuffer;

@property (weak) IBOutlet NSTextView *outputTextView;

- (IBAction)showSettingsClicked:(id)sender;
- (IBAction)nextCellClicked:(id)sender;
- (IBAction)showSerialBufferClicked:(id)sender;
- (IBAction)exitClicked:(id)sender;


@end

