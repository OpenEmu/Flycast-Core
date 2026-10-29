// Flycast embeds fonts, translations and Naomi flash dumps through CMake's
// cmrc generator. OpenEmu builds the core with Xcode and does not need any of
// them for Dreamcast emulation, so the resource store is empty.

#include "oslib/resources.h"

namespace resource
{

std::unique_ptr<u8[]> load(const std::string&, size_t& size) {
	size = 0;
	return nullptr;
}

std::vector<std::string> listDirectory(const std::string&) {
	return {};
}

}
