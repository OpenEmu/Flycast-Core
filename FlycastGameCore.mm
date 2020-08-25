/*
 Copyright (c) 2013, OpenEmu Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FlycastGameCore.h"
#import <OpenEmuBase/OERingBuffer.h>
#import <Carbon/Carbon.h>

#include "audiobackend_openemu.h"

#include "types.h"
#include "emulator.h"
#include "stdclass.h"
#include "cheats.h"
#include "cfg/cfg.h"
#include "hw/mem/_vmem.h"
#include "hw/maple/maple_cfg.h"
#include "hw/maple/maple_devs.h"
#include "hw/pvr/Renderer_if.h"
#include "hw/pvr/pvr_mem.h"
#include "oslib/oslib.h"
#include "oslib/audiostream.h"
#include "rend/gui.h"
#include "rend/TexCache.h"
#include <sys/stat.h>
#include "wsi/context.h"

#include <OpenGL/gl3.h>
#include <functional>

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 60 * 4
#define DC_PLATFORM DC_PLATFORM_DREAMCAST
#define DC_Contollers 4

#if 1    /* was set to #if 1 by ./configure */
#  define Z_HAVE_UNISTD_H
#endif

#if 1    /* was set to #if 1 by ./configure */
#  define Z_HAVE_STDARG_H
#endif

typedef std::function<void(bool status, const std::string &message, void *cbUserData)> Callback;

@interface FlycastGameCore () <OEDCSystemResponderClient>
{
    uint16_t *_soundBuffer;
    int videoWidth, videoHeight;
    NSString *romPath;
    NSString *romFile;
    NSString *autoLoadStatefileName;
}
@end

__weak FlycastGameCore *_current;

@implementation FlycastGameCore

- (id)init
{
    self = [super init];
    
    if(self)
    {
        videoHeight = 480;
        videoWidth = 640;
        _soundBuffer = (uint16_t *)malloc(SIZESOUNDBUFFER * sizeof(uint16_t));
        memset(_soundBuffer, 0, SIZESOUNDBUFFER * sizeof(uint16_t));
    }
    
    _current = self;
    return self;
}

- (void)dealloc
{
    free(_soundBuffer);
}

bool system_init;
char bios_dir[1024];

# pragma mark - Reicast Execution functions

extern void common_linux_setup();
extern int reicast_init(int argc, char* argv[]);

extern void dc_exit();
extern void dc_resume();
extern void dc_stop();
extern void dc_run();
extern void dc_reset(bool manual);
extern void dc_request_reset();
extern void dc_start_game(const char *path);

extern void rend_init_renderer();
extern int screen_width,screen_height;
extern bool rend_framePending();
extern bool rend_single_frame();

extern void dc_savestate();
extern void dc_loadstate();
extern void dc_SetStateName (const std::string &fileName);

int darw_printf(const char* text,...) {
    va_list args;
    
    char temp[2048];
    va_start(args, text);
    vsprintf(temp, text, args);
    va_end(args);
    
    NSLog(@"%s", temp);
    
    return 0;
}

volatile bool has_init = false;

# pragma mark - Reicast thread
- (void)emu_init
{
    settings.profile.run_counts=0;
    common_linux_setup();
    
    //Register our own audio backend
    RegisterAudioBackend(&audiobackend_openemu);
    
    // Set battery save dir
    NSURL *SavesDirectory = [NSURL fileURLWithPath:[self batterySavesDirectoryPath]];
    
    //create the save direcory for the game
    [[NSFileManager defaultManager] createDirectoryAtURL:[SavesDirectory URLByAppendingPathComponent:romFile] withIntermediateDirectories:YES attributes:nil error:nil];
    
    // create the data directory
    [[NSFileManager defaultManager] createDirectoryAtURL:[[NSURL fileURLWithPath:[self supportDirectoryPath]] URLByAppendingPathComponent:@"data"] withIntermediateDirectories:YES attributes:nil error:nil];
    
    //setup the user and system directories
    set_user_config_dir([[self supportDirectoryPath] UTF8String]);
    set_user_data_dir([SavesDirectory URLByAppendingPathComponent:romFile].path.fileSystemRepresentation);
    add_system_data_dir([[self supportDirectoryPath] UTF8String]);
    
    //Setup the bios directory
    snprintf(bios_dir,sizeof(bios_dir),"%s%c",[[self biosDirectoryPath] UTF8String],'/');
    
    //Initialize core gles
    InitRenderApi();
    rend_init_renderer();
    
    char* argv[] = { "reicast" };
    
    reicast_init(0, NULL);
    
    has_init = true;
}

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    romFile = [[path lastPathComponent] stringByDeletingPathExtension];
    romPath = path;
    
    return YES;
}

