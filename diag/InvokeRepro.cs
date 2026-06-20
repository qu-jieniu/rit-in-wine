// Minimal repro of RIT's hang pattern:
//   - real WinForms UI thread with a window + message pump
//   - HttpListener on a worker thread
//   - every request handler marshals onto the UI thread via Control.Invoke
//   - returns a tiny JSON-ish body
//
// Under Windows: GET / returns "ok 1" in ms.
// Under Wine 10: expectation per RIT diagnosis = curl hangs after request sent.
using System;
using System.Net;
using System.Text;
using System.Threading;
using System.Windows.Forms;

class Repro : Form {
    HttpListener l;
    int n;
    [STAThread]
    static void Main(string[] a) { Application.Run(new Repro(a.Length > 0 ? a[0] : "http://+:9995/")); }
    Repro(string prefix) {
        Text = "InvokeRepro";
        Width = 400; Height = 200;
        var lbl = new Label { Dock = DockStyle.Fill, Text = "listening on " + prefix };
        Controls.Add(lbl);
        l = new HttpListener();
        l.Prefixes.Add(prefix);
        l.Start();
        l.BeginGetContext(OnCtx, null);
        Console.WriteLine("STARTED " + prefix + " ui_thread=" + Thread.CurrentThread.ManagedThreadId);
    }
    void OnCtx(IAsyncResult ar) {
        HttpListenerContext ctx;
        try { ctx = l.EndGetContext(ar); }
        catch (Exception ex) { Console.WriteLine("end err: " + ex.Message); return; }
        l.BeginGetContext(OnCtx, null);
        Console.WriteLine("WORKER got " + ctx.Request.Url + " worker_thread=" + Thread.CurrentThread.ManagedThreadId);
        object body;
        try {
            if (this.InvokeRequired) {
                Console.WriteLine("WORKER calling Invoke...");
                body = this.Invoke(new Func<string>(() => {
                    Console.WriteLine("UI got the delegate ui_thread=" + Thread.CurrentThread.ManagedThreadId);
                    return "ok " + Interlocked.Increment(ref n);
                }));
                Console.WriteLine("WORKER Invoke returned");
            } else {
                body = "ok-direct " + Interlocked.Increment(ref n);
            }
        } catch (Exception ex) {
            Console.WriteLine("invoke err: " + ex);
            body = "err: " + ex.Message;
        }
        var b = Encoding.UTF8.GetBytes(body.ToString() + "\n");
        ctx.Response.ContentLength64 = b.Length;
        ctx.Response.OutputStream.Write(b, 0, b.Length);
        ctx.Response.OutputStream.Close();
        Console.WriteLine("WORKER replied " + b.Length + " bytes");
    }
}
