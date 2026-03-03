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
#import "OlympusCamera/OlympusCam.h"
#import "Utilities.h"

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
    self.previewView.wantsLayer = YES;      // allow camera preview
    
    AppDelegate *appDelegate = (AppDelegate *)NSApp.delegate;
    self.serialManager = appDelegate.serialManager;
    self.appSettings = appDelegate.appSettings;

    // Observer that handles received text from the serial manager that we need to display
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(serialDidReceiveLine:)
               name:SerialDidReceiveLineNotification
             object:nil];

    // Observer that handles received text from the camera handler that we need to display
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(cameraDidReceiveLine:)
               name:CameraInfoNotification
             object:nil];
    
    // Observer that handles call to shut down the application
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(appWillTerminate:)
               name:NSApplicationWillTerminateNotification
             object:nil];
    
    // Observer that handles serial port status notifications
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(serialStatusChange:)
               name:PortChangedStateNotification
             object:nil];

    [self setLEDState:LEDStateOff imgName:_commsLED];
    [self setLEDState:LEDStateRed imgName:_cmdLED];

    if ([Utilities createPathIfNotExist:self.appSettings.imagePath] == FALSE)
        [self appendOutput:[NSString stringWithFormat:@"\n** Warning **\nImage path could not be created [%@]\n", self.appSettings.imagePath]];

    // Ideally I'd use an object oriented model with a common baseclass, but it looks like webcams are so completely
    // different to communicate with compared to Olympus cams, I'm just using two entirely different objects which
    // means the code is full of ugly if/else sections. Once I have both models running, I might revisit that to
    // clean it up as best as I can.
    if (self.appSettings.useOlympusCam)
    {
        self.olympusCam = [[OlympusCam alloc] init];
        [self.olympusCam DetectCameras];
    }
    else
    {
        // initialise and turn on camera so we can run a preview screen.
        self.camera = [[CameraCapture alloc] init];
        [self.camera startSession:_appSettings.cameraResolution];   // start camera preview session
        [self.camera attachPreviewToView:self.previewView];
    }
    
    NSLog(@"Button pointer: %@", _btnOpenPort);
    _btnOpenPort.enabled = false;   // will be enabled when we receive a disconnect notification
 }

// ------------------------------------------------------------------------------------------------

- (void)viewDidLayout
{
    [super viewDidLayout];

    if (self.appSettings.useOlympusCam)
    {
        
    }
    else
    {
        self.camera.previewLayer.frame = self.previewView.bounds;
    }
}

// ------------------------------------------------------------------------------------------------

- (void)appWillTerminate:(NSNotification *)note
{
    // close the threads that may still be running.
    self.scanThreadRunning = YES;
    
    if (self.appSettings.useOlympusCam)
    {
        [self.olympusCam CameraExit];
    }
    else
    {
        [self.camera stopSession];
    }
}

// ------------------------------------------------------------------------------------------------

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

// ------------------------------------------------------------------------------------------------

