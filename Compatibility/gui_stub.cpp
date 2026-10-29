// OpenEmu does not build Flycast's ImGui user interface: OpenEmu brings its own
// and never asks the core to draw one. The core still calls into the GUI from
// its renderer and input code, so this file provides the interface as no-ops
// instead of pulling in the whole ui/ directory and its embedded resources.

#include "ui/gui.h"
#include "ui/mainui.h"
#include "ui/imgui_driver.h"

GuiState gui_state = GuiState::Closed;
std::unique_ptr<ImGuiDriver> imguiDriver;

void gui_setState(GuiState newState) {
	gui_state = newState;
}

void gui_init() {}
void gui_updateStyle() {}
void gui_open_settings() {}
void gui_display_ui() {}
void gui_draw_osd() {}
void gui_display_osd() {}
void gui_display_profiler() {}
void gui_open_onboarding() {}
void gui_term() {}
void gui_cancel_load() {}
void gui_refresh_files() {}
void gui_cheats() {}
void gui_keyboard_input(u32) {}
void gui_keyboard_inputUTF8(const std::string&) {}
void gui_keyboard_key(u8, bool) {}
bool gui_keyboard_captured() { return false; }
bool gui_mouse_captured() { return false; }
void gui_set_mouse_position(int, int, bool) {}
void gui_set_mouse_button(int, bool, bool) {}
void gui_set_mouse_wheel(float) {}
void gui_set_insets(int, int, int, int) {}
void gui_stop_game(const std::string&) {}
void gui_start_game(const std::string&) {}
void gui_error(const std::string&) {}
void gui_setOnScreenKeyboardCallback(void (*)(bool)) {}
void gui_loadState(bool) {}
void gui_saveState(bool, bool) {}
void gui_cycleSaveStateSlot(int) {}
void gui_togglePause() {}
std::string gui_getCurGameBoxartUrl() { return {}; }
void gui_takeScreenshot() {}
void gui_runOnUiThread(std::function<void()>) {}

void mainui_init() {}
void mainui_term() {}
void mainui_loop(bool) {}
void mainui_start() {}
void mainui_stop() {}
void mainui_reinit() {}
bool mainui_rend_frame() { return false; }
u32 MainFrameCount = 0;
