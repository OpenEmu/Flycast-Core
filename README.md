Flycast-Core
===========

OpenEmu Core plugin with Flycast to support Dreamcast emulation.

The `flycast` submodule is pinned to Flycast v2.7, whose frontend the wrapper
in this repository is written against. Flycast compiles into the plugin from
the source list in `Flycast.xcodeproj`, which is the set of files Flycast's own
CMake build uses for macOS minus the parts OpenEmu replaces:

* the window system, the ImGui interface and the audio drivers are replaced by
  the implementations in `Compatibility/`,
* SDL, Vulkan, DirectX, RetroAchievements, GGPO, Lua and network play are not
  built at all.

The target builds for arm64 only, since v2.7's recompiler is written for
AArch64 and the x86_64 one needs a dependency the project does not ship.