- (void)serialStatusChange:(NSNotification *)note
{
    // TODO : add an "Open port" button and enable/disable this based on the port status we receive.
    
    NSDictionary *userInfo = note.userInfo;
    // Extract the NSNumber and get its boolean value
    BOOL isOpen = [userInfo[PortChangedStateKey] boolValue];
    
    if (isOpen)
    {
        [self setLEDState:LEDStateGreen imgName:_commsLED];
        
        [self appendOutput:@"Monitoring USB input...\n\n"];
        NSLog(@"The port is now open.");
        _btnOpenPort.enabled = false;
    }
    else
    {
        [self setLEDState:LEDStateRed imgName:_commsLED];

        [self appendOutput:@"USB port has been closed\n"];
        NSLog(@"The port is now closed.");
        _btnOpenPort.enabled = true;
    }
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

// ------------------------------------------------------------------------------------------------

- (void)cameraDidReceiveLine:(NSNotification *)note
{
    NSString *line = note.userInfo[CameraInfoKey];
    
    [self appendOutput:[NSString stringWithFormat:@"%@\n", line]];  // display in textview
}

// ------------------------------------------------------------------------------------------------

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
    
    if (_appSettings.lastError.length > 0)
    {
        [self appendOutput:[NSString stringWithFormat:@"\n---- Configuration Error ----\n%s\n------------", [_appSettings.lastError UTF8String]]];
    }
    
    [self appendOutput:[NSString stringWithFormat:@"\n\tConfiguration File\t\t: %s", [_appSettings.configFile.absoluteString UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCells To Read\t\t\t: %li", _appSettings.cellsToRead]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCapture Pause\t\t\t: %li", _appSettings.capturePause]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tUSB Port\t\t\t\t: %s", [_appSettings.usbPortName UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tLog File\t\t\t\t: %s", [_appSettings.logFileName UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCaptured Image Location\t: %s", [_appSettings.imagePath UTF8String]]];
    if (_appSettings.useOlympusCam == TRUE)
    {
        [self appendOutput:@"\n\tCamera used\t\t\t: Olympus"];
    }
    else
    {
        [self appendOutput:@"\n\tCamera used\t\t\t: Webcam"];
    }
    
    [self appendOutput:[NSString stringWithFormat:@"\n\tWeb camera Resolution\t: %d x %d\n\n", (int)_appSettings.cameraResolution.width, (int)_appSettings.cameraResolution.height]];
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
    }
    else
    {
        [self startScanThread];
    }
    // TODO: We should really display the last scanned image too.
}

// ------------------------------------------------------------------------------------------------

- (IBAction)exitClicked:(id)sender
{
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
    [self sendCommand:@CMD_TESTOPTO];
}

// ------------------------------------------------------------------------------------------------

- (IBAction)takePhotoClicked:(id)sender
{
    if (self.appSettings.useOlympusCam)
    {
        [self.olympusCam CaptureImage];
    }
    else
    {
        [self photoCapture];
    }
}

// ------------------------------------------------------------------------------------------------

- (IBAction)openPortClicked:(id)sender
{
    [_serialManager start];
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
    [self.camera capturePhotoWithCompletion:^(NSData *imageData) {
        if (imageData)
        {
            // We save the images with a preceding date and time in the file name so we can easily
            // sort them by sequence taken to later combine them into a movie.
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
            NSString *timestamp = [formatter stringFromDate:[NSDate date]];
            NSString *fileName = [NSString stringWithFormat:@"%@_scan.jpg", timestamp];
            NSString *fullPath = [self.appSettings.imagePath stringByAppendingPathComponent:fileName];
            NSString *expandedPath = [fullPath stringByExpandingTildeInPath];
            
            // TODO: we should check that the path exists and we actually have write access to it.
            //       for the moment the app only has access to the ~/Pictures and its ~/Library/Containers/[Your-Bundle-ID]
            //       paths. If we can't save the file, the app just fails silently at the moment.
            //       It would probably be saver and easier if we just default to using the Pictures path and create a
            //       'Scan3000' directory in it and always save the images there.
            [imageData writeToFile:expandedPath atomically:YES];
            NSLog(@"Saved photo to %@", expandedPath);
            [self appendOutput:[NSString stringWithFormat:@"Saved photo to: %@\n", expandedPath]];
        }
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
                usleep(500000);    // half a second pause. TODO: This doesn't seem an ideal solution, but without it this thread uses lots of CPU.
                
                /*
                 - The projector has been given an instruction to move to the next cell. So the procedure from here is as follows (not everything has been fully implemented yet)
                 - 1. We wait until we've received an "AtCell" response from the projector (or a timeout)
                 - 2. Run a photo capture and trigger a display of that photo on the screen
                 - 3. Once capture is done, send a "NextCell" command to start the projector again
                 - 4. Also deduct from the loop counter so we can halt when the required scans have been done.
                 - Make sure none of the above block the thread for too long. We want to be able to have the user click on "Stop" and process this.
                */

                @synchronized(self.serialManager)
                {
                    // TODO : The logging message can be removed once I'm happy with how it all runs
                    if ((self.serialManager.scannerAtCell) && (self.serialManager.scannerOk))
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self appendOutput:[NSString stringWithFormat:@"Scanner is at cell. We have %li scans remaining.\n", scansRemaining - 1]];
                        });
                        
                        // we're in position, take a photo and save it to a file.
                        [self photoCapture];
                        waitingForScannerResponse = false;
                    }
                    else
                        dispatch_async(dispatch_get_main_queue(), ^{ [self appendOutput:@"--- still waiting for scanner\n"]; });

                    
                    // TODO: also handle scannerTimeout and scannerError
                }
            }
        }
        
        // Scanning has ended. Re-enable the buttons again.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self enableButtons:TRUE];
            [self->_btnStartScan setTitle:@"Start Scan"];
        });
    });
    
}

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
