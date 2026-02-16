//
//  OlympusCam.m
//  Scan3000
//
//  Created by Pius Ott on 16/2/2026.
//

#import <Foundation/Foundation.h>
#import "OlympusCam.h"

@implementation OlympusCam

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

    int ret = gp_camera_init(_camera, _context);
}

// -------------------------------------------------------------------------------------------

- (void)CaptureImage
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
        NSLog(@"Captured: %s/%s",
              camera_file_path.folder,
              camera_file_path.name);
    }
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
