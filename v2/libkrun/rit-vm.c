/*
 * rit-vm — boots the RIT payload in a libkrun microVM and maps its ports.
 *
 * This is the portable core of the v2 launcher: the SAME libkrun API calls
 * compile on Linux (KVM backend) and macOS/Apple-Silicon (Hypervisor.framework).
 * On Linux x86 the payload runs natively; on macOS arm64 the payload is amd64 and
 * runs under FEX inside the guest. The macOS RIT.app wraps this and shows the
 * noVNC desktop (port 6080) in a native window.
 *
 * API prototypes are declared inline so we don't need libkrun-devel headers.
 * Build:  cc rit-vm.c -o rit-vm -l:libkrun.so.1
 * Run:    ./rit-vm <rootfs-dir>
 */
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

extern int32_t krun_create_ctx(void);
extern int32_t krun_set_vm_config(uint32_t ctx_id, uint8_t num_vcpus, uint32_t ram_mib);
extern int32_t krun_set_root(uint32_t ctx_id, const char *root_path);
extern int32_t krun_set_port_map(uint32_t ctx_id, const char *const port_map[]);
extern int32_t krun_set_workdir(uint32_t ctx_id, const char *workdir_path);
extern int32_t krun_set_exec(uint32_t ctx_id, const char *exec_path,
                             const char *const argv[], const char *const envp[]);
extern int32_t krun_start_enter(uint32_t ctx_id);

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <rootfs-dir>\n", argv[0]); return 2; }

    int32_t ctx = krun_create_ctx();
    if (ctx < 0) { fprintf(stderr, "krun_create_ctx failed: %d\n", ctx); return 1; }

    /* 4 vCPUs, 4 GiB — enough for Wine + .NET + RIT + the desktop. */
    if (krun_set_vm_config(ctx, 4, 4096) < 0) { fprintf(stderr, "set_vm_config failed\n"); return 1; }

    if (krun_set_root(ctx, argv[1]) < 0) { fprintf(stderr, "set_root failed\n"); return 1; }
    krun_set_workdir(ctx, "/");

    /* Expose the web desktop and the REST API to the host. */
    const char *ports[] = { "6090:6080", "9970:9999", NULL };
    if (krun_set_port_map(ctx, ports) < 0) { fprintf(stderr, "set_port_map failed\n"); return 1; }

    const char *vargv[] = { NULL };
    const char *venv[]  = { "HOME=/root", "PATH=/usr/local/bin:/usr/bin:/bin", NULL };
    if (krun_set_exec(ctx, "/usr/local/bin/rit-desktop", vargv, venv) < 0) {
        fprintf(stderr, "set_exec failed\n"); return 1;
    }

    fprintf(stderr, "booting RIT microVM... (desktop: localhost:6080  api: localhost:9999)\n");
    return krun_start_enter(ctx);   /* boots the VM and blocks until it exits */
}
