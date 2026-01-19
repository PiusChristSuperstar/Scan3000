//
//  SerialBuffer.h
//  FIFO buffer that holds data read via the USB serial port until it can be processed
//
//  Created by Pius Ott on 3/12/2024.
//  Copyright © 2024 Worlddom. All rights reserved.
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ScannerResponse)
{
    cmdOk,
    cmdErr,
    cmdReady,
    cmdAttCell,
    cmdLog,
    cmdUnknown
};


// The data object that will be stored in the buffer.
@interface SerialData : NSObject
@property (nonatomic) ScannerResponse command;          // the interpreted scanner response command
@property (nonatomic, copy) NSString *plainText;        // the plain text as received.
@end

@interface SerialBuffer : NSObject
@property (nonatomic, strong) NSMutableArray<SerialData *> *buffer;

- (void)enqueue:(NSString *)string;  // Decipher if the data is a valid projector instruction and if so, add to the end of the buffer
- (SerialData *)dequeue;             // Remove and return the data at the front
- (NSUInteger)size;                  // Get the number of elements in the buffer
- (BOOL)isEmpty;

@end