- (void)setupEmulation
{
    screen_width = videoWidth;
    screen_height = videoHeight;
}

- (void)stopEmulation
{
    NSLog(@"Stopping Emulation Core");
    //We need this sleep for now until I find a better way of making sure the save is completed
    usleep (10000);
    
    dc_exit();
    
    has_init = false;
    
    [super stopEmulation];
}

- (void)resetEmulation
{
    dc_request_reset();
}

- (void)executeFrame
{
    if (!system_init && !has_init)
    {
        //Set the game to the virtual drive
        cfgSetVirtual ("config", "image", [romPath UTF8String]);
        
        //start the reicast core
        [self emu_init];
        
        gui_state = Closed;
        
        dc_start_game([romPath UTF8String]);
        
        dc_resume();
    }
    
    //System is initialized - render the frames
    if (!has_init)
        return;
    
    if (rend_framePending())
    {
        if (!system_init){
            system_init = true;
            screen_height = videoHeight;
            screen_width = videoWidth;
        }
        
        if ([self needsDoubleBufferedFBO])
           [self.renderDelegate presentDoubleBufferedFBO];
        else
           [self.renderDelegate presentationFramebuffer];
                   
        rend_single_frame();
        
        calcFPS();
    }
}

# pragma mark - Video
void os_SetWindowText(const char * text) {
    puts(text);
}

void os_DoEvents() {
}

void os_CreateWindow() {
}

void* libPvr_GetRenderTarget() {
    return 0;
}

void* libPvr_GetRenderSurface() {
    return 0;
}

bool gl_init(void*, void*) {
    return true;
}

void gl_term() {}

double emuFrameInterval = 59.94;

void calcFPS(){
    const int spg_clks[4] = { 26944080, 13458568, 13462800, 26944080 };
    u32 pixel_clock = spg_clks[(SPG_CONTROL.full >> 6) & 3];
    
    switch (pixel_clock)
    {
        case 26944080:
            emuFrameInterval = 60.00;
            //info->timing.fps = 60.00; /* (VGA  480 @ 60.00) */
            break;
        case 26917135:
            emuFrameInterval = 59.94;
            //info->timing.fps = 59.94; /* (NTSC 480 @ 59.94) */
            break;
        case 13462800:
            emuFrameInterval = 50.00;
            // info->timing.fps = 50.00; /* (PAL 240  @ 50.00) */
            break;
        case 13458568:
            emuFrameInterval = 59.94;
            // info->timing.fps = 59.94; /* (NTSC 240 @ 59.94) */
            break;
        case 25925600:
            emuFrameInterval = 50.00;
            //info->timing.fps = 50.00; /* (PAL 480  @ 50.00) */
            break;
    }
}

- (OEGameCoreRendering)gameCoreRendering
{
    return OEGameCoreRenderingOpenGL3Video;
}

- (BOOL)needsDoubleBufferedFBO
{
    return YES;
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(videoWidth, videoHeight);
}

- (OEIntSize)aspectSize
{
    return OEIntSizeMake(4, 3);
}

- (NSTimeInterval)frameInterval
{
    return emuFrameInterval;
}

# pragma mark - Audio

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return SAMPLERATE;
}

