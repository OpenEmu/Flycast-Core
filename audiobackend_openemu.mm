#import "audiobackend_openemu.h"
#import "FlycastGameCore.h"
#include <mach/mach_time.h>
#import <OpenEmuBase/OERingBuffer.h>
#import <chrono>
#include <thread>

using the_clock = std::chrono::high_resolution_clock;
static the_clock::time_point last_time, NOW;

#define SAMPLERATE  44100

static void openemu_init()
{
    last_time = the_clock::time_point();
}

static u32 openemu_push(const void* frame, u32 samples, bool wait)
{
    //Flycast is using the sound buffer as timing.  OpenEmu sound uses multiple
    //  buffers so we have no way to wait that I've found
    //We need to wait for sound to play before returning to the emulator core
    //  we calculate the time that is needed in microseconds to play the current sound
    //  and subtract the time it took since the last sound samples were played

    //Get the Current clock time
    NOW = the_clock::now();
    
    //Write the sound bytes to the buffer
    [[_current audioBufferAtIndex:0] write:frame maxLength:(size_t)samples * 4];
    
    if (wait) {
        //Calculate the time in nano seconds it should take to play the audio
        auto fduration = std::chrono::nanoseconds(1000000000L * samples / SAMPLERATE);

        //make sure time has actually elapsed before waiting
        if (last_time.time_since_epoch() != the_clock::duration::zero())
        {
          //Calculate the duration differnece between the time elapsed and how long it should have taken to play the sound
          auto duration = fduration - (NOW - last_time);
            if (duration >= the_clock::duration::zero()){
                //Sleep the thread to make up that difference
                std::this_thread::sleep_for(duration);
                last_time += fduration;
            }else{
                last_time = NOW;
            }
        }
        else
        {
            //Set the last_time marker to now
            last_time = NOW;
        }
    }
	return 1;
}

static void openemu_term() {
}

audiobackend_t audiobackend_openemu = {
		"openemu", // Slug
		"OpenEmu", // Name
		&openemu_init,
		&openemu_push,
		&openemu_term
};
