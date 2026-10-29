// OpenEmu owns the OpenGL context and the drawable. It makes its CGL context
// current and binds the framebuffer the core has to draw into before calling
// into the core, so the graphics context below only records what GL reports and
// leaves presenting the frame to OpenEmu.

#pragma once

#include "wsi/gl_context.h"
#include "ui/imgui_driver.h"

class OpenEmuGraphicsContext : public GLGraphicsContext
{
public:
	static void Create(void *window, void *display);

	// OpenEmu blits the presentation framebuffer into its IOSurface itself.
	void swap() override {}

	OpenEmuGraphicsContext();
};

// The core asks its UI driver whether a frame has been rendered, so the driver
// exists even though nothing is ever drawn with ImGui.
class OpenEmuImGuiDriver : public ImGuiDriver
{
public:
	void newFrame() override {}
	void renderDrawData(ImDrawData *drawData, bool guiOpen) override {}
	void present() override {}
	ImTextureID getTexture(const std::string& name) override { return ImTextureID(); }
	ImTextureID updateTexture(const std::string& name, const u8 *data, int width, int height, bool nearestSampling) override {
		return ImTextureID();
	}
	void deleteTexture(const std::string& name) override {}
};
