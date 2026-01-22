//
//  SerialManager.h
//  Scan3000
//
//  Created by Pius Ott on 14/1/2026.
//

#import <Foundation/Foundation.h>
#import "AppSettings.h"

@class SerialBuffer;

extern NSString * const SerialDidReceiveLineNotification;
extern NSString * const SerialLineKey;

@interface SerialManager : NSObject

@property (nonatomic, assign) int usb;      // file handle for the opened USB port
@property (nonatomic, weak) AppSettings *appSettings;           // contains application settings

@property (nonatomic, strong) NSMutableData *rawBuffer;         // holds unprocessed data received via USB
@property (nonatomic, strong) SerialBuffer *receiveBuffer;      // unprocessed but complete text lines received via USB
@property (strong) dispatch_semaphore_t receiveSemaphore;
@property (atomic, assign) BOOL responseThreadRunning;
@property (atomic, assign) BOOL usbReadThreadRunning;

// these are flags set when we've received corresponding responses from the scanner. Once each response has been
// handled, we clear it
@property (nonatomic, assign) BOOL scannerIsReady;
@property (nonatomic, assign) BOOL scannerAtCell;
@property (nonatomic, assign) BOOL scannerOk;
@property (nonatomic, assign) BOOL scannerTimeout;
@property (nonatomic, assign) BOOL scannerError;

- (void)start;
- (void)stop;
- (void)notifyView:(NSString *)displayText;

- (NSString *)sendCommand:(NSString *)cmd;

@end

