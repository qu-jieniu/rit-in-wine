// Async variant — uses BeginGetContext like most real-world .NET servers.
// If this hangs the same way RIT does, the bug is in Wine httpapi/http.sys
// async completion. If it works, RIT is doing something else (e.g. blocking
// in its own response handler, or using a WCF / Web API stack that
// internally re-enters httpapi differently).
using System;
using System.Net;
using System.Text;
using System.Threading;

class P {
    static HttpListener l;
    static int n = 0;
    static void Main(string[] a) {
        var prefix = a.Length > 0 ? a[0] : "http://+:9996/";
        l = new HttpListener();
        l.Prefixes.Add(prefix);
        l.Start();
        Console.WriteLine("async listening on " + prefix);
        l.BeginGetContext(OnCtx, null);
        Thread.Sleep(Timeout.Infinite);
    }
    static void OnCtx(IAsyncResult ar) {
        HttpListenerContext ctx;
        try { ctx = l.EndGetContext(ar); }
        catch (Exception ex) { Console.WriteLine("end err: " + ex.Message); return; }
        l.BeginGetContext(OnCtx, null);
        var b = Encoding.UTF8.GetBytes("async hit #" + Interlocked.Increment(ref n) + " " + ctx.Request.Url + "\n");
        ctx.Response.ContentLength64 = b.Length;
        ctx.Response.OutputStream.Write(b, 0, b.Length);
        ctx.Response.OutputStream.Close();
        Console.WriteLine("async replied " + b.Length + " bytes for " + ctx.Request.Url);
    }
}
