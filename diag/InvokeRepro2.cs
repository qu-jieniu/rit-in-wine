// Closer repro: matches RIT's pattern exactly.
//   - sync Listener.GetContext() in a ThreadPool worker
//   - per-request ThreadPool.QueueUserWorkItem
//   - HandleRequest does Control.Invoke onto the UI thread
// Also adds heavy UI work so the UI thread isn't sitting idle.
using System;
using System.Net;
using System.Text;
using System.Threading;
using System.Windows.Forms;

class Repro : Form {
    HttpListener l;
    int n;
    System.Windows.Forms.Timer t;
    int spin;
    [STAThread]
    static void Main(string[] a) { Application.Run(new Repro(a.Length > 0 ? a[0] : "http://+:9994/")); }
    Repro(string prefix) {
        Text = "InvokeRepro2";
        Width = 600; Height = 400;
        var lbl = new Label { Dock = DockStyle.Fill, Text = "listening on " + prefix };
        Controls.Add(lbl);
        // Simulate RIT-style busy UI: many controls + timer doing work.
        for (int i = 0; i < 30; i++) Controls.Add(new Label { Text = "filler " + i, Top = 10 * i, Left = 200 });
        t = new System.Windows.Forms.Timer { Interval = 5 };
        t.Tick += (s, e) => {
            // Busy work on UI thread.
            for (int i = 0; i < 50000; i++) spin = (spin * 1103515245 + 12345) & 0x7fffffff;
            lbl.Text = "spin=" + spin + " n=" + n;
        };
        t.Start();
        l = new HttpListener();
        l.Prefixes.Add(prefix);
        l.Start();
        ThreadPool.QueueUserWorkItem(delegate {
            try {
                while (l.IsListening) {
                    var ctx = l.GetContext();
                    ThreadPool.QueueUserWorkItem(_ => HandleRequest(ctx));
                }
            } catch (Exception ex) { Console.WriteLine("accept loop err: " + ex.Message); }
        });
        Console.WriteLine("STARTED " + prefix + " ui_thread=" + Thread.CurrentThread.ManagedThreadId);
    }
    void HandleRequest(HttpListenerContext ctx) {
        Console.WriteLine("WORKER got " + ctx.Request.Url + " worker_thread=" + Thread.CurrentThread.ManagedThreadId);
        object body;
        try {
            if (this.InvokeRequired) {
                Console.WriteLine("WORKER calling Invoke...");
                body = this.Invoke(new Func<string>(() => {
                    Console.WriteLine("UI got delegate ui_thread=" + Thread.CurrentThread.ManagedThreadId);
                    return "ok " + Interlocked.Increment(ref n);
                }));
                Console.WriteLine("WORKER Invoke returned");
            } else body = "ok-direct " + Interlocked.Increment(ref n);
        } catch (Exception ex) {
            Console.WriteLine("invoke err: " + ex);
            body = "err: " + ex.Message;
        }
        var b = Encoding.UTF8.GetBytes(body.ToString() + "\n");
        ctx.Response.ContentLength64 = b.Length;
        ctx.Response.OutputStream.Write(b, 0, b.Length);
        ctx.Response.OutputStream.Close();
    }
}
