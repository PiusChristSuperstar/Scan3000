//
//  OlympusCam.m
//  Scan3000
//
//  Created by Pius Ott on 16/2/2026.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "OlympusCam.h"

@implementation OlympusCam

// formatter used for the file name. We're making this static because creating it over and over uses a lot of resources
static NSDateFormatter *formatter = nil;


// -------------------------------------------------------------------------------------------

/**
 Detect connected Olympus cameras and use the first one found
 */
- (void)DetectCameras
{
    CameraList *list;
    gp_list_new(&list);
    gp_camera_autodetect(list, _context);

    int count = gp_list_count(list);
    if (count == 0)
    {
        NSLog(@"No cameras detected");
        return;
    }

    const char *model;
    const char *port;

    gp_list_get_name(list, 0, &model);
    gp_list_get_value(list, 0, &port);

    gp_camera_new(&_camera);

    GPPortInfoList *portinfolist;
    gp_port_info_list_new(&portinfolist);
    gp_port_info_list_load(portinfolist);

    int portIndex = gp_port_info_list_lookup_path(portinfolist, port);
    GPPortInfo portinfo;
    gp_port_info_list_get_info(portinfolist, portIndex, &portinfo);

    gp_camera_set_port_info(_camera, portinfo);

    CameraAbilitiesList *abilities;
    gp_abilities_list_new(&abilities);
    gp_abilities_list_load(abilities, _context);

    int modelIndex = gp_abilities_list_lookup_model(abilities, model);
    CameraAbilities ability;
    gp_abilities_list_get_abilities(abilities, modelIndex, &ability);

    gp_camera_set_abilities(_camera, ability);

    int result = gp_camera_init(_camera, _context);
    if (result != GP_OK)
    {
        NSLog(@"Error initialising camera : %d", result);
    }
    else
    {
        NSLog(@"Camera initialised successfully");
        [self EnableLiveView];      // turn on camera live view option if needed
    }
}

// -------------------------------------------------------------------------------------------

- (void)CaptureImage:(NSString *)saveImagePath
{
    CameraFilePath camera_file_path;
    
    int ret = gp_camera_capture(
        _camera,
        GP_CAPTURE_IMAGE,
        &camera_file_path,
        _context
    );

    if (ret == GP_OK)
    {
        // NSLog(@"Captured: %s/%s", camera_file_path.folder, camera_file_path.name);

        // 1. Create a new camera file object
        CameraFile *cameraFile;
        gp_file_new(&cameraFile);

        // 2. Get the file from the camera
        ret = gp_camera_file_get(_camera, camera_file_path.folder, camera_file_path.name,
                                 GP_FILE_TYPE_NORMAL,
                                 cameraFile,
                                 _context);

        if (ret == GP_OK)
        {
            if (!formatter) // create the date formatter on first use
            {
                formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"yyyyMMdd_HHmmss";
            }
            
            // Make sure our save images directory actually exists
            NSString *expandedPath = [saveImagePath stringByExpandingTildeInPath];  // in case we use ~ in our appSettings
            [[NSFileManager defaultManager]
                  createDirectoryAtPath:expandedPath
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:nil];
            
            NSString *filename = [NSString stringWithFormat:@"%@.jpg", [formatter stringFromDate:[NSDate date]]];
            NSString *fullFilePath = [expandedPath stringByAppendingPathComponent:filename];

            // 3. Save the file locally
            const char *data;
            unsigned long size;
            gp_file_get_data_and_size(cameraFile, &data, &size);

            NSData *imageData = [NSData dataWithBytes:data length:size];
            [imageData writeToFile:fullFilePath atomically:YES];
            
            NSError *error = nil;
            BOOL success = [imageData writeToFile:fullFilePath
                                          options:NSDataWritingAtomic
                                            error:&error];

            if (!success)
                NSLog(@"Write for file [%@] failed: %@", fullFilePath, error.localizedDescription);
            else
            {
                NSLog(@"File [%@] saved", fullFilePath);
                
                [self DeleteCameraImage:camera_file_path];
                //TestSomeShit;
            }
            
            /* - old method. Seems less robust than the gp_file_get_data_and_size/writeToFile version above. -
            NSString *fullFilePath2 = [expandedPath stringByAppendingPathComponent:@"image2.jpg"];
            ret = gp_file_save(cameraFile, [fullFilePath2 UTF8String]);
            if (ret == GP_OK)
                NSLog(@"File [%@] downloaded successfully.", fullFilePath2);
            else
                NSLog(@"Save error: %s", gp_result_as_string(ret));
             */
        }
        else
        {
            NSLog(@"Failed to download file.");
        }

        // 4. Clean up
        gp_file_unref(cameraFile);
    }
}

