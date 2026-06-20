// Mimic RIT's HandleRequest behavior for an OPTIONS request exactly:
//   - sync Listener.GetContext() + ThreadPool dispatch
//   - on the worker, set the SAME CORS headers RIT sets when Origin starts with http://rit.306w.
//   - write an empty body and Close().
// If this hangs under Wine, the bug is in HttpListenerResponse's flush path,
// not in Control.Invoke (which is not used here).
using System;
using System.Net;
using System.Text;
using System.Threading;

class Repro {
    static HttpListener l;
    static int n;
    static void Main(string[] a) {
        var prefix = a.Length > 0 ? a[0] : "http://+:9993/v1/";
        l = new HttpListener();
        l.Prefixes.Add(prefix);
        l.Start();
        Console.WriteLine("listening on " + prefix);
        ThreadPool.QueueUserWorkItem(_ => {
            try {
                while (l.IsListening) {
                    var ctx = l.GetContext();
                    ThreadPool.QueueUserWorkItem(c => Handle(c as HttpListenerContext), ctx);
                }
            } catch (Exception ex) { Console.WriteLine("accept err: " + ex.Message); }
        });
        Thread.Sleep(Timeout.Infinite);
    }
    static void Handle(HttpListenerContext context) {
        var i = Interlocked.Increment(ref n);
        Console.WriteLine("WORKER #" + i + " " + context.Request.HttpMethod + " " + context.Request.Url + " tid=" + Thread.CurrentThread.ManagedThreadId);
        byte[] array = new byte[0];
        try {
            // For non-OPTIONS, build a tiny JSON body.
            if (context.Request.HttpMethod != "OPTIONS") {
                array = Encoding.UTF8.GetBytes("{\"n\":" + i + "}");
            }
        } finally {
            // EXACT same finally block as RIT's HandleRequest.
            string origin = context.Request.Headers.Get("Origin");
            if (origin != null && (origin.StartsWith("http://rit.306w.") || origin.StartsWith("https://rit.306w."))) {
                context.Response.AddHeader("Access-Control-Allow-Origin", origin);
                context.Response.AddHeader("Access-Control-Allow-Headers", context.Request.Headers.Get("Access-Control-Request-Headers") ?? "*");
                context.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS, DELETE");
                context.Response.AddHeader("Access-Control-Max-Age", "1");
            }
            context.Response.ContentType = "application/json";
            context.Response.ContentLength64 = array.Length;
            Console.WriteLine("WORKER #" + i + " writing " + array.Length + " bytes");
            context.Response.OutputStream.Write(array, 0, array.Length);
            Console.WriteLine("WORKER #" + i + " closing OutputStream");
            context.Response.OutputStream.Close();
            Console.WriteLine("WORKER #" + i + " done");
        }
    }
}
