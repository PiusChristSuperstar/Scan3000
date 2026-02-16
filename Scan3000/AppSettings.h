//
//  AppSettings.h
//  Scan3000
//
//  Holds Application Settings data. For the moment, this is read from a xconfig file and cannot be
//  changed at runtime, so needs to be manually edited in that file. Something to implement in
//  the future...
//
//  Created by Pius Ott on 14/1/2026.
//

@interface AppSettings : NSObject;

@property (nonatomic, readonly) NSString *configFile;   // Configuration filename and path
@property (nonatomic, readonly) NSString *lastError;    // most recent error message
@property (nonatomic, assign) NSInteger cellsToRead;    // how many film cells to scan. This is just used for testing during development
@property (nonatomic, strong) NSString *usbPortName;    // USB port to communicate with the Arduino
@property (nonatomic, strong) NSString *logFileName;    // Log file to use. Filename only. Log file will be in the Documents folder
@property (nonatomic, strong) NSString *imagePath;      // Location of where to store the captured photos
@property (nonatomic, assign) NSInteger capturePause;   // How long to pause (in seconds) after sending Arduino instructions. This gives the
                                                        // Arduino time to process what has been received. But I'm also using this during development
                                                        // to simulate a delay during the photo capture
@property (nonatomic, assign) NSSize cameraResolution;  // desired height and width resolution of the camera
@property (nonatomic, assign) Boolean useOlympusCam;    // if true, use the Olympus SLR camera instead of a webcam

@end
