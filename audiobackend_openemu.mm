#import "audiobackend_openemu.h"
#import "FlycastGameCore.h"

#import <OpenEmuBase/OERingBuffer.h>

#include <chrono>
#include <thread>

// OpenEmu runs its own output unit and pulls samples from the ring buffer, so
// the core uses the samplerate OpenEmu plays back at.
static constexpr u32 SAMPLERATE = 44100;

using the_clock = std::chrono::high_resolution_clock;
static the_clock::time_point last_time;

OpenEmuAudioBackend::OpenEmuAudioBackend()
	: AudioBackend("openemu", "OpenEmu")
{
}

bool OpenEmuAudioBackend::init()
{
	last_time = the_clock::time_point();
	return true;
}

u32 OpenEmuAudioBackend::push(const void *frame, u32 samples, bool wait)
{
	// Flycast paces itself on its sound output: push() may block until the
	// samples it just wrote have had time to play. OpenEmu's ring buffer gives
	// no such feedback, so the time the samples take to play is subtracted from
	// the time elapsed since the last push instead.
	the_clock::time_point now = the_clock::now();

	[[_current audioBufferAtIndex:0] write:frame maxLength:(size_t)samples * 4];

	if (wait)
	{
		auto frameDuration = std::chrono::nanoseconds(1000000000L * samples / SAMPLERATE);
		if (last_time.time_since_epoch() != the_clock::duration::zero())
		{
			auto remaining = frameDuration - (now - last_time);
			if (remaining >= the_clock::duration::zero())
			{
				std::this_thread::sleep_for(remaining);
				last_time += frameDuration;
			}
			else
			{
				// Rather behind: restart the clock instead of trying to catch up.
				last_time = now;
			}
		}
		else
		{
			last_time = now;
		}
	}
	return 1;
}
