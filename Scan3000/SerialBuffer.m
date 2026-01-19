//
//  SerialBuffer.m
//  FIFO buffer that holds data read via the USB serial port until it can be processed. We
//  use a SerialData object that contains both, the raw text as well as an interpreted type
//  of the response in the buffer.
//
//  Created by Pius Ott on 3/12/2024.
//  Copyright © 2024 Worlddom. All rights reserved.
//

#import "SerialBuffer.h"
#import "ArduinoResponse.h"

// -------------------------------------------------------------------------------------------

@implementation SerialData
// nothing to do.
@end

// -------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------

@implementation SerialBuffer

// -------------------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _buffer = [NSMutableArray array];
    }
    return self;
}

// -------------------------------------------------------------------------------------------

- (void)enqueue:(NSString *)str
{
    SerialData *newData = [SerialData new];
    newData.plainText = str;
    
    if ([str isEqualToString:@CMD_OK])
        newData.command = cmdOk;
    else if ([str isEqualToString:@RSP_ERR])
        newData.command = cmdErr;
    else if ([str isEqualToString:@CMD_READY])
        newData.command = cmdReady;
    else if ([str isEqualToString:@CMD_ATCELL])
        newData.command = cmdAttCell;
    else
        newData.command = cmdUnknown;    // usually logging data from the projector
    // TODO: we should probably also detect log messages separately rather than just flagging them as unknowns
    
    [self.buffer addObject:newData];
}

// -------------------------------------------------------------------------------------------

- (SerialData *)dequeue
{
    if ([self isEmpty])
    {
        return nil; // Return nil if the buffer is empty
    }
    
    SerialData *firstItem = self.buffer[0];
    [self.buffer removeObjectAtIndex:0];
    return firstItem;
}

// -------------------------------------------------------------------------------------------

- (NSUInteger)size
{
    return self.buffer.count;
}

// -------------------------------------------------------------------------------------------

- (BOOL)isEmpty
{
    return self.buffer.count == 0;
}

// -------------------------------------------------------------------------------------------

@end



