// Probe: listen on a *narrower* prefix than RIT (or on 9997 only).
// If 9999 comes back open while this runs, T2 wins (http.sys binds RIT's
// prefix on side effect). If 9999 stays closed, T1 wins (my wildcard
// from the earlier test was hijacking it).
using System;
using System.Net;
using System.Text;

class P {
    static void Main(string[] a) {
        var l = new HttpListener();
        foreach (var p in a) l.Prefixes.Add(p);
        l.Start();
        Console.WriteLine("listening on:");
        foreach (var p in l.Prefixes) Console.WriteLine("  " + p);
        while (true) {
            var ctx = l.GetContext();
            Console.WriteLine("got " + ctx.Request.Url);
            var b = Encoding.UTF8.GetBytes("from probe at " + DateTime.UtcNow.ToString("o") + "\n");
            ctx.Response.ContentLength64 = b.Length;
            ctx.Response.OutputStream.Write(b, 0, b.Length);
            ctx.Response.OutputStream.Close();
        }
    }
}
