//
//  ViewController.m
//  Scan3000
//
//  Created by Pius Ott on 9/1/2026.
//

#include <termios.h>

#import "ViewController.h"
#import "SerialBuffer.h"
#import "Utilities.h"
#import "ArduinoResponse.h"

// The file that holds the instructions and configuration for our app
#define SETTINGS_FILE "/Users/Pius/dev/XCode/ModemCommTest/settings.xcconfig"

// TODO: these should move to a class or the header.
static NSString *gLastError = @"";      // most recent error message

// settings values, initialised to default but can be overridden by values found in the SETTINGS_FILE
static NSInteger gCellsToRead = 10;             // how many film cells to scan. This is just used for testing during development
static NSString *gUsbPort = @"/dev/cu.usbserial-0001";  // USB port to communicate with the Arduino

static NSString *gLogName = @"ScanBrain.log";           // Log file to use. Filename only. Log file will be in the Documents folder

static NSString *gImageLocation = @"~/ScanBrain/Images";    // Location of where to store the captured photos

static NSInteger gCapturePause = 2;     // How long to pause (in seconds) after sending Arduino instructions. This gives the
                                        // Arduino time to process what has been received. But I'm also using this during development
                                        // to simulate a delay during the photo capture


@implementation ViewController

// ------------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self appendOutput:@"Text view connected successfully\n"];
    
    readSettings();

    self.receiveBuffer = [[SerialBuffer alloc] init];
    self.rawBuffer = [NSMutableData data];

    self.usb = openSerialPort(gUsbPort);
    if (self.usb == -1)
    {
        [self appendOutput:@"Failed to open USB port\n"];
        return;
    }

    [self appendOutput:@"USB Reader App Running...\n"];
    [self appendOutput:@"Monitoring USB input...\n\n"];

    [self startUSBReaderThread];
}

// ------------------------------------------------------------------------------------------------

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

// ------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------

// Function to open USB serial port
int openSerialPort(NSString *devicePath)
{
    int fd = open([devicePath UTF8String], O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd == -1)
    {
        perror("Unable to open serial port");
        return -1;
    }

    struct termios options;
    tcgetattr(fd, &options);
    cfsetispeed(&options, B9600);
    cfsetospeed(&options, B9600);
    options.c_cflag |= (CLOCAL | CREAD);
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;

    tcsetattr(fd, TCSANOW, &options);
    return fd;
}

// ------------------------------------------------------------------------------------------------

/// Display the current settings. This is just a cheapo way to avoid implementing a proper settings feature. All settings for the time being
/// need to be manually changed through editing the settings file.
- (void)showSettings
{
    [self appendOutput:@"\n=== Settings ===\n"];
    [self appendOutput:@"\nNote that for the time being, settings can only be changed through the config file.\n"];
    [self appendOutput:@"\n\tConfiguration File     : %s"];

    [self appendOutput:[NSString stringWithFormat:@"\n\tConfiguration File     : %s", [@SETTINGS_FILE UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCells To Read          : %li", gCellsToRead]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCapture Pause          : %li", gCapturePause]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tUSB Port               : %s", [gUsbPort UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tLog File               : %s", [gLogName UTF8String]]];
    [self appendOutput:[NSString stringWithFormat:@"\n\tCaptured Image Location: %s\n\n", [gImageLocation UTF8String]]];
    // TODO: maybe add an option to re-load settings file?
}

- (void)appendOutput:(NSString *)text
{
    NSTextStorage *storage = self.outputTextView.textStorage;
    [storage appendAttributedString:[[NSAttributedString alloc] initWithString:text]];
    [self.outputTextView scrollRangeToVisible:NSMakeRange(storage.length, 0)];
}

- (IBAction)showSettingsClicked:(id)sender
{
    [self showSettings];
    [self appendOutput:@"Settings displayed\n"];
}

- (IBAction)nextCellClicked:(id)sender
{
    ssize_t numBytes = write(self.usb, CMD_NEXTCELL, strlen(CMD_NEXTCELL));
    if (numBytes == -1)
    {
        NSString *err = [NSString stringWithFormat:@"USB write error: %s\n", strerror(errno)];
        [self appendOutput:err];
    }
    else
    {
        [self appendOutput:@"Sent CMD_NEXTCELL\n"];
    }
}

- (IBAction)showSerialBufferClicked:(id)sender
{
    @synchronized (self.receiveBuffer)
    {
        [self appendOutput:[NSString stringWithFormat:
            @"SerialBuffer size: %lu\n", self.receiveBuffer.size]];

        while (self.receiveBuffer.size > 0)
        {
            NSString *line = [self.receiveBuffer dequeue];
            [self appendOutput:[NSString stringWithFormat:@"[%@]\n", line]];
        }
    }
}

- (IBAction)exitClicked:(id)sender
{
    close(self.usb);
    [NSApp terminate:nil];
}


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
                        NSString *line = [[NSString alloc] initWithData:lineData
                                                               encoding:NSUTF8StringEncoding];

                        if (line)
                        {
                            @synchronized(self.receiveBuffer)
                            {
                                [self.receiveBuffer enqueue:line];
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

// ------------------------------------------------------------------------------------------------

/// Load the configuration settings. If no file is defined, or the file could not be opened, we just use default values.
static void readSettings(void)
{
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:@SETTINGS_FILE encoding:NSUTF8StringEncoding error:&error];

    if (error)
    {
        NSLog(@"Error reading config file: [%@] - using default configurations instead", error.localizedDescription);
        return;
    }

    // split all lines into an array
    NSArray *configLines = [fileContents componentsSeparatedByString:@"\n"];
    
    for (int i = 0; i < configLines.count; i++)
    {
        if ([configLines[i] hasPrefix:@"//"])
        {
            // Comment line, ignore it
        }
        else
        {
            NSArray *components = [configLines[i] componentsSeparatedByString:@"="];
            
            // Ensure there are exactly two components
            if (components.count == 2)
            {
                NSString *settingName = [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *valueWithQuotes = components[1];
                
                // Strip the single quotes and line end from the value
                NSString *settingValue = [valueWithQuotes stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\n"]];
                
                NSLog(@"Setting: %@, Value: %@\n", settingName, settingValue);
                if ([settingName isEqualToString:@"CELLS_TO_READ"])
                {
                    gCellsToRead = [Utilities getNumberFromString:settingValue];
                }
                else if ([settingName isEqualToString:@"CAPTURE_PAUSE"])
                {
                    gCapturePause = [Utilities getNumberFromString:settingValue];
                }
                else if ([settingName isEqualToString:@"USB_PORT"])
                {
                    gUsbPort = settingValue;
                }
                else if ([settingName isEqualToString:@"LOGFILE_NAME"])
                {
                    gLogName = settingValue;
                }
                else if ([settingName isEqualToString:@"IMAGE_LOCATION"])
                {
                    gImageLocation = settingValue;
                }
            }
            else
            {
                //NSLog(@"The input string [%@] is invalid", configLine);
            }
        }
    }
}

// ------------------------------------------------------------------------------------------------

@end
