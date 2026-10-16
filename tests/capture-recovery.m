// Exercise focus recovery without requesting screen access or capturing content.
#define main PluckApplicationMain
#ifdef COMPACT
#include "../experiments/runtime/build/Mote.m"
#else
#include "../Mote.m"
#endif
#undef main

@interface RecoveryWindow : NSWindow
@property NSUInteger activations;
@property BOOL pretendKey;
@end
@implementation RecoveryWindow
- (void)makeKeyAndOrderFront:(id)sender { self.activations++; self.pretendKey = YES; }
- (BOOL)isKeyWindow { return self.pretendKey; }
@end

static void SetSelection(id controller, NSWindow *fixture) {
#ifdef COMPACT
    selectionWindow = (id)fixture;
#else
    [controller setValue:fixture forKey:@"selectionWindow"];
#endif
}

int main(void) {
    @autoreleasepool {
        [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyProhibited];
#ifdef COMPACT
        RegisterClasses();
#endif
        id controller = [[NSClassFromString(@"Mote") alloc] init];
        RecoveryWindow *fixture = [[RecoveryWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        fixture.releasedWhenClosed = NO;
        [controller setBusy:YES];
        SetSelection(controller, fixture);
        [controller capture:nil];
        if (fixture.activations != 1) { puts("FAIL: retry did not recover the pending selector"); return 1; }
        [controller capture:nil];
        if (fixture.activations != 2) { puts("FAIL: retry did not reuse the selector"); return 1; }
        NSNotification *activation = [NSNotification notificationWithName:NSApplicationDidBecomeActiveNotification object:NSApp];
        fixture.pretendKey = NO;
        [controller applicationDidBecomeActive:activation];
        if (fixture.activations != 3) { puts("FAIL: activation did not recover focus"); return 1; }
        [controller applicationDidBecomeActive:activation];
        if (fixture.activations != 3) { puts("FAIL: active selector was unnecessarily reactivated"); return 1; }
        SetSelection(controller, nil);
        [controller capture:nil];
        [controller applicationDidBecomeActive:activation];
        if (fixture.activations != 3) return 1;
        puts("PASS: retry reuses selection, activation restores focus, busy OCR starts no second capture");
    }
    return 0;
}
