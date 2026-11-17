using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media.Imaging;
using Forms = System.Windows.Forms;

namespace Promecapt;

internal sealed class App : Application
{
    private HwndSource? hotkeySource;
    private Forms.NotifyIcon? tray;
    private Icon? appIcon;
    private CaptureWindow? capture;
    private bool hotkeyRegistered;

    [STAThread]
    public static void Main()
    {
        using var instance = new Mutex(true, @"Local\Promecapt.Windows", out bool firstInstance);
        if (!firstInstance)
            return;

        new App { ShutdownMode = ShutdownMode.OnExplicitShutdown }.Run();
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        hotkeySource = new HwndSource(new HwndSourceParameters("Promecapt Hotkey")
        {
            ParentWindow = new IntPtr(-3) // HWND_MESSAGE
        });
        hotkeySource.AddHook(HandleMessage);
        // Ctrl + Alt + 1, with key repeat disabled.
        hotkeyRegistered = Native.RegisterHotKey(hotkeySource.Handle, 1, 0x4003, 0x31);
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(hotkeyRegistered ? "Capture region (Ctrl+Alt+1)" : "Capture region", null,
            (_, _) => Dispatcher.BeginInvoke((Action)StartCapture));
        menu.Items.Add("Quit", null, (_, _) => Dispatcher.Invoke(() => Shutdown()));
        if (Environment.ProcessPath is string executablePath)
            appIcon = Icon.ExtractAssociatedIcon(executablePath);
        tray = new Forms.NotifyIcon
        {
            Icon = appIcon ?? SystemIcons.Application,
            Text = "Promecapt",
            ContextMenuStrip = menu,
            Visible = true
        };
        tray.MouseDoubleClick += (_, args) =>
        {
            if (args.Button == Forms.MouseButtons.Left)
                Dispatcher.BeginInvoke((Action)StartCapture);
        };
        if (!hotkeyRegistered)
            tray.ShowBalloonTip(4000, "Promecapt", "Ctrl+Alt+1 is unavailable. Use the tray menu to capture.", Forms.ToolTipIcon.Info);
    }

    private IntPtr HandleMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == 0x0312 && wParam.ToInt32() == 1)
        {
            handled = true;
            Dispatcher.BeginInvoke((Action)StartCapture);
        }
        return IntPtr.Zero;
    }

    private void StartCapture()
    {
        if (capture is not null)
            return;

        try
        {
            Rectangle bounds = Forms.Screen.FromPoint(Forms.Cursor.Position).Bounds;
            using var bitmap = new Bitmap(bounds.Width, bounds.Height, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
            using (var graphics = Graphics.FromImage(bitmap))
                graphics.CopyFromScreen(bounds.Location, System.Drawing.Point.Empty, bounds.Size);

            IntPtr bitmapHandle = bitmap.GetHbitmap();
            BitmapSource screenshot;
            try
            {
                screenshot = Imaging.CreateBitmapSourceFromHBitmap(
                    bitmapHandle, IntPtr.Zero, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                screenshot.Freeze();
            }
            finally
            {
                Native.DeleteObject(bitmapHandle);
            }

            capture = new CaptureWindow(screenshot, bounds, selection =>
                new EditorWindow(selection).Show());
            capture.Closed += (_, _) => capture = null;
            capture.Show();
        }
        catch (Exception error)
        {
            capture?.Close();
            MessageBox.Show(error.Message, "Promecapt — Capture failed", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (tray is not null)
        {
            tray.Visible = false;
            tray.ContextMenuStrip?.Dispose();
            tray.Dispose();
        }
        appIcon?.Dispose();
        if (hotkeySource is not null)
        {
            if (hotkeyRegistered)
                Native.UnregisterHotKey(hotkeySource.Handle, 1);
            hotkeySource.Dispose();
        }
        base.OnExit(e);
    }
}

internal static class Native
{
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UnregisterHotKey(IntPtr window, int id);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DeleteObject(IntPtr handle);
}
