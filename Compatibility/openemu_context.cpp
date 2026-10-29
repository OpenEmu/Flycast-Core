// OpenEmu makes its CGL context current before it calls initRenderApi(), so
// there is no context to create here and nothing to load besides the entry
// points glad has to know about.

#include "openemu_context.h"

#include "log/Log.h"

#include <glad/gl.h>

#include <dlfcn.h>

// Flycast calls OpenGL through glad's function pointers, which the platform
// window systems fill in once their context is current. The framework exports
// everything the 3.2 core profile offers, so a lookup there is enough.
static GLADapiproc glProcAddress(const char *name)
{
	static void *framework = dlopen("/System/Library/Frameworks/OpenGL.framework/OpenGL", RTLD_NOW | RTLD_LOCAL);
	if (framework != nullptr)
		if (GLADapiproc proc = (GLADapiproc)dlsym(framework, name))
			return proc;

	return (GLADapiproc)dlsym(RTLD_DEFAULT, name);
}

OpenEmuGraphicsContext::OpenEmuGraphicsContext()
	: GLGraphicsContext(nullptr, nullptr)
{
	if (!gladLoadGL(glProcAddress))
		ERROR_LOG(RENDERER, "gladLoadGL() failed");
	postInit();
}

void OpenEmuGraphicsContext::Create(void *window, void *display)
{
	new OpenEmuGraphicsContext();
}
