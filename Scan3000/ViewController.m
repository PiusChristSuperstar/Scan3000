//
//  ViewController.m
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#import "ViewController.h"
#import "ArduinoResponse.h"
#import "SerialManager.h"
#import "AppDelegate.h"
#import "CameraCapture.h"

// ------------------------------------------------------------------------------------------------

@interface ViewController ()

// TODO: we may need to make this atomic to keep it threadsafe
@property (nonatomic) BOOL scanThreadRunning;   // true if we're currently scanning

@end

// ------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------

@implementation ViewController

// ------------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];

    _scanThreadRunning = false;
    
    AppDelegate *appDelegate = (AppDelegate *)NSApp.delegate;
    self.serialManager = appDelegate.serialManager;
    self.appSettings = appDelegate.appSettings;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(serialDidReceiveLine:)
        name:SerialDidReceiveLineNotification
        object:nil];

    [self setLEDState:LEDStateOff imgName:_commsLED];
    [self setLEDState:LEDStateRed imgName:_cmdLED];

    // TODO : only do this if the SerialManager has opened the serial port successfully
    //[self setLEDState:LEDStateGreen imgName:_commsLED];
    [self appendOutput:@"Monitoring USB input...\n\n"];
 }

// ------------------------------------------------------------------------------------------------

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

// ------------------------------------------------------------------------------------------------

