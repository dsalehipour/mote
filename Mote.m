#import <AppKit/AppKit.h>
#import <Vision/Vision.h>
#import <Carbon/Carbon.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#include <sys/stat.h>

// No bundled runtime, model, network client, or background polling.
static NSUserDefaults *prefs;
static BOOL CopyText(NSString *text) {
    NSPasteboard *board = NSPasteboard.generalPasteboard;
    [board clearContents];
    return [board setString:text forType:NSPasteboardTypeString];
}
static NSString *Recognize(VNImageRequestHandler *handler, BOOL fast, BOOL correction, NSError **error) {
    VNRecognizeTextRequest *request = [VNRecognizeTextRequest new];
    request.recognitionLevel = fast ? VNRequestTextRecognitionLevelFast : VNRequestTextRecognitionLevelAccurate;
    request.usesLanguageCorrection = correction;
    request.automaticallyDetectsLanguage = YES;
    if (![handler performRequests:@[request] error:error]) return nil;
    NSMutableArray *lines = [NSMutableArray new];
    for (VNRecognizedTextObservation *observation in request.results) {
        NSString *line = [observation topCandidates:1].firstObject.string;
        if (line.length) [lines addObject:line];
    }
    return [lines componentsJoinedByString:@"\n"];
}

@interface MoteButton : NSButton @end
@implementation MoteButton
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)canBecomeKeyView { return self.enabled && !self.hidden; }
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor]; }
@end

@interface MoteWindow : NSWindow @end
@implementation MoteWindow
- (void)sendEvent:(NSEvent *)event {
    if (event.type == NSEventTypeKeyDown && !(event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption))) {
        NSResponder *current = self.firstResponder;
        if (event.keyCode == 48) {
            BOOL back = event.modifierFlags & NSEventModifierFlagShift;
            NSView *next = [current isKindOfClass:NSView.class] ? (back ? [(NSView *)current previousKeyView] : [(NSView *)current nextKeyView]) : self.initialFirstResponder;
            if (next) { [self makeFirstResponder:next]; return; }
        }
    }
    [super sendEvent:event];
}
@end

@interface SelectionWindow : NSWindow @end
@implementation SelectionWindow
- (BOOL)canBecomeKeyWindow { return YES; }
@end

@interface SelectionView : NSView {
    NSPoint anchor, cursor;
    BOOL selecting;
}
@property NSImage *snapshot;
@property (copy) void (^completion)(NSRect rect);
@end
@implementation SelectionView
- (BOOL)acceptsFirstResponder { return YES; }
- (void)resetCursorRects { [self addCursorRect:self.bounds cursor:NSCursor.crosshairCursor]; }
- (NSRect)selection {
    return NSIntersectionRect(self.bounds, NSMakeRect(MIN(anchor.x, cursor.x), MIN(anchor.y, cursor.y), fabs(cursor.x-anchor.x), fabs(cursor.y-anchor.y)));
}
- (void)drawRect:(NSRect)dirty {
    [self.snapshot drawInRect:self.bounds];
    if (selecting) {
        NSRect rect = self.selection;
        [NSColor.blackColor setStroke];
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:rect]; path.lineWidth = 4; [path stroke];
        [NSColor.whiteColor setStroke]; path.lineWidth = 2; [path stroke];
    }
    NSRect box = NSMakeRect(24, self.bounds.size.height-68, MIN(320, self.bounds.size.width-48), 44);
    [NSColor.blackColor setFill]; [[NSBezierPath bezierPathWithRoundedRect:box xRadius:10 yRadius:10] fill];
    NSString *hint = @"Drag around text · Escape cancels";
    [hint drawInRect:NSInsetRect(box, 16, 10) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:16], NSForegroundColorAttributeName:NSColor.whiteColor}];
}
- (void)mouseDown:(NSEvent *)event { [NSCursor.crosshairCursor set]; anchor = cursor = [self convertPoint:event.locationInWindow fromView:nil]; selecting = YES; self.needsDisplay = YES; }
- (void)mouseDragged:(NSEvent *)event { [NSCursor.crosshairCursor set]; cursor = [self convertPoint:event.locationInWindow fromView:nil]; self.needsDisplay = YES; }
- (void)mouseUp:(NSEvent *)event {
    cursor = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect rect = self.selection;
    if (rect.size.width >= 1 && rect.size.height >= 1) self.completion(rect);
    else { selecting = NO; self.needsDisplay = YES; }
}
- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53) self.completion(NSZeroRect);
}
@end

