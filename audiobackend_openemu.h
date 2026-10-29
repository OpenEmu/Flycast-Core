#pragma once

#include "audio/audiostream.h"

// Hands audio to OpenEmu's ring buffer instead of opening a device of its own.
class OpenEmuAudioBackend : public AudioBackend
{
public:
	OpenEmuAudioBackend();

	bool init() override;
	u32 push(const void *data, u32 frames, bool wait) override;
};
