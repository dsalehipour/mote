// Exercise the production shortcut registration against a second real process.
#define main PluckApplicationMain
#ifdef COMPACT
#include "../experiments/runtime/build/Mote.m"
#else
#include "../Mote.m"
#endif
#undef main

static BOOL Attempt(id controller, BOOL expectConflict) {
    [controller setMessage:@"Registration succeeded."];
    [controller registerShortcut];
#ifdef COMPACT
    NSString *outcome = savedMessage;
#else
    NSString *outcome = [controller valueForKey:@"savedMessage"];
#endif
    BOOL conflict = [outcome hasPrefix:@"Shortcut is in use."];
    printf("%s: expected %s, received %s\n", conflict == expectConflict ? "PASS" : "FAIL",
           expectConflict ? "conflict" : "success", conflict ? "conflict" : "success");
    return conflict == expectConflict;
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyProhibited];
        if (argc > 1 && !strcmp(argv[1], "--hold")) {
            EventHotKeyRef held = NULL;
            OSStatus result = RegisterEventHotKey(25, cmdKey | shiftKey,
                (EventHotKeyID){0x54455354, 1}, GetApplicationEventTarget(), kEventHotKeyExclusive, &held);
            putchar(result == noErr ? 'R' : 'E'); fflush(stdout);
            if (result != noErr) return 2;
            // EOF releases the fixture even if the parent test is interrupted.
            getchar();
            UnregisterEventHotKey(held);
            return 0;
        }
#ifdef COMPACT
        RegisterClasses();
#endif
        // Registration defaults stay in memory and do not alter app preferences.
        prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.darius.pluck.hotkey-test"];
        [prefs registerDefaults:@{@"Shortcut":@"9"}];
        id controller = [[NSClassFromString(@"Mote") alloc] init];
        BOOL passed = YES;
        NSTask *holder = [NSTask new];
        holder.executableURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[0]]];
        holder.arguments = @[@"--hold"];
        NSPipe *ready = [NSPipe pipe]; holder.standardOutput = ready;
        NSPipe *lifetime = [NSPipe pipe]; holder.standardInput = lifetime;
        NSError *error = nil;
        if (![holder launchAndReturnError:&error]) {
            fprintf(stderr, "Cannot start conflict fixture: %s\n", error.localizedDescription.UTF8String);
            return 2;
        }
        @try {
            NSData *signal = [ready.fileHandleForReading readDataOfLength:1];
            if (signal.length != 1 || ((const char *)signal.bytes)[0] != 'R') return 2;
            passed = Attempt(controller, YES) && passed;
        } @finally {
            [lifetime.fileHandleForWriting closeFile]; [holder waitUntilExit];
        }
        passed = Attempt(controller, NO) && passed;
        return passed ? 0 : 1;
    }
}
