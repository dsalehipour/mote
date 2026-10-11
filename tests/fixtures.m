#import <AppKit/AppKit.h>

// Deterministic image fixtures, drawn using the same native fonts as Mac apps.
int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *root = @(argv[1]);
        [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSString *name in @[@"large", @"small-retina", @"dark", @"blank"]) {
            BOOL small = [name isEqualToString:@"small-retina"], dark = [name isEqualToString:@"dark"];
            NSInteger width = 1200, height = 260;
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
            [(dark ? [NSColor colorWithWhite:0.1 alpha:1] : NSColor.whiteColor) setFill];
            NSRectFill(NSMakeRect(0, 0, width, height));
            if (![name isEqualToString:@"blank"]) {
                NSString *text = @"Utility Profit\nRent: $1,250.00\nMote copies text from your screen.";
                [text drawAtPoint:NSMakePoint(40, 40) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:small ? 28 : 36], NSForegroundColorAttributeName:dark ? NSColor.whiteColor : NSColor.blackColor}];
            }
            [NSGraphicsContext restoreGraphicsState];
            [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[root stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]] atomically:YES];
        }
    }
    return 0;
}
