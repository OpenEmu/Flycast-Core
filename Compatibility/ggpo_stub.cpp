// Flycast's rollback netplay needs the GGPO library, which OpenEmu does not
// build. The core calls into the ggpo namespace unconditionally, so this file
// provides the same stubs the libretro build uses: input is read from the
// gamepad state the frontend writes, and no network session is ever active.

#include "types.h"
#include "network/ggpo.h"
#include "hw/maple/maple_cfg.h"
#include "input/gamepad_device.h"

#include <chrono>
#include <future>
#include <cstring>

namespace ggpo
{

bool inRollback;

std::future<bool> startNetwork() {
	return std::async(std::launch::deferred, [] { return false; });
}

void startSession(int localPort, int localPlayerNum) {
}

void stopSession() {
}

void getInput(MapleInputState inputState[4])
{
	for (int player = 0; player < 4; player++)
	{
		MapleInputState& state = inputState[player];
		state.kcode = kcode[player];
		state.halfAxes[PJTI_L] = lt[player];
		state.halfAxes[PJTI_R] = rt[player];
		state.halfAxes[PJTI_L2] = lt2[player];
		state.halfAxes[PJTI_R2] = rt2[player];
		state.fullAxes[PJAI_X1] = joyx[player];
		state.fullAxes[PJAI_Y1] = joyy[player];
		state.fullAxes[PJAI_X2] = joyrx[player];
		state.fullAxes[PJAI_Y2] = joyry[player];
		state.fullAxes[PJAI_X3] = joy3x[player];
		state.fullAxes[PJAI_Y3] = joy3y[player];
	}
}

bool nextFrame() {
	return true;
}

bool active() {
	return false;
}

void displayStats() {
}

void endOfFrame() {
}

void sendChatMessage(int playerNum, const std::string& msg) {
}

void receiveChatMessages(void (*callback)(int playerNum, const std::string& msg)) {
}

}
