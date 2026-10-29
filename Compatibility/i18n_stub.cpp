// Flycast's translations live in resources that CMake embeds into the binary.
// OpenEmu's core does not ship that resource bundle and has no translated UI,
// so the translation helpers pass their input through unchanged.

#include "oslib/i18n.h"

namespace i18n
{

std::string getCurrentLocale() { return "en"; }
std::string getSystemLocale() { return "en"; }

void init() {}
void reloadLanguage() {}

std::string Ts(const std::string& msg) { return msg; }

const char *T(const char *msg) { return msg; }

const char *translateCtx(const std::string&, const char *msg) { return msg; }

const char *translatePlural(const char *msg, const char *, int) { return msg; }

}
