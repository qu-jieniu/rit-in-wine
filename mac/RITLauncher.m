// RIT.app launcher for Intel Macs — native stock Wine (no Rosetta, no VM).
// Successor to the old launcher.m, hardened for the multi-process teardown:
//
//   Graceful quit  (⌘Q / close window / Wine exits):
//       kill the Wine process GROUP + `wineserver -k`  (the proven path).
//   Force Quit / kill -9 of this launcher:
//       a detached kqueue WATCHDOG notices the launcher died and runs the same
//       teardown — closing the gap the old launcher had.
//
// Why both: Wine's `wineserver` and services (services.exe, plugplay, winedevice,
// explorer) setsid() into their own session, so a process-group kill alone misses
// them — `wineserver -k` is the reliable catch-all. And SIGKILL is uncatchable, so
// the watchdog (a separate session that outlives the launcher) is the only way to
// guarantee teardown on Force Quit. The watchdog self-terminates right after; it
// does not linger.

#import <Cocoa/Cocoa.h>
#include <spawn.h>
#include <sys/event.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>

extern char **environ;

static NSString *gPrefix = nil;
static NSString *gWineserver = nil;
static pid_t     gWinePid = 0;   // Wine process-group leader

// Kill the whole Wine session: the process group, then the per-prefix server.
static void teardown(void) {
    if (gWinePid > 0) killpg(gWinePid, SIGTERM);
    NSTask *t = [[NSTask alloc] init];
    t.launchPath = gWineserver;
    t.arguments  = @[@"-k"];
    t.environment = @{ @"WINEPREFIX": gPrefix };
    @try { [t launch]; [t waitUntilExit]; } @catch (NSException *e) {}
    if (gWinePid > 0) killpg(gWinePid, SIGKILL);   // anything still standing
}

// The watchdog: runs in its own session so it survives a Force Quit of the
// launcher. Blocks on the launcher's exit (kqueue NOTE_EXIT — fires even on
// SIGKILL), then tears Wine down and exits. Not a daemon: it lives only as long
// as the launcher, and is the LAST thing to die.
static void spawnWatchdog(pid_t launcherPid) {
    pid_t wd = fork();
    if (wd != 0) return;                 // parent (launcher) continues
    setsid();                            // detach from the launcher's group/session
    int kq = kqueue();
    struct kevent ke;
    EV_SET(&ke, launcherPid, EVFILT_PROC, EV_ADD, NOTE_EXIT, 0, NULL);
    if (kevent(kq, &ke, 1, NULL, 0, NULL) == 0) {
        struct kevent out;
        kevent(kq, NULL, 0, &out, 1, NULL);   // blocks until the launcher exits
    }
    teardown();
    _exit(0);
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
@implementation AppDelegate
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)s { teardown(); return NSTerminateNow; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)s { return YES; }
@end

static void waitForWine(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int st = 0; waitpid(gWinePid, &st, 0);
        dispatch_async(dispatch_get_main_queue(), ^{ [NSApp terminate:nil]; });
    });
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *res = [[NSBundle mainBundle] resourcePath];
        gPrefix     = [res stringByAppendingPathComponent:@"prefix"];
        NSString *wineBin   = [res stringByAppendingPathComponent:@"wine/bin/wine"];
        gWineserver = [res stringByAppendingPathComponent:@"wine/bin/wineserver"];

        // Native stock Wine, win32 prefix (RIT is 32-bit), .NET 4.8 + MSI baked.
        setenv("WINEPREFIX", [gPrefix UTF8String], 1);
        setenv("WINEARCH", "win32", 1);
        setenv("WINEDEBUG", "-all", 1);
        setenv("WINEDLLOVERRIDES", "mscoree=n;mshtml=d", 1);
        NSString *wineBinDir = [res stringByAppendingPathComponent:@"wine/bin"];
        setenv("PATH", [[NSString stringWithFormat:@"%@:%s", wineBinDir,
                         getenv("PATH") ?: "/usr/bin:/bin"] UTF8String], 1);

        [NSApplication sharedApplication];
        AppDelegate *d = [[AppDelegate alloc] init];
        [NSApp setDelegate:d];

        NSString *client = [gPrefix stringByAppendingPathComponent:
            @"drive_c/Program Files/Rotman/RIT User Application/Client.exe"];
        const char *args[] = { [wineBin UTF8String], [client UTF8String], NULL };

        // Spawn Wine as its own process-group leader so we can signal the tree.
        posix_spawnattr_t attr; posix_spawnattr_init(&attr);
        posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);
        posix_spawnattr_setpgroup(&attr, 0);
        int rc = posix_spawn(&gWinePid, [wineBin UTF8String], NULL, &attr, (char **)args, environ);
        posix_spawnattr_destroy(&attr);
        if (rc != 0) {
            NSAlert *a = [[NSAlert alloc] init];
            a.messageText = @"Failed to launch Wine";
            a.informativeText = [NSString stringWithFormat:@"posix_spawn errno %d", rc];
            [a runModal];
            return 1;
        }

        spawnWatchdog(getpid());   // Force-Quit insurance
        waitForWine();             // quit the app when RIT exits
        [NSApp run];
        teardown();                // belt-and-suspenders on normal return
    }
    return 0;
}