// -------------------------------------------------------------------------------------------

- (void)DeleteCameraImage:(CameraFilePath)camera_file_path
{
    int result = gp_filesystem_delete_file(_camera->fs, camera_file_path.folder, camera_file_path.name, _context);

    if (result != GP_OK)
    {
        NSLog(@"Error deleting camera file [%s] : %d", camera_file_path.name, result);
    }
    else
    {
        NSLog(@"File [%s] deleted successfully from camera", camera_file_path.name);

        // Assuming the camera is set to also capture RAW files, delete that one too.
        NSString *camFileName = [NSString stringWithUTF8String:camera_file_path.name];
        NSString *rawFileName = [camFileName stringByReplacingOccurrencesOfString:@".JPG"
                                                                       withString:@".ORF"
                                                                          options:NSCaseInsensitiveSearch
                                                                            range:NSMakeRange(0, [camFileName length])];
        
        result = gp_filesystem_delete_file(_camera->fs, camera_file_path.folder, [rawFileName UTF8String], _context);
        if (result != GP_OK)
        {
            NSLog(@"Error deleting raw file [%@] : %d", rawFileName, result);
        }
        else
        {
            NSLog(@"File [%@] deleted successfully from camera", rawFileName);
        }
    }
}

// -------------------------------------------------------------------------------------------

- (void)EnableLiveView
{
    CameraWidget *widget = NULL;
    gp_camera_get_config(_camera, &widget, _context);
    
    CameraWidget *liveview = NULL;
    gp_widget_get_child_by_name(widget, "liveview", &liveview);
    
    if (liveview)
    {
        NSLog(@"Turning on liveview option");

        int value = 1;
        gp_widget_set_value(liveview, &value);
        gp_camera_set_config(_camera, widget, _context);
        //NSLog(@"Error initialising camera : %d", result);
    }
    
    gp_widget_free(widget);
}

// -------------------------------------------------------------------------------------------

// retrieve a preview image from the camera
- (NSImage *)GetPreviewImage:(CameraFile *)camFile
{
    NSImage *img;
    
    int ret = gp_camera_capture_preview(_camera, camFile, _context);

    if (ret == GP_OK)
    {
        const char *data;
        unsigned long size;

        gp_file_get_data_and_size(camFile, &data, &size);

        NSData *imageData = [NSData dataWithBytes:data length:size];

        img = [[NSImage alloc] initWithData:imageData];
    }
    else if (ret == GP_ERROR_CAMERA_BUSY)    // should be GP_ERROR_IO_IN_PROGRESS but I can't find a header file that has this defined
    {
        // This happens if the previous call hasn't finished and is to be expected to happen
        // a bunch of times while we're doing fast previews.
        // Just pause for a short while to give the loop time to breathe
        usleep(20000);
    }
    else
    {
        NSLog(@"Preview failed: %s", gp_result_as_string(ret));
        img = NULL;
    }
  
    return img;
}

// -------------------------------------------------------------------------------------------

- (void)CameraExit
{
    gp_camera_exit(_camera, _context);
    gp_camera_free(_camera);
    gp_context_unref(_context);
}

// -------------------------------------------------------------------------------------------

@end
