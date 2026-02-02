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
#import <IOKit/IOKitLib.h>
#import <IOKit/serial/IOSerialKeys.h>

#import "SerialManager.h"
#import "SerialBuffer.h"
#import "ArduinoResponse.h"

// Keys for notifications we're sending out to observers
NSString * const SerialDidReceiveLineNotification = @"SerialDidReceiveLineNotification";
NSString * const SerialLineKey = @"SerialLineKey";
NSString * const PortChangedStateNotification = @"PortChangedStateNotification";
NSString * const PortChangedStateKey = @"PortChangedStateKey";

// -------------------------------------------------------------------------------------------

/*
 Callback method that is called when the USB port closes. E.g. the cable is being unplugged
 or there is an error.
 */
static void DeviceDisconnectedCallback(void *refCon, io_iterator_t iterator)
{
    // Get a pointer to the instance of this serialManager
    SerialManager *mgrInstance = (__bridge SerialManager *)refCon;
    
    io_object_t device;
    // 2. You MUST iterate through the iterator to "arm" the next notification
    while ((device = IOIteratorNext(iterator)))
    {
        // You can get device info here if needed, but for disconnects,
        // we usually just release the object.
        IOObjectRelease(device);
    }
    
    // 3. Tell your instance to handle the cleanup
    [mgrInstance handleDisconnect];
}

@implementation SerialManager

// -------------------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.usb = -1;      // file descriptor. If this is > 0 then the port is currently open.
        self.receiveBuffer = [[SerialBuffer alloc] init];
        self.rawBuffer = [NSMutableData data];
        self.receiveSemaphore = dispatch_semaphore_create(0);   // will be flagged when we receive data from projector
        
        
        // Inside your startMonitoring method:
        IONotificationPortRef notifyPort = IONotificationPortCreate(kIOMainPortDefault);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPort), kCFRunLoopDefaultMode);

        // Create a matching dictionary for your device
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOSerialBSDServiceValue);

        // We want to know if the port is being disconnected while we're using it. So register to receive port disconnection notifications
        io_iterator_t portIterator;
        kern_return_t kr = IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, matchingDict,
                                         DeviceDisconnectedCallback, (__bridge void *)(self), &portIterator);
        
        // EXHAUST the iterator to "arm" the notification
        if (kr == KERN_SUCCESS)
        {
            io_object_t device;
            while ((device = IOIteratorNext(portIterator)))
            {
                // We release each object found to avoid memory leaks
                IOObjectRelease(device);
            }
        }
    }
    return self;
}

// -------------------------------------------------------------------------------------------

- (void)handleDisconnect
{
    if (self.usb != -1)
    {
        close(self.usb);
        self.usb = -1;
    }

    // stop the reader threads
    [self stopResponseReaderThread];
    [self stopUsbReadThread];
    
    // Post the changed port state to the UI
    [self notifyCommsState:self.isPortOpen];
}

// -------------------------------------------------------------------------------------------

- (BOOL)isPortOpen
{
    return (self.usb > 0);  // true while port is open.
}

// -------------------------------------------------------------------------------------------

- (void)start
{
    if ([self isPortOpen] == YES)
    {
        [self notifyView: @"Port is already open"];
        return;
    }
    
    // clear all scanner state flags
    self.scannerIsReady = false;
    self.scannerAtCell = false;
    self.scannerOk = false;
    self.scannerTimeout = false;
    self.scannerError = false;
    
    // start USB thread, reader thread, etc
    self.usb = [self openSerialPort: _appSettings.usbPortName];
    [self notifyCommsState:self.isPortOpen];
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

// send a message to the ViewController to allow it to indicate the current port state
- (void)notifyCommsState:(BOOL)isPortOpen
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PortChangedStateNotification
         object:self
         userInfo:@{ PortChangedStateKey : @(isPortOpen) }];  // need to box that into a number because BOOL can't be sent.
    });
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

// -------------------------------------------------------------------------------------------

- (void)stop
{
    [self stopResponseReaderThread];

    [self stopUsbReadThread];
    
    // close the serial port again
    int flags = fcntl(self.usb, F_GETFL);
    flags &= ~O_NONBLOCK;
    fcntl(self.usb, F_SETFL, flags);      // flush the buffer, reset terminal settings and re-set blocking mode before closing
    if (self.usb != -1)
    {
        close(self.usb);
        self.usb = -1; // Reset to prevent double-closing
    }
    
    [self notifyCommsState:self.isPortOpen];
}

// -------------------------------------------------------------------------------------------

- (NSString *)sendCommand:(NSString *)cmd;
{
    // clear appropriate scanner state flags
    self.scannerAtCell = false;
    self.scannerOk = false;
    self.scannerTimeout = false;
    self.scannerError = false;
    
    if ([self isPortOpen] == NO)
        return @"USB port is no longer open\n";

    ssize_t numBytes = write(self.usb, [cmd UTF8String], cmd.length);
    if (numBytes == -1)
    {
        return [NSString stringWithFormat:@"USB write error: %s\n", strerror(errno)];
    }
    return NULL;
}

// ------------------------------------------------------------------------------------------------

- (int) openSerialPort:(NSString *)devicePath;
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

- (BOOL)isPortStillValid
{
    if (self.usb < 0)
        return NO;
    
    // F_GETFL is the cheapest call to check if the kernel still "owns" this fd
    int result = fcntl(self.usb, F_GETFL);
    if ((result == -1) && (errno == EBADF))
    {
        return NO; // Hardware was disconnected or port was closed
    }
    return YES;
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
    self.usbReadThreadRunning = TRUE;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char readBuf[256];
        
        while (self.usbReadThreadRunning)
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
            
            // have we received a shut down signal?
            if (!self.usbReadThreadRunning)
                break;
        }
    });
}

// ------------------------------------------------------------------------------------------------

- (void) stopUsbReadThread
{
    // Tell the thread to exit
    self.usbReadThreadRunning = NO;
}

// ------------------------------------------------------------------------------------------------

/*
 Thread that checks the serial buffer and interprets the responses we may have received from the scanner.
 */
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
            
            SerialData *dataItem = nil;
            @synchronized(self.receiveBuffer)
            {
                if (self.receiveBuffer.size > 0)
                {
                    dataItem = [self.receiveBuffer dequeue];
                }
            }

            if (!dataItem)
                continue;
            
            switch (dataItem.command)
            {
                case cmdOk:
                    self.scannerOk = true;
                    break;
                    
                case cmdErr:
                    self.scannerTimeout = true;
                    self.scannerError = true;
                    break;
                    
                case cmdReady:
                    self.scannerIsReady = true;
                    break;
                    
                case cmdAttCell:
                    self.scannerAtCell = true;
                    break;
                    
                case cmdLog:
                case cmdUnknown:
                    // For the time being, we don't handle these since we don't need them. However in
                    // the future we should probably at least log them.
                    break;
            }
        }
    });
}

// ------------------------------------------------------------------------------------------------

@end
