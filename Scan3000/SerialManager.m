//
//  SerialManager.m
//  Scan3000
//
//  Handles reading the serial data
//
//  Created by Pius Ott on 14/1/2026.
//

#import <termios.h>

#import <Foundation/Foundation.h>
#import "SerialManager.h"
#import "SerialBuffer.h"
#import "ArduinoResponse.h"


NSString * const SerialDidReceiveLineNotification = @"SerialDidReceiveLineNotification";
NSString * const SerialLineKey = @"SerialLineKey";


@implementation SerialManager

// -------------------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        
        self.receiveBuffer = [[SerialBuffer alloc] init];
        self.rawBuffer = [NSMutableData data];
        self.receiveSemaphore = dispatch_semaphore_create(0);   // will be flagged when we receive data from projector

    }
    return self;
}

// -------------------------------------------------------------------------------------------

- (void)start
{
    // start USB thread, reader thread, etc
    self.usb = openSerialPort(_appSettings.usbPortName);
    if (self.usb == -1)
    {
        [self notifyView: @"Failed to open USB port\n"];

        return;
    }

    [self notifyView: [NSString stringWithFormat:@"Opened USB port [%@]\n", _appSettings.usbPortName]];

    [self startUSBReaderThread];
    [self startResponseReaderThread];            // start the thread that interprets responses we've received from the projector
}

// -------------------------------------------------------------------------------------------

// send a message to the ViewController that we have something we want it to display or handle
- (void)notifyView:(NSString *)displayText
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:SerialDidReceiveLineNotification
            object:self
            userInfo:@{ SerialLineKey : displayText }];
    });
}

- (void)stop
{
    // signal semaphores, stop threads cleanly
}

// -------------------------------------------------------------------------------------------

- (NSString *)sendCommand:(NSString *)cmd;
{
    ssize_t numBytes = write(self.usb, [cmd UTF8String], cmd.length);
    if (numBytes == -1)
    {
        return [NSString stringWithFormat:@"USB write error: %s\n", strerror(errno)];
    }
    return NULL;
}

// ------------------------------------------------------------------------------------------------

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
    
- (void) stopResponseReaderThread
{
    // 1) Tell the thread to exit
    self.responseThreadRunning = NO;

    // 2) Wake it up if it's blocked
    dispatch_semaphore_signal(self.receiveSemaphore);
}

// ------------------------------------------------------------------------------------------------

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

                            // let the ViewController know that we have data to display.
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter]
                                    postNotificationName:SerialDidReceiveLineNotification
                                    object:self
                                    userInfo:@{ SerialLineKey : line }];
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
                /*
                 TODO : send notification to ViewController
                 
                dispatch_async(dispatch_get_main_queue(), ^{ [self setLEDState:LEDStateGreen imgName:self->_cmdLED]; });
                */
                
                /*
                TODO: we need to handle each of the three responses separately
                 CMD_OK - clear a flag that will be set whenever we launch a command to let us know it has been handled successfully
                 CMD_READY - set a global 'projector ready' flag
                 CMD_ATCELL - increase a counter of cells handled
                            - take a photo
                 */
            }
            else if ([line isEqualToString:@RSP_ERR])   // Error response. Will be followed by an error code or text
            {
                /*
                 TODO : send notification to ViewController
                 
                dispatch_async(dispatch_get_main_queue(), ^{ [self setLEDState:LEDStateRed imgName:self->_cmdLED]; });
                 */
            }
        }
    });
}

// ------------------------------------------------------------------------------------------------

@end
