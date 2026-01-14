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

// TODO : I don't think this is needed anymore
static NSString *gLastError = @"";      // most recent error message

@implementation ViewController

// ------------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
   
    
/*
    ssize_t numBytes = write(self.usb, cmd, strlen(cmd));
    if (numBytes == -1)
    {
        NSString *err = [NSString stringWithFormat:@"USB write error: %s\n", strerror(errno)];
        [self appendOutput:err];
    }
    else
    {
        [self appendOutput:[NSString stringWithFormat:@"Sent: %s\n", cmd]];
    }
 */
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
}

// ------------------------------------------------------------------------------------------------

- (IBAction)showSerialBufferClicked:(id)sender
{
    // TODO : this was just a test function and can be removed.
    /*
    @synchronized (self.serialManager.receiveBuffer)
    {
        [self appendOutput:[NSString stringWithFormat:
            @"SerialBuffer size: %lu\n", self.serialManager.receiveBuffer.size]];

        while (self.serialManager.receiveBuffer.size > 0)
        {
            NSString *line = [self.serialManager.receiveBuffer dequeue];
            [self appendOutput:[NSString stringWithFormat:@"[%@]\n", line]];
        }
    }*/
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
    [self sendCommand:@CMD_TESTOPTO];
}

// ------------------------------------------------------------------------------------------------
/*
- (void) stopResponseReaderThread
{
    // 1) Tell the thread to exit
    self.responseThreadRunning = NO;

    // 2) Wake it up if it's blocked
    dispatch_semaphore_signal(self.receiveSemaphore);
}

- (void) stopUSBReaderThread
{
    
}

- (void)startResponseReaderThread
{
    self.responseThreadRunning = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while(self.responseThreadRunning)
        {
            // 🔴 Block until data is available
            dispatch_semaphore_wait(self.receiveSemaphore, DISPATCH_TIME_FOREVER);

            // have we received a shut down signal?
            if (!self.responseThreadRunning)
                break;
            
            NSString *line = nil;

            @synchronized(self.receiveBuffer)
            {
                if (self.receiveBuffer.size > 0)
                    line = [self.receiveBuffer dequeue];
            }

            if (!line)
                continue;

            if ([line isEqualToString:@CMD_OK] ||       // Acknowledgement. Sent as a response to each command
                [line isEqualToString:@CMD_READY] ||    // Sent when the Arduino is ready to receive instructions
                [line isEqualToString:@CMD_ATCELL])     // The film has been positioned and is ready for a photo capture
            {
                dispatch_async(dispatch_get_main_queue(), ^{ [self setLEDState:LEDStateGreen imgName:self->_cmdLED]; });
                

            }
            else if ([line isEqualToString:@RSP_ERR])   // Error response. Will be followed by an error code or text
            {
                dispatch_async(dispatch_get_main_queue(), ^{ [self setLEDState:LEDStateRed imgName:self->_cmdLED]; });
            }
        }
    });
}
*/
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