- (void)serialDidReceiveLine:(NSNotification *)note
{
    NSString *line = note.userInfo[SerialLineKey];

    [self appendOutput:[NSString stringWithFormat:@"%@\n", line]];  // display in textview
    
    if ([line isEqualToString:@CMD_OK] ||       // Acknowledgement. Sent as a response to each command
        [line isEqualToString:@CMD_READY] ||    // Sent when the Arduino is ready to receive instructions
        [line isEqualToString:@CMD_ATCELL])     // The film has been positioned and is ready for a photo capture
    {
        [self setLEDState:LEDStateGreen imgName:self->_cmdLED];
    }
    else if ([line isEqualToString:@RSP_ERR])
        [self setLEDState:LEDStateRed imgName:self->_cmdLED];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ------------------------------------------------------------------------------------------------

- (void)appendOutput:(NSString *)text
{
    NSTextStorage *storage = self.outputTextView.textStorage;
    [storage appendAttributedString:[[NSAttributedString alloc] initWithString:text]];
    [self.outputTextView scrollRangeToVisible:NSMakeRange(storage.length, 0)];
}

// ------------------------------------------------------------------------------------------------

- (void)sendCommand:(NSString *)cmd
{
    [self setLEDState:LEDStateRed imgName:_cmdLED];

    NSString *response = [self.serialManager sendCommand:cmd];
    if (response != NULL)
    {
        [self appendOutput:response];
    }
    else
    {
        [self appendOutput:[NSString stringWithFormat:@"Sent: %@\n", cmd]];
    }
}

// ------------------------------------------------------------------------------------------------

- (IBAction)showSettingsClicked:(id)sender
{
    [self appendOutput:@"\n=== Settings ===\n"];
    [self appendOutput:@"\nNote that for the time being, settings can only be changed through the config file.\n"];
    
    [self appendOutput:[NSString stringWithFormat:@"\n\tConfiguration File\t\t: %s", [_appSettings.configFile UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCells To Read\t\t\t: %li", _appSettings.cellsToRead]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCapture Pause\t\t\t: %li", _appSettings.capturePause]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tUSB Port\t\t\t\t: %s", [_appSettings.usbPortName UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tLog File\t\t\t\t: %s", [_appSettings.logFileName UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCaptured Image Location\t: %s\n\n", [_appSettings.imagePath UTF8String]]];
    // TODO: maybe add an option to re-load settings file?

    // Also display the current scanner state flags
    [self appendOutput:@"\n=== Scanner Flags ===\n"];
    [self appendOutput:[NSString stringWithFormat:@"\tReady\t: %@\n", _serialManager.scannerIsReady ? @"YES" : @"NO"]];
    [self appendOutput:[NSString stringWithFormat:@"\tAt Cell\t: %@\n", _serialManager.scannerAtCell ? @"YES" : @"NO"]];
    [self appendOutput:[NSString stringWithFormat:@"\tOk\t\t: %@\n", _serialManager.scannerOk ? @"YES" : @"NO"]];
    [self appendOutput:[NSString stringWithFormat:@"\tTimeout\t: %@\n", _serialManager.scannerTimeout ? @"YES" : @"NO"]];
    [self appendOutput:[NSString stringWithFormat:@"\tError\t\t: %@\n", _serialManager.scannerError ? @"YES" : @"NO"]];
}

// ------------------------------------------------------------------------------------------------

- (IBAction)startScanClicked:(id)sender
{
    if (_scanThreadRunning)
    {
        self.scanThreadRunning = NO;    // tell the thread to exit

        // TODO: change the button label to "Start Scanning"
        // TODO: re-enable the disabled buttons
    }
    else
    {
        [self startScanThread];
        // TODO: Start scanning
        // TODO: change the button label to "Stop Scanning"
    }
    
    
    // TODO : Implement this. For the moment we run however many scans as are defined in appSettings.cellsToRead
    //        Eventually we'll want to scan until either the film has ended (interrupt switch triggered) or
    //        until the user clicks the "Stop" button (e.g. this button again while we're scanning.
    // TODO: Also while we're scanning, disable the "Rewind", "Ping", "Check Sensor" and "Next Cell" buttons
    // TODO: We should really display the last scanned image too.
}

// ------------------------------------------------------------------------------------------------

- (IBAction)exitClicked:(id)sender
{
//    close(self.usb);
    [NSApp terminate:nil];
}

// ------------------------------------------------------------------------------------------------

- (IBAction)nextCellClicked:(id)sender
{
    [self sendCommand:@CMD_NEXTCELL];
}

// ------------------------------------------------------------------------------------------------

- (IBAction)pingClicked:(id)sender
{
    [self sendCommand:@CMD_PING];
}

// ------------------------------------------------------------------------------------------------

- (IBAction)rewindClicked:(id)sender
{
    [self sendCommand:@CMD_REWIND];
}

// ------------------------------------------------------------------------------------------------

- (IBAction)optoClicked:(id)sender
{
    // TODO: uncomment this again. I'm just quickly hijacking this function to test photo capture
    //[self sendCommand:@CMD_TESTOPTO];
    
    [self photoCapture];
}

// ------------------------------------------------------------------------------------------------

- (void)enableButtons:(BOOL)doEnable
{
    [self appendOutput:[NSString stringWithFormat:@"enableButtons [%@]\n", doEnable ? @"YES" : @"NO"]];

    _btnRewind.enabled = doEnable;
    _btnPing.enabled = doEnable;
    _btnCheckSensor.enabled = doEnable;
    _btnNextCell.enabled = doEnable;
}

// ------------------------------------------------------------------------------------------------

- (void)photoCapture
{
    self.camera = [[CameraCapture alloc] init];

    [self.camera capturePhotoWithCompletion:^(NSData *imageData) {
        if (imageData)
        {
            NSString *path = [NSTemporaryDirectory()
                stringByAppendingPathComponent:@"photo.jpg"];

            [imageData writeToFile:path atomically:YES];
            NSLog(@"Saved photo to %@", path);
            [self appendOutput:[NSString stringWithFormat:@"Saved photo to: %@\n", path]];
        }

        // Optional: release after capture
        self.camera = nil;
    }];

}

// ------------------------------------------------------------------------------------------------

/*
 Start the photo scanning thread. We run this in a thread because we don't want to block the user
 interface while the very lengthy scan is running.
 */
- (void)startScanThread
{
    self.scanThreadRunning = YES;

    __block NSInteger scansRemaining = _appSettings.cellsToRead;
    __block BOOL waitingForScannerResponse = NO;        // true if we have sent a command and are waiting for a scanner reply

    // disable the buttons we don't want active while we're scanning.
    [self enableButtons:FALSE];
    [_btnStartScan setTitle:@"Stop Scan"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while(self.scanThreadRunning)
        {
            // have we received a shut down signal?
            if (!self.scanThreadRunning)
                break;

            if (!waitingForScannerResponse)
            {
                usleep(1000000);    // 1 second pause. TODO: Remove this again! This is just to test the enable/disable button feature
                
                if (--scansRemaining < 1)
                {
                    self.scanThreadRunning = NO;
                    break;  // stop processing and close this thread again.
                }
                
                @synchronized(self.serialManager)
                {
                    if (self.serialManager.scannerIsReady)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{ [self sendCommand:@CMD_NEXTCELL]; });
                        waitingForScannerResponse = YES;
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{ [self appendOutput:@"\nError: Scanner is not ready."]; });
                        break;
                    }
                }
            }
            else
            {
                usleep(500000);    // half a second pause. TODO: Remove this again! This is just to test the enable/disable button feature
                
                @synchronized(self.serialManager)
                {
                    // TODO : obviously remove the logging messages again and instead launch the photo capture
                    if ((self.serialManager.scannerAtCell) && (self.serialManager.scannerOk))
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self appendOutput:[NSString stringWithFormat:@"Scanner is at cell. We have %li scans remaining.\n", scansRemaining - 1]];
                        });
                        waitingForScannerResponse = false;
                    }
                    else
                        dispatch_async(dispatch_get_main_queue(), ^{ [self appendOutput:@"--- still waiting for scanner\n"]; });

                    
                    // TODO: also handle scannerTimeout and scannerError
                }
            }
            
            /*
             TODO:
             - 1. wait until we've received an "AtCell" projector response (or a timeout)
             - 2. Run a photo capture (and trigger a display of that photo on the screen)
             - 3. Once capture is done, send a "NextCell" command
             - 4. Also deduct from the loop counter so we can halt when the required scans have been done.
             - Make sure none of the above block the thread for too long. We want to be able to have the user click on "Stop" and process this.

             - Do we need the below? :
                    dispatch_semaphore_wait(self.receiveSemaphore, DISPATCH_TIME_FOREVER);
            */
        }
        
        // Scanning has ended. Re-enable the buttons again.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enableButtons:TRUE];
            [self->_btnStartScan setTitle:@"Start Scan"];
        });
    });
    
}

