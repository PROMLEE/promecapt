using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using ScreenBounds = System.Drawing.Rectangle;

namespace Promecapt;

internal sealed class CaptureWindow : Window
{
    private readonly BitmapSource screenshot;
    private readonly Action<BitmapSource> onSelection;
    private readonly Grid surface;
    private readonly SelectionShade shade = new();
    private Point? anchor;

    internal CaptureWindow(BitmapSource screenshot, ScreenBounds bounds, Action<BitmapSource> onSelection)
    {
        this.screenshot = screenshot;
        this.onSelection = onSelection;
        Title = "Promecapt — Select region";
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        Width = bounds.Width;
        Height = bounds.Height;
        Cursor = Cursors.Cross;

        surface = new Grid { Background = Brushes.Black };
        surface.Children.Add(new Image { Source = screenshot, Stretch = Stretch.Fill });
        surface.Children.Add(shade);
        Content = surface;

        SourceInitialized += (_, _) =>
        {
            // Use physical coordinates for monitors with different scaling or negative origins.
            if (!Native.SetWindowPos(new WindowInteropHelper(this).Handle, IntPtr.Zero,
                    bounds.X, bounds.Y, bounds.Width, bounds.Height, 0x0014))
                throw new Win32Exception();
        };
        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Escape)
                Close();
        };
        surface.MouseLeftButtonDown += (_, e) =>
        {
            if (surface.CaptureMouse())
            {
                anchor = e.GetPosition(surface);
                shade.Selection = Rect.Empty;
                shade.InvalidateVisual();
            }
        };
        surface.MouseMove += (_, e) =>
        {
            if (anchor is Point start)
            {
                shade.Selection = new Rect(start, Clamp(e.GetPosition(surface)));
                shade.InvalidateVisual();
            }
        };
        surface.LostMouseCapture += (_, _) =>
        {
            anchor = null;
            shade.Selection = Rect.Empty;
            shade.InvalidateVisual();
        };
        surface.MouseLeftButtonUp += (_, e) =>
        {
            if (anchor is not Point start)
                return;
            var region = new Rect(start, Clamp(e.GetPosition(surface)));
            surface.ReleaseMouseCapture();
            if (region.Width < 1 || region.Height < 1)
                return;

            double scaleX = screenshot.PixelWidth / surface.ActualWidth;
            double scaleY = screenshot.PixelHeight / surface.ActualHeight;
            int left = (int)Math.Floor(region.Left * scaleX);
            int top = (int)Math.Floor(region.Top * scaleY);
            int right = Math.Min(screenshot.PixelWidth, (int)Math.Ceiling(region.Right * scaleX));
            int bottom = Math.Min(screenshot.PixelHeight, (int)Math.Ceiling(region.Bottom * scaleY));
            var cropped = new CroppedBitmap(screenshot, new Int32Rect(left, top, right - left, bottom - top));
            cropped.Freeze();
            Close();
            onSelection(cropped);
        };
    }

    private Point Clamp(Point point) => new(
        Math.Clamp(point.X, 0, surface.ActualWidth),
        Math.Clamp(point.Y, 0, surface.ActualHeight));

    private sealed class SelectionShade : FrameworkElement
    {
        private static readonly Brush Dim = new SolidColorBrush(Color.FromArgb(115, 0, 0, 0));
        private static readonly Pen Outline = new(Brushes.Aquamarine, 1);

        internal Rect Selection { get; set; } = Rect.Empty;

        protected override void OnRender(DrawingContext context)
        {
            var bounds = new RectangleGeometry(new Rect(RenderSize));
            if (Selection.IsEmpty)
            {
                context.DrawGeometry(Dim, null, bounds);
                return;
            }
            context.DrawGeometry(Dim, null,
                new CombinedGeometry(GeometryCombineMode.Exclude, bounds, new RectangleGeometry(Selection)));
            context.DrawRectangle(null, Outline, Selection);
        }
    }
}
