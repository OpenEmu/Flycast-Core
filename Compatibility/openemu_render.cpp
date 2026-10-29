// Flycast's renderer headers declare RGBColor and Rect in the global namespace,
// the same names QuickDraw uses, so the Objective-C++ game core cannot include
// them. These two entry points are everything the core needs from them.

#include "OEFCBridging.h"

#include "types.h"
#include "hw/pvr/Renderer_if.h"
#include "hw/pvr/pvr_regs.h"

void oe_init_renderer(void)
{
	rend_init_renderer();
}

// The Dreamcast's pixel clock decides how many frames the game runs per
// second, and OpenEmu paces its presentation on that.
double oe_frame_interval(void)
{
	const int spg_clks[4] = { 26944080, 13458568, 13462800, 26944080 };
	u32 pixel_clock = spg_clks[(SPG_CONTROL.full >> 6) & 3];

	switch (pixel_clock)
	{
	case 26944080:
		return 60.00;
	case 26917135:
		return 59.94;
	case 13462800:
		return 50.00;
	case 13458568:
		return 59.94;
	case 25925600:
		return 50.00;
	default:
		return 59.94;
	}
}