// ------------------------------------------------------------------------------------------------
/*
- (void)startUSBReaderThread
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char readBuf[256];

        while (1)
        {
            ssize_t bytesRead = read(self.usb, readBuf, sizeof(readBuf));
            if (bytesRead > 0)
            {
                @synchronized(self.rawBuffer)
                {
                    [self.rawBuffer appendBytes:readBuf length:bytesRead];

                    while (1)
                    {
                        const char *bytes = self.rawBuffer.bytes;
                        NSUInteger len = self.rawBuffer.length;

                        char *newline = memchr(bytes, '\n', len);
                        if (!newline) break;

                        NSUInteger lineLen = newline - bytes;

                        NSData *lineData = [NSData dataWithBytes:bytes length:lineLen];
                        NSString *line = [[NSString alloc] initWithData:lineData                                                       encoding:NSUTF8StringEncoding];

                        if (line)
                        {
                            @synchronized(self.receiveBuffer)
                            {
                                [self.receiveBuffer enqueue:line];
                                
                                // let the receive handler know that we've received something it may want to process
                                dispatch_semaphore_signal(self.receiveSemaphore);
                            }

                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self appendOutput:[NSString stringWithFormat:@"RX: %@\n", line]];
                            });
                        }

                        [self.rawBuffer replaceBytesInRange:NSMakeRange(0, lineLen + 1)
                                                 withBytes:NULL
                                                    length:0];
                    }
                }
            }
        }
    });
}
*/

// ------------------------------------------------------------------------------------------------

typedef NS_ENUM(NSInteger, LEDState)
{
    LEDStateOff,
    LEDStateRed,
    LEDStateGreen
};

- (void)setLEDState:(LEDState)state imgName:(NSImageView *)imgLED
{
    NSString *imageName = @"";
    switch (state) {
        case LEDStateOff:   imageName = @"LED_Gray";  break;
        case LEDStateRed:   imageName = @"LED_Red";   break;
        case LEDStateGreen: imageName = @"LED_Green"; break;
    }
    imgLED.image = [NSImage imageNamed:imageName];
}

// ------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------

@end
