/*
    Created on: Oct 19, 2019

	Copyright 2019 flyinghead

	This file is part of Flycast.

    Flycast is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    Flycast is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Flycast.  If not, see <https://www.gnu.org/licenses/>.
*/

// Copy of core/wsi/gl_context.cpp with an OpenEmu window system added: OpenEmu
// creates the GL context, so there is nothing to create here and nothing to
// swap, and the ImGui driver is a stub since OpenEmu draws its own interface.

#include "gl_context.h"
#if defined(LIBRETRO)
#include "libretro.h"
#elif defined(TARGET_IPHONE)
#include "osx.h"
#elif defined(USE_SDL)
#include "sdl.h"
#elif defined(__ANDROID__) || defined(SUPPORT_X11)
#include "egl.h"
#elif defined(OPENEMU)
#include "openemu_context.h"
#else
#error Unsupported window system
#endif

#if !defined(LIBRETRO) && !defined(OPENEMU)
#include "rend/gles/opengl_driver.h"
#endif

#include <cstring>

void GLGraphicsContext::findGLVersion()
{
	while (true)
		if (glGetError() == GL_NO_ERROR)
			break;
	glGetIntegerv(GL_MAJOR_VERSION, &majorVersion);
	if (glGetError() == GL_INVALID_ENUM)
		majorVersion = 2;
	else
	{
		glGetIntegerv(GL_MINOR_VERSION, &minorVersion);
	}
	const char *version = (const char *)glGetString(GL_VERSION);
	_isGLES = !strncmp(version, "OpenGL ES", 9);
	INFO_LOG(RENDERER, "OpenGL version: %s", version);

	const char *p = (const char *)glGetString(GL_RENDERER);
	driverName = p != nullptr ? p : "unknown";
	p = (const char *)glGetString(GL_VERSION);
	driverVersion = p != nullptr ? p : "unknown";
	p = (const char *)glGetString(GL_VENDOR);
	std::string vendor = p != nullptr ? p : "";
	if (vendor.substr(0, 4) == "ATI ")
		amd = true;
	else if (driverName.find(" ATI ") != std::string::npos
			|| driverName.find(" AMD ") != std::string::npos)
		// mesa
		amd = true;
	else
		amd = false;
}

void GLGraphicsContext::postInit()
{
	findGLVersion();
	resetUIDriver();
}

void GLGraphicsContext::preTerm()
{
#ifndef LIBRETRO
	imguiDriver.reset();
#endif
}

void GLGraphicsContext::resetUIDriver()
{
#ifndef LIBRETRO
	imguiDriver.reset();
#if defined(OPENEMU)
	imguiDriver = std::unique_ptr<ImGuiDriver>(new OpenEmuImGuiDriver());
#else
	imguiDriver = std::unique_ptr<ImGuiDriver>(new OpenGLDriver());
#endif
#endif
}

void GLGraphicsContext::setSwapInterval(int interval)
{
	if (interval <= 0 || interval == gameSwapInterval)
		return;
	gameSwapInterval = interval;
	gameSwapIntervalChanged = true;
}

void GLGraphicsContext::Create(void *window, void *display)
{
#if defined(LIBRETRO)
	LibretroGraphicsContext::Create(window, display);
#elif defined(TARGET_IPHONE)
	OSXGraphicsContext::Create(window, display);
#elif defined(USE_SDL)
	SDLGLGraphicsContext::Create(window, display);
#elif defined(__ANDROID__) || defined(SUPPORT_X11)
	EGLGraphicsContext::Create(window, display);
#elif defined(OPENEMU)
	OpenEmuGraphicsContext::Create(window, display);
#endif
}