# pragma mark - Save States
- (void)autoloadWaitThread
{
    @autoreleasepool
    {
        //Wait here until we get the signal for full initialization
        while (!system_init)
            usleep (10000);
        
        dc_SetStateName(autoLoadStatefileName.fileSystemRepresentation);
        dc_loadstate();
        
        dc_resume();
    }
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    if (has_init) {
        dc_SetStateName(fileName.fileSystemRepresentation);
        dc_savestate();
        
        dc_resume();

        block(true, nil);
    }
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    if (!has_init) {
        //Start a separate thread to load
        autoLoadStatefileName = fileName;
        [NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
    } else {
        dc_SetStateName(fileName.fileSystemRepresentation);
        dc_loadstate();
        dc_resume();
    }
    block(true, nil);
}

# pragma mark - Input

void os_SetupInput()
{
    // Create contollers, but only put vmu on the first controller
#if DC_PLATFORM == DC_PLATFORM_DREAMCAST
   for (int i = 0; i < DC_Contollers; i++)
    {
        settings.input.maple_devices[i] = MDT_SegaController;
        settings.input.maple_expansion_devices[i][0] = i == 0 ? MDT_SegaVMU : MDT_None;
        settings.input.maple_expansion_devices[i][1] = i == 0 ? MDT_SegaVMU : MDT_None;
    }
    
    mcfg_CreateDevices();
#endif
}

void UpdateInputState(u32 port) {}

void UpdateVibration(u32 port, u32 value) {}

int get_mic_data(u8* buffer) { return 0; }
int push_vmu_screen(u8* buffer) { return 0; }

extern u16 kcode[4] ; //= { 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF };
extern s8 joyx[4],joyy[4];
extern u8 rt[4],lt[4];

enum DCPad
{
    Btn_C		= 1,
    Btn_B		= 1<<1,
    Btn_A		= 1<<2,
    Btn_Start	= 1<<3,
    DPad_Up		= 1<<4,
    DPad_Down	= 1<<5,
    DPad_Left	= 1<<6,
    DPad_Right	= 1<<7,
    Btn_Z		= 1<<8,
    Btn_Y		= 1<<9,
    Btn_X		= 1<<10,
    Btn_D		= 1<<11,
    DPad2_Up	= 1<<12,
    DPad2_Down	= 1<<13,
    DPad2_Left	= 1<<14,
    DPad2_Right	= 1<<15,
    
    Axis_LT= 0x10000,
    Axis_RT= 0x10001,
    Axis_X= 0x20000,
    Axis_Y= 0x20001,
};

void handle_key(int dckey, int state, int player)
{
    if (state)
        kcode[player] &= ~dckey;
    else
        kcode[player] |= dckey;
}

- (oneway void)didMoveDCJoystickDirection:(OEDCButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
    if (player > DC_Contollers) return;
    
    player -= 1;
    
    switch (button)
    {
        case OEDCAnalogUp:
            joyy[player] = value * INT8_MIN;
            break;
        case OEDCAnalogDown:
            joyy[player] = value * INT8_MAX;
            break;
        case OEDCAnalogLeft:
            joyx[player] = value * INT8_MIN;
            break;
        case OEDCAnalogRight:
            joyx[player] = value * INT8_MAX;
            break;
        case OEDCAnalogL:
            lt[player] = value ? 255 : 0;
            break;
        case OEDCAnalogR:
            rt[player] = value ? 255 : 0;
            break;
        default:
            break;
    }
}

-(oneway void)didPushDCButton:(OEDCButton)button forPlayer:(NSUInteger)player
{
    if (player > DC_Contollers) return;
    
    player -= 1;
    
    switch (button) {
        case OEDCButtonUp:
            handle_key(DPad_Up, 1, (int)player);
            break;
        case OEDCButtonDown:
            handle_key(DPad_Down, 1, (int)player);
            break;
        case OEDCButtonLeft:
            handle_key(DPad_Left, 1, (int)player);
            break;
        case OEDCButtonRight:
            handle_key(DPad_Right, 1, (int)player);
            break;
        case OEDCButtonA:
            handle_key(Btn_A, 1, (int)player);
            break;
        case OEDCButtonB:
            handle_key(Btn_B, 1, (int)player);
            break;
        case OEDCButtonX:
            handle_key(Btn_X, 1, (int)player);
            break;
        case OEDCButtonY:
            handle_key(Btn_Y, 1, (int)player);
            break;
        case OEDCButtonStart:
            handle_key(Btn_Start, 1, (int)player);
            break;
        default:
            break;
    }
}

- (oneway void)didReleaseDCButton:(OEDCButton)button forPlayer:(NSUInteger)player
{
    if (player > DC_Contollers) return;
    
    player -= 1;
    
    // FIXME: Dpad up/down seems to get set and released on the same frame, making it not do anything.
    // Need to ensure actions last across a frame?
    switch (button) {
        case OEDCButtonUp:
            handle_key(DPad_Up, 0, (int)player);
            break;
        case OEDCButtonDown:
            handle_key(DPad_Down, 0, (int)player);
            break;
        case OEDCButtonLeft:
            handle_key(DPad_Left, 0, (int)player);
            break;
        case OEDCButtonRight:
            handle_key(DPad_Right, 0, (int)player);
            break;
        case OEDCButtonA:
            handle_key(Btn_A, 0, (int)player);
            break;
        case OEDCButtonB:
            handle_key(Btn_B, 0, (int)player);
            break;
        case OEDCButtonX:
            handle_key(Btn_X, 0, (int)player);
            break;
        case OEDCButtonY:
            handle_key(Btn_Y, 0, (int)player);
            break;
        case OEDCButtonStart:
            handle_key(Btn_Start, 0, (int)player);
            break;
        default:
            break;
    }
}

@end
