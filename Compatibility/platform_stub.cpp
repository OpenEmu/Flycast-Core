// Pieces of Flycast's shells that the core still calls: the debug output hook
// the console listener writes through, the fatal error reporter, and the
// RetroAchievements serialization that the save state code invokes.

#include "types.h"
#include "oslib/oslib.h"
#include "serialize.h"
#include "achievements/achievements.h"

#include <cstdarg>
#include <cstdio>

int darw_printf(const char *text, ...)
{
	va_list args;
	va_start(args, text);
	int written = vfprintf(stderr, text, args);
	va_end(args);
	return written;
}

void fatal_error(const char *text, ...)
{
	char buffer[2048];
	va_list args;
	va_start(args, text);
	vsnprintf(buffer, sizeof(buffer), text, args);
	va_end(args);

	std::fprintf(stderr, "Fatal error: %s\n", buffer);
	os_notify("Fatal Error", 20000, buffer);
}

// OpenEmu builds without RetroAchievements, so a save state carries none.
namespace achievements
{

void serialize(Serializer &ser)
{
}

void deserialize(Deserializer &deser)
{
}

}
