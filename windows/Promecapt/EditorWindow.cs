using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Promecapt;

internal sealed class EditorWindow : Window
{
    private readonly Grid artwork;
    private readonly InkCanvas ink;
    private readonly BitmapSource image;

    internal EditorWindow(BitmapSource image)
    {
        this.image = image;
        Title = $"Promecapt — {image.PixelWidth} × {image.PixelHeight}";
        var workArea = SystemParameters.WorkArea;
        Width = Math.Min(Math.Max(440, image.PixelWidth + 24), workArea.Width * 0.9);
        Height = Math.Min(Math.Max(180, image.PixelHeight + 100), workArea.Height * 0.9);
        WindowStartupLocation = WindowStartupLocation.CenterScreen;

        artwork = new Grid { Width = image.PixelWidth, Height = image.PixelHeight, ClipToBounds = true };
        artwork.Children.Add(new Image { Source = image, Stretch = Stretch.Fill });
        ink = new InkCanvas { Background = Brushes.Transparent, EditingMode = InkCanvasEditingMode.Ink };
        SetPen(Colors.OrangeRed, false);
        artwork.Children.Add(ink);

        var toolbar = new WrapPanel { Margin = new Thickness(8) };
        AddButton("Red pen", () => SetPen(Colors.OrangeRed, false));
        AddButton("Blue pen", () => SetPen(Colors.DeepSkyBlue, false));
        AddButton("Highlight", () => SetPen(Colors.Gold, true));
        AddButton("Undo stroke", UndoStroke);
        AddButton("Copy (Ctrl+C)", CopyImage);
        AddButton("Pin (Ctrl+Enter)", PinImage);

        var layout = new DockPanel();
        DockPanel.SetDock(toolbar, Dock.Top);
        layout.Children.Add(toolbar);
        layout.Children.Add(new Viewbox { Child = artwork, StretchDirection = StretchDirection.DownOnly });
        Content = layout;

        PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Escape)
            {
                Close();
                e.Handled = true;
            }
            else if (Keyboard.Modifiers == ModifierKeys.Control)
            {
                switch (e.Key)
                {
                    case Key.C: CopyImage(); break;
                    case Key.Enter: PinImage(); break;
                    case Key.Z: UndoStroke(); break;
                    default: return;
                }
                e.Handled = true;
            }
        };

        void AddButton(string label, Action action)
        {
            var button = new Button
            {
                Content = label,
                Margin = new Thickness(0, 0, 6, 4),
                Padding = new Thickness(8, 4, 8, 4)
            };
            button.Click += (_, _) => action();
            toolbar.Children.Add(button);
        }
    }

    private void SetPen(Color color, bool highlight)
    {
        double width = highlight ? 16 : 3;
        ink.DefaultDrawingAttributes = new DrawingAttributes
        {
            Color = color,
            IsHighlighter = highlight,
            Width = width,
            Height = width,
            IgnorePressure = true
        };
    }

    private void UndoStroke()
    {
        if (ink.Strokes.Count > 0)
            ink.Strokes.RemoveAt(ink.Strokes.Count - 1);
    }

    private BitmapSource RenderImage()
    {
        if (ink.Strokes.Count == 0)
            return image;

        artwork.UpdateLayout();
        var rendered = new RenderTargetBitmap(image.PixelWidth, image.PixelHeight, 96, 96, PixelFormats.Pbgra32);
        rendered.Render(artwork);
        rendered.Freeze();
        return rendered;
    }

    private void CopyImage()
    {
        try
        {
            Clipboard.SetImage(RenderImage());
            Close();
        }
        catch (ExternalException)
        {
            MessageBox.Show(this, "The clipboard is busy. Try copying again.", "Promecapt");
        }
    }

    private void PinImage()
    {
        var workArea = SystemParameters.WorkArea;
        var pin = new Window
        {
            Title = "Promecapt — Pinned image",
            Topmost = true,
            ShowInTaskbar = false,
            Width = Math.Min(Math.Max(140, image.PixelWidth + 16), workArea.Width * 0.85),
            Height = Math.Min(Math.Max(90, image.PixelHeight + 40), workArea.Height * 0.85),
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            Background = Brushes.Black,
            Content = new Image { Source = RenderImage(), Stretch = Stretch.Uniform }
        };
        pin.PreviewKeyDown += (_, e) =>
        {
            if (e.Key == Key.Escape)
                pin.Close();
        };
        pin.Show();
        Close();
    }
}
