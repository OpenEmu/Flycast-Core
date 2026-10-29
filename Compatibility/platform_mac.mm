// The macOS frontend normally supplies this; OpenEmu provides its own folder
// for anything Flycast wants to write outside of its own directories.

#import <Foundation/Foundation.h>

#include <string>

namespace hostfs
{

std::string getScreenshotsPath()
{
	@autoreleasepool {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES);
		return [[paths objectAtIndex:0] UTF8String];
	}
}

}