// Cocoa delegates use selector discovery. Omitting the broad protocol metadata
// avoids shipping descriptions of hundreds of optional callbacks we do not use.
@interface Mote : NSObject {
    NSStatusItem *status;
    NSWindow *window;
    NSTextView *resultView;
    NSTextField *message;
    NSButton *captureButton, *openButton, *copyButton;
    NSMenuItem *captureMenu;
    NSString *lastText, *savedMessage;
    NSURL *stateURL;
    SelectionWindow *selectionWindow;
    EventHotKeyRef hotkey;
    BOOL busy;
}
- (void)capture:(id)sender;
@end

static OSStatus Hotkey(EventHandlerCallRef next, EventRef event, void *context) {
    [(Mote *)(__bridge id)context capture:nil];
    return noErr;
}

static NSTextField *Label(NSString *text, CGFloat size, NSRect frame, NSView *parent) {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.font = [NSFont systemFontOfSize:size];
    label.frame = frame;
    [parent addSubview:label];
    return label;
}

@implementation Mote
- (NSMenuItem *)item:(NSString *)title action:(SEL)action menu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    [menu addItem:item];
    return item;
}
- (NSButton *)button:(NSString *)title action:(SEL)action frame:(NSRect)frame {
    NSButton *button = [MoteButton buttonWithTitle:title target:self action:action];
    button.font = [NSFont systemFontOfSize:15];
    button.controlSize = NSControlSizeLarge;
    button.frame = frame;
    [window.contentView addSubview:button];
    return button;
}
- (NSString *)shortcut {
    return [NSString stringWithFormat:@"⌘⇧%@", [prefs stringForKey:@"Shortcut"]];
}
- (void)setMessage:(NSString *)text {
    savedMessage = text;
    message.stringValue = text;
    status.button.toolTip = text;
}
- (void)setBusy:(BOOL)value {
    busy = value;
    captureButton.enabled = openButton.enabled = !value;
    status.button.title = value ? @"…" : @"";
}
- (void)registerShortcut {
    if (hotkey) { UnregisterEventHotKey(hotkey); hotkey = NULL; }
    NSString *key = [prefs stringForKey:@"Shortcut"];
    UInt32 code = [@{@"2":@19, @"8":@28, @"9":@25}[key] unsignedIntValue];
    OSStatus result = RegisterEventHotKey(code, cmdKey | shiftKey,
        (EventHotKeyID){0x4d4f5445, 1}, GetApplicationEventTarget(), 0, &hotkey);
    captureMenu.keyEquivalent = key;
    captureMenu.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    for (NSMenuItem *item in NSApp.mainMenu.itemArray.firstObject.submenu.itemArray) {
        if (item.action == @selector(capture:)) {
            item.keyEquivalent = key;
            item.keyEquivalentModifierMask = captureMenu.keyEquivalentModifierMask;
        }
    }
    captureButton.title = [NSString stringWithFormat:@"Capture text   %@", self.shortcut];
    if (result != noErr) [self setMessage:@"Shortcut is in use. Choose another in the Mote menu."];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    prefs = NSUserDefaults.standardUserDefaults;
    [prefs registerDefaults:@{@"Shortcut":@"2", @"Fast":@NO, @"Correction":@YES, @"ShowResult":@NO}];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *support = [[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"Mote" isDirectory:YES];
    NSError *stateError = nil;
    [fm createDirectoryAtURL:support withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&stateError];
    stateURL = [support URLByAppendingPathComponent:@"last-result.txt"];
    lastText = [NSString stringWithContentsOfURL:stateURL encoding:NSUTF8StringEncoding error:nil] ?: @"";
    savedMessage = stateError ? @"Local storage unavailable. Captures can still be copied." : @"Ready. Select an area, then paste its words anywhere.";

    status = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    status.button.image = [NSImage imageWithSystemSymbolName:@"text.viewfinder" accessibilityDescription:@"Mote"];
    status.button.image.template = YES;
    status.button.toolTip = @"Mote — copy text from your screen";
    NSMenu *menu = [NSMenu new]; menu.delegate = (id)self; status.menu = menu;
    captureMenu = [self item:@"Capture text" action:@selector(capture:) menu:menu];
    [self item:@"Open image…" action:@selector(openImage:) menu:menu];
    [self item:@"Show Mote / last result" action:@selector(show:) menu:menu];
    [self item:@"Copy last result" action:@selector(copyResult:) menu:menu];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenu *shortcuts = [NSMenu new];
    for (NSString *key in @[@"2", @"8", @"9"]) {
        NSMenuItem *item = [self item:[@"⌘⇧" stringByAppendingString:key] action:@selector(changeShortcut:) menu:shortcuts];
        item.representedObject = key;
    }
    [self item:@"Keyboard shortcut" action:NULL menu:menu].submenu = shortcuts;
    [self item:@"Fast recognition" action:@selector(toggle:) menu:menu].representedObject = @"Fast";
    [self item:@"Language correction" action:@selector(toggle:) menu:menu].representedObject = @"Correction";
    [self item:@"Show result after capture" action:@selector(toggle:) menu:menu].representedObject = @"ShowResult";
    [menu addItem:NSMenuItem.separatorItem];
    [self item:@"Screen capture permission…" action:@selector(permission:) menu:menu];
    [self item:@"Reveal saved text" action:@selector(reveal:) menu:menu];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [self item:@"Quit Mote" action:@selector(quit:) menu:menu];
    quit.keyEquivalent = @"q";

    // Standard application/edit menus make text selection and keyboard navigation work.
    NSMenu *main = [NSMenu new];
    NSMenuItem *appItem = [main addItemWithTitle:@"Mote" action:NULL keyEquivalent:@""];
    // The same actions are keyboard-accessible from the app menu as from its status item.
    NSMenu *appMenu = [menu copy]; appMenu.delegate = (id)self; appItem.submenu = appMenu;
    NSMenuItem *edit = [main addItemWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    NSMenu *editMenu = [NSMenu new]; edit.submenu = editMenu;
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:NSMenuItem.separatorItem];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSApp.mainMenu = main;
    EventTypeSpec event = {kEventClassKeyboard, kEventHotKeyPressed};
    InstallEventHandler(GetApplicationEventTarget(), Hotkey, 1, &event, (__bridge void *)self, NULL);
    [self show:nil];
    [self registerShortcut];
}
- (void)show:(id)sender {
    if (!window) {
        window = [[MoteWindow alloc] initWithContentRect:NSMakeRect(0, 0, 520, 560)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered defer:NO];
        window.title = @"Mote"; window.releasedWhenClosed = NO;
        [window setFrameAutosaveName:@"MoteWindow"];
        NSView *view = window.contentView;
        Label(@"Copy the uncopyable.", 29, NSMakeRect(28, 488, 464, 42), view);
        Label(@"Drag over text on your screen. Paste its words anywhere.", 16, NSMakeRect(28, 438, 464, 44), view);
        captureButton = [self button:[NSString stringWithFormat:@"Capture text   %@", self.shortcut] action:@selector(capture:) frame:NSMakeRect(24, 379, 295, 44)];
        captureButton.keyEquivalent = @"\r";
        captureButton.bezelColor = NSColor.controlAccentColor;
        openButton = [self button:@"Open image…" action:@selector(openImage:) frame:NSMakeRect(328, 379, 168, 44)];
        message = Label(savedMessage, 14, NSMakeRect(28, 320, 464, 48), view);
        Label(@"LAST RESULT", 14, NSMakeRect(28, 284, 340, 23), view).textColor = NSColor.secondaryLabelColor;
        copyButton = [self button:@"Copy again" action:@selector(copyResult:) frame:NSMakeRect(374, 278, 123, 33)];
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(28, 98, 464, 172)];
        scroll.hasVerticalScroller = YES; scroll.borderType = NSBezelBorder;
        resultView = [[NSTextView alloc] initWithFrame:scroll.bounds];
        resultView.editable = NO; resultView.selectable = YES;
        resultView.font = [NSFont systemFontOfSize:16];
        resultView.textContainerInset = NSMakeSize(12, 12);
        resultView.autoresizingMask = NSViewWidthSizable;
        resultView.textContainer.widthTracksTextView = YES;
        resultView.verticallyResizable = YES;
        resultView.accessibilityLabel = @"Recognized text";
        scroll.documentView = resultView; [view addSubview:scroll];
        Label(@"On-device recognition. Last text saved on this Mac.\nScreenshots stay in memory. Settings are in the menu bar.", 14, NSMakeRect(28, 39, 464, 45), view);
        Label(@"Mote 0.1.2 · Apple Silicon", 14, NSMakeRect(28, 10, 464, 23), view);
        captureButton.nextKeyView = openButton;
        openButton.nextKeyView = copyButton;
        copyButton.nextKeyView = resultView;
        resultView.nextKeyView = captureButton;
        window.initialFirstResponder = captureButton;
        [window center];
    }
    resultView.string = lastText.length ? lastText : @"Your captured text will appear here.";
    copyButton.enabled = lastText.length > 0;
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:captureButton];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    [self show:nil]; return NO;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return NO; }
- (void)menuNeedsUpdate:(NSMenu *)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == @selector(toggle:)) item.state = [prefs boolForKey:item.representedObject] ? NSControlStateValueOn : NSControlStateValueOff;
        for (NSMenuItem *child in item.submenu.itemArray)
            child.state = [child.representedObject isEqual:[prefs stringForKey:@"Shortcut"]] ? NSControlStateValueOn : NSControlStateValueOff;
    }
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(capture:) || item.action == @selector(openImage:)) return !busy;
    if (item.action == @selector(copyResult:) || item.action == @selector(reveal:)) return lastText.length > 0;
    return YES;
}
- (void)changeShortcut:(NSMenuItem *)item {
    [prefs setObject:item.representedObject forKey:@"Shortcut"];
    [self setMessage:@"Shortcut updated."]; [self registerShortcut];
}
- (void)toggle:(NSMenuItem *)item {
    [prefs setBool:![prefs boolForKey:item.representedObject] forKey:item.representedObject];
}
- (void)permission:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];
}
- (void)reveal:(id)sender { [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[stateURL]]; }
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (void)applicationWillTerminate:(NSNotification *)notification {
    if (hotkey) UnregisterEventHotKey(hotkey);
}
- (void)copyResult:(id)sender {
    if (!lastText.length) return;
    if (CopyText(lastText)) [self setMessage:@"Copied. Paste with ⌘V."];
    else [self setMessage:@"Clipboard unavailable. Select and copy the text below."];
}
- (void)finish:(NSString *)text error:(NSError *)error elapsed:(NSTimeInterval)elapsed {
    [self setBusy:NO];
    if (error) {
        [self setMessage:[@"Could not read image: " stringByAppendingString:error.localizedDescription]];
        [self show:nil]; return;
    }
    if (!text.length) {
        [self setMessage:@"No text found. Try a larger area or turn off Fast recognition. Clipboard unchanged."];
        [self show:nil]; return;
    }
    lastText = text;
    NSError *saveError = nil;
    BOOL saved = [text writeToURL:stateURL atomically:YES encoding:NSUTF8StringEncoding error:&saveError];
    if (saved) chmod(stateURL.fileSystemRepresentation, 0600);
    BOOL copied = CopyText(lastText);
    NSString *outcome = copied ? [NSString stringWithFormat:@"Copied %lu characters in %.2f s. Paste with ⌘V.%@", (unsigned long)text.length, elapsed, saved ? @"" : @" Could not save the last result."] : @"Text recognized. Clipboard unavailable; select and copy the result below.";
    [self setMessage:outcome];
    status.button.title = copied ? @"✓" : @"!";
    resultView.string = text; copyButton.enabled = YES;
    if ([prefs boolForKey:@"ShowResult"] || !saved || !copied) [self show:nil];
}
- (void)readHandler:(VNImageRequestHandler *)handler {
    BOOL fast = [prefs boolForKey:@"Fast"], correction = [prefs boolForKey:@"Correction"];
    [self setMessage:@"Reading text on your Mac…"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSTimeInterval start = NSProcessInfo.processInfo.systemUptime;
            NSError *error = nil;
            NSString *text = Recognize(handler, fast, correction, &error);
            NSTimeInterval elapsed = NSProcessInfo.processInfo.systemUptime - start;
            dispatch_async(dispatch_get_main_queue(), ^{ [self finish:text error:error elapsed:elapsed]; });
        }
    });
}
- (void)openImage:(id)sender {
    if (busy) return;
    [self setBusy:YES];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = NO; panel.allowsMultipleSelection = NO;
    panel.message = @"Choose an image to copy its text. The original file stays unchanged.";
    [NSApp activateIgnoringOtherApps:YES];
    if ([panel runModal] != NSModalResponseOK) { [self setBusy:NO]; return; }
    [self readHandler:[[VNImageRequestHandler alloc] initWithURL:panel.URL options:@{}]];
}
- (void)capture:(id)sender {
    if (busy) return;
    [self setBusy:YES];
    [self setMessage:@"Preparing screen capture…"];
    NSScreen *screen = NSScreen.mainScreen;
    for (NSScreen *candidate in NSScreen.screens)
        if (NSPointInRect(NSEvent.mouseLocation, candidate.frame)) screen = candidate;
    [window orderOut:nil];
    // Capture one still on the display under the pointer. Exclude our own windows
    // explicitly, avoiding compositor delays and accidentally recognizing our UI.
    [SCShareableContent getShareableContentExcludingDesktopWindows:NO onScreenWindowsOnly:YES completionHandler:^(SCShareableContent *content, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setBusy:NO];
                BOOL denied = [error.domain isEqualToString:SCStreamErrorDomain] && error.code == SCStreamErrorUserDeclined;
                [self setMessage:denied ? @"Allow Mote in System Settings → Privacy & Security → Screen & System Audio Recording, then try again." : @"Screen capture could not start. Check the display connection and try again."];
                [self show:nil];
            }); return;
        }
        SCDisplay *display = nil;
        for (SCDisplay *candidate in content.displays)
            if (candidate.displayID == [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue]) display = candidate;
        if (!display) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self setBusy:NO]; [self setMessage:@"Display disconnected. Move the pointer to another display and try again."]; [self show:nil]; }); return;
        }
        NSMutableArray *excluded = [NSMutableArray new];
        for (SCRunningApplication *app in content.applications)
            if (app.processID == NSProcessInfo.processInfo.processIdentifier) [excluded addObject:app];
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingApplications:excluded exceptingWindows:@[]];
        SCStreamConfiguration *config = [SCStreamConfiguration new];
        config.width = NSWidth(screen.frame) * screen.backingScaleFactor;
        config.height = NSHeight(screen.frame) * screen.backingScaleFactor;
        config.showsCursor = NO;
        [SCScreenshotManager captureImageWithFilter:filter configuration:config completionHandler:^(CGImageRef cgImage, NSError *captureError) {
            if (cgImage) CGImageRetain(cgImage);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!cgImage) { [self finish:nil error:captureError ?: [NSError errorWithDomain:@"Mote" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Screen image unavailable. Try again."}] elapsed:0]; return; }
                NSImage *snapshot = [[NSImage alloc] initWithCGImage:cgImage size:screen.frame.size];
                CGImageRelease(cgImage);
                [self selectSnapshot:snapshot screen:screen];
            });
        }];
    }];
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    if (notification.object != selectionWindow) return;
    // Activation is asynchronous. Apply after AppKit finishes changing the key
    // window, so its cursor reset cannot leave the system pointer as an arrow.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (selectionWindow.keyWindow) [NSCursor.crosshairCursor set];
    });
}
- (void)selectSnapshot:(NSImage *)snapshot screen:(NSScreen *)screen {
    selectionWindow = [[SelectionWindow alloc] initWithContentRect:screen.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    selectionWindow.delegate = (id)self;
    selectionWindow.title = @"Mote — Select text";
    selectionWindow.releasedWhenClosed = NO;
    selectionWindow.level = NSStatusWindowLevel + 1;
    selectionWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    SelectionView *view = [[SelectionView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(screen.frame), NSHeight(screen.frame))];
    view.snapshot = snapshot;
    view.accessibilityLabel = @"Select text. Drag a rectangle. Escape cancels.";
    __weak Mote *weakSelf = self;
    view.completion = ^(NSRect rect) {
        Mote *self = weakSelf;
        [self->selectionWindow close]; self->selectionWindow = nil;
        [NSCursor.arrowCursor set];
        if (NSIsEmptyRect(rect)) { [self setBusy:NO]; [self setMessage:@"Capture cancelled. Clipboard unchanged."]; return; }
        CGImageRef source = [snapshot CGImageForProposedRect:NULL context:nil hints:nil];
        CGFloat sx = CGImageGetWidth(source) / NSWidth(screen.frame), sy = CGImageGetHeight(source) / NSHeight(screen.frame);
        CGRect pixels = CGRectMake(NSMinX(rect)*sx, (NSHeight(screen.frame)-NSMaxY(rect))*sy, NSWidth(rect)*sx, NSHeight(rect)*sy);
        CGImageRef crop = CGImageCreateWithImageInRect(source, pixels);
        if (!crop) { [self finish:nil error:[NSError errorWithDomain:@"Mote" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Selection could not be read. Try again."}] elapsed:0]; return; }
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:crop options:@{}];
        CGImageRelease(crop);
        [self readHandler:handler];
    };
    selectionWindow.contentView = view;
    [NSApp activateIgnoringOtherApps:YES];
    [selectionWindow makeKeyAndOrderFront:nil];
    [selectionWindow makeFirstResponder:view];
    // A shortcut can open the overlay under a stationary pointer, without a
    // cursor-rectangle entry event. Activate its cursor immediately as well.
    [selectionWindow invalidateCursorRectsForView:view];
    [NSCursor.crosshairCursor set];
}
@end

int main(int argc, const char **argv) {
    @autoreleasepool {
        // A real CLI path shares the exact OCR code with the app for repeatable tests.
        if (argc >= 3 && !strcmp(argv[1], "--ocr")) {
            NSError *error = nil;
            BOOL fast = argc > 3 && !strcmp(argv[3], "fast");
            VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithURL:[NSURL fileURLWithPath:@(argv[2])] options:@{}];
            NSString *text = Recognize(handler, fast, YES, &error);
            if (!text) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1; }
            if (text.length) puts(text.UTF8String);
            return text.length ? 0 : 3;
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __attribute__((objc_precise_lifetime)) Mote *delegate = [Mote new];
        app.delegate = (id)delegate;
        [app run];
    }
    return 0;
}
