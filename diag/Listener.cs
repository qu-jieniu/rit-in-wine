using System;
using System.Net;
using System.Text;

class P {
    static void Main(string[] a) {
        var prefix = a.Length > 0 ? a[0] : "http://+:9998/";
        var l = new HttpListener();
        l.Prefixes.Add(prefix);
        l.Start();
        Console.WriteLine("listening on " + prefix);
        while (true) {
            var ctx = l.GetContext();
            Console.WriteLine("got " + ctx.Request.Url);
            var b = Encoding.UTF8.GetBytes("hello at " + DateTime.UtcNow.ToString("o") + "\n");
            ctx.Response.ContentType = "text/plain";
            ctx.Response.ContentLength64 = b.Length;
            ctx.Response.OutputStream.Write(b, 0, b.Length);
            ctx.Response.OutputStream.Close();
            Console.WriteLine("replied " + b.Length + " bytes");
        }
    }
}
