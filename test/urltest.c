/*
 * urltest.c -- regression test for Wine's http.sys '*' wildcard host bug.
 *
 * RIT registers its REST API as "http://*:9999/" via .NET HttpListener. Stock
 * Wine's dlls/http.sys/http.c::host_matches only treats '+' as a wildcard host,
 * so a '*' registration matches no incoming Host header: the driver accepts the
 * connection but never hands the request to user mode, and the listener hangs
 * forever. The one-line patch extends the wildcard branch to also accept '*'.
 *
 * This program reproduces exactly that, with no .NET and no winetricks: it
 * registers "http://*:PORT/" through the HTTP Server API (the same kernel path
 * HttpListener uses), fires a plain TCP HTTP request at 127.0.0.1:PORT, and
 * checks whether the request is delivered.
 *
 *   PASS (exit 0): HttpReceiveHttpRequest delivered the request  -> patched driver
 *   FAIL (exit 1): timed out waiting for the request             -> stock driver bug
 *
 * Builds for x86_64 and aarch64 with the matching mingw clang/gcc.
 */
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <http.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static int PORT = 9999;
#define RECV_TIMEOUT_MS 8000

/* Connects after a short delay and sends one HTTP/1.1 request with a concrete
 * Host header, which http.sys must match against the wildcard registration. */
static DWORD WINAPI client_thread(LPVOID arg)
{
    (void)arg;
    Sleep(800); /* give the server time to post its receive */

    SOCKET s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == INVALID_SOCKET) { printf("CLIENT: socket failed %d\n", WSAGetLastError()); return 1; }

    struct sockaddr_in sa;
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_port = htons((u_short)PORT);
    sa.sin_addr.s_addr = inet_addr("127.0.0.1");

    if (connect(s, (struct sockaddr *)&sa, sizeof(sa)) != 0) {
        printf("CLIENT: connect failed %d\n", WSAGetLastError());
        closesocket(s);
        return 1;
    }

    char req[256];
    int n = _snprintf(req, sizeof(req),
        "GET /v1/case HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nConnection: close\r\n\r\n", PORT);
    send(s, req, n, 0);
    printf("CLIENT: sent GET /v1/case (Host: 127.0.0.1:%d)\n", PORT);

    /* Drain whatever comes back so the server side can complete cleanly. */
    char resp[512];
    recv(s, resp, sizeof(resp), 0);
    closesocket(s);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc > 1) PORT = atoi(argv[1]);
    setvbuf(stdout, NULL, _IONBF, 0); /* keep output even if the process dies early */

    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);

    HTTPAPI_VERSION ver = HTTPAPI_VERSION_1;
    ULONG r = HttpInitialize(ver, HTTP_INITIALIZE_SERVER, NULL);
    if (r) { printf("HttpInitialize failed %lu\n", r); return 2; }

    HANDLE queue = NULL;
    r = HttpCreateHttpHandle(&queue, 0);
    if (r) { printf("HttpCreateHttpHandle failed %lu\n", r); return 2; }

    wchar_t url[64];
    _snwprintf(url, 64, L"http://*:%d/", PORT);
    r = HttpAddUrl(queue, url, NULL);
    if (r) { wprintf(L"HttpAddUrl(%ls) failed %lu\n", url, r); return 2; }
    wprintf(L"SERVER: registered %ls\n", url);

    HANDLE ev = CreateEventW(NULL, TRUE, FALSE, NULL);
    OVERLAPPED ov;
    memset(&ov, 0, sizeof(ov));
    ov.hEvent = ev;

    char buf[8192];
    r = HttpReceiveHttpRequest(queue, HTTP_NULL_ID, 0,
                               (PHTTP_REQUEST)buf, sizeof(buf), NULL, &ov);
    if (r != NO_ERROR && r != ERROR_IO_PENDING) {
        printf("HttpReceiveHttpRequest failed %lu\n", r);
        return 2;
    }

    CreateThread(NULL, 0, client_thread, NULL, 0, NULL);

    DWORD w = WaitForSingleObject(ev, RECV_TIMEOUT_MS);
    if (w == WAIT_OBJECT_0) {
        DWORD bytes = 0;
        GetOverlappedResult(queue, &ov, &bytes, FALSE);
        PHTTP_REQUEST got = (PHTTP_REQUEST)buf;
        wprintf(L"PASS: request delivered (%lu bytes) url=%ls\n",
                bytes, got->CookedUrl.pFullUrl ? got->CookedUrl.pFullUrl : L"(null)");
        return 0;
    }

    printf("FAIL: request never delivered within %d ms -- stock http.sys '*' wildcard bug\n",
           RECV_TIMEOUT_MS);
    return 1;
}
