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

#include "audiobackend_openemu.h"
#include "OEFCBridging.h"

#include "types.h"
#include "emulator.h"
#include "stdclass.h"
#include "cfg/cfg.h"
#include "cfg/option.h"
#include "hw/maple/maple_cfg.h"
#include "hw/maple/maple_devs.h"
#include "input/gamepad_device.h"
#include "oslib/oslib.h"
#include "ui/gui.h"
#include "wsi/context.h"

#include <exception>

#define SAMPLERATE 44100
#define DC_PLATFORM DC_PLATFORM_DREAMCAST
#define DC_Contollers 4

// Flycast's own window system entry points, provided by this file.
void common_linux_setup();

@interface FlycastGameCore () <OEDCSystemResponderClient>
{
    int videoWidth, videoHeight;
    NSString *romPath;
    NSString *romFile;
    NSString *autoLoadStatefileName;
    BOOL coreInitialized;
    BOOL gameStarted;
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
    }

    _current = self;
    return self;
}

# pragma mark - Flycast setup

- (void)emu_init
{
    // Flycast writes code into RAM and protects the pages it has written to, so
    // it needs its SIGSEGV handler to be installed before the game boots.
    common_linux_setup();

    // The backend registers itself with the core and writes to OpenEmu's ring
    // buffer, so it replaces Flycast's own audio drivers.
    static OpenEmuAudioBackend audioBackend;

    // Set battery save dir
    NSURL *SavesDirectory = [NSURL fileURLWithPath:[self batterySavesDirectoryPath]];

    //create the save direcory for the game
    [[NSFileManager defaultManager] createDirectoryAtURL:[SavesDirectory URLByAppendingPathComponent:romFile] withIntermediateDirectories:YES attributes:nil error:nil];

    // create the data directory
    [[NSFileManager defaultManager] createDirectoryAtPath:[[self supportDirectoryPath] stringByAppendingPathComponent:@"data"] withIntermediateDirectories:YES attributes:nil error:nil];

    //setup the user and system directories
    set_user_config_dir([[self supportDirectoryPath] fileSystemRepresentation]);
    set_user_data_dir([SavesDirectory URLByAppendingPathComponent:romFile].fileSystemRepresentation);
    add_system_data_dir([[self supportDirectoryPath] fileSystemRepresentation]);

    //Setup the bios directory
    add_system_data_dir([self biosDirectoryPath].fileSystemRepresentation);

    settings.display.width = videoWidth;
    settings.display.height = videoHeight;

    // A standard controller on every port, with VMUs on the first one. Flycast
    // reads this when it creates the maple devices while loading a game.
    for (int port = 0; port < 4; port++)
    {
        config::MapleMainDevices[port] = MDT_SegaController;
        config::MapleExpansionDevices[port][0] = port == 0 ? MDT_SegaVMU : MDT_None;
        config::MapleExpansionDevices[port][1] = port == 0 ? MDT_SegaVMU : MDT_None;
    }

    // OpenEmu creates the GL context and binds a framebuffer before every
    // frame; initRenderApi() only records what it finds there.
    initRenderApi();
    oe_init_renderer();

    // Flycast's option parser reads argv[0] for its usage message, so it gets a
    // program name even though OpenEmu has no command line for it.
    static char *flycast_argv[] = { (char *)"Flycast", NULL };
    flycast_init(1, flycast_argv);

    coreInitialized = YES;
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
    settings.display.width = videoWidth;
    settings.display.height = videoHeight;
}

- (void)stopEmulation
{
    NSLog(@"Stopping Emulation Core");
    //We need this sleep for now until I find a better way of making sure the save is completed
    usleep (10000);

    if (coreInitialized)
    {
        dc_exit();
        flycast_term();
        termRenderApi();

        coreInitialized = NO;
        gameStarted = NO;
    }

    [super stopEmulation];
}

- (void)resetEmulation
{
    if (gameStarted)
        emu.requestReset();
}

- (void)executeFrame
{
    if (!coreInitialized)
        [self emu_init];

    if (!gameStarted)
    {
        // Flycast renders its own interface, and OpenEmu brings one of its own.
        gui_state = GuiState::Closed;

        try {
            emu.loadGame([romPath fileSystemRepresentation]);
            emu.start();
        } catch (const std::exception &e) {
            NSLog(@"Flycast: unable to start %@: %s", romPath, e.what());
            return;
        }
        gameStarted = YES;
    }

    try {
        // Renders into the framebuffer OpenEmu bound for this frame and returns
        // NO when the game is not running.
        if (emu.render())
            [self.renderDelegate presentDoubleBufferedFBO];
    } catch (const std::exception &e) {
        NSLog(@"Flycast: frame failed: %s", e.what());
        return;
    }
}

# pragma mark - Video

// os_CreateWindow() and os_DestroyWindow() do nothing without SDL or X11, so
// the ones in oslib are all this core needs. Pumps Flycast's event queue.
void os_DoEvents() {
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
    return oe_frame_interval();
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
- (void)autoloadWaitThread:(id)unused
{
    @autoreleasepool
    {
        //Wait here until we get the signal for full initialization
        while (!gameStarted)
            usleep (10000);

        dc_SetStateName(autoLoadStatefileName.fileSystemRepresentation);
        dc_loadstate(0);
    }
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    if (gameStarted) {
        dc_SetStateName(fileName.fileSystemRepresentation);
        dc_savestate(0);

        block(true, nil);
    } else {
        block(false, [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError userInfo:nil]);
    }
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    if (!gameStarted) {
        //Start a separate thread to load
        autoLoadStatefileName = fileName;
        [NSThread detachNewThreadSelector:@selector(autoloadWaitThread:) toTarget:self withObject:nil];
    } else {
        dc_SetStateName(fileName.fileSystemRepresentation);
        dc_loadstate(0);
    }
    block(true, nil);
}

# pragma mark - Input

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
};

// Flycast reads the gamepad state from these arrays, see ggpo::getInput().
static void handle_key(u32 dckey, int state, int player)
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
            joyy[player] = (s16)(-32767 * value);
            break;
        case OEDCAnalogDown:
            joyy[player] = (s16)(32767 * value);
            break;
        case OEDCAnalogLeft:
            joyx[player] = (s16)(-32767 * value);
            break;
        case OEDCAnalogRight:
            joyx[player] = (s16)(32767 * value);
            break;
        case OEDCAnalogL:
            lt[player] = value ? 0xFFFF : 0;
            break;
        case OEDCAnalogR:
            rt[player] = value ? 0xFFFF : 0;
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

# pragma mark - Platform services

// Flycast normalizes the file names it lists so that they can be compared;
// macOS hands out decomposed ones.
std::string os_PrecomposedString(std::string string){
    std::string result;
    @autoreleasepool {
        NSString *text = [NSString stringWithUTF8String:string.c_str()];
        result = [[text precomposedStringWithCanonicalMapping] UTF8String];
    }
    return result;
}

void os_SetThreadName(const char *name) {
    // Named threads help in samples; Flycast names its emulation thread.
    @autoreleasepool {
        [[NSThread currentThread] setName:[NSString stringWithUTF8String:name]];
    }
}

void os_RunInstance(int argc, const char *argv[]) {
}

void os_notify(const char *msg, int durationMs, const char *details) {
    NSLog(@"Flycast: %s%s%s", msg,
          details != nullptr ? " - " : "",
          details != nullptr ? details : "");
}

@end
