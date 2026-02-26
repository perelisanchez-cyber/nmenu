using System.Drawing;

namespace RobloxManager
{
    public static class Theme
    {
        // Main colors
        public static readonly Color Background = Color.FromArgb(18, 18, 24);
        public static readonly Color Surface = Color.FromArgb(28, 28, 36);
        public static readonly Color SurfaceLight = Color.FromArgb(38, 38, 48);
        public static readonly Color Border = Color.FromArgb(50, 50, 60);

        // Text colors
        public static readonly Color Text = Color.FromArgb(230, 230, 240);
        public static readonly Color TextMuted = Color.FromArgb(160, 160, 180);
        public static readonly Color TextDim = Color.FromArgb(100, 100, 120);

        // Accent colors
        public static readonly Color Accent = Color.FromArgb(138, 43, 226);  // Purple
        public static readonly Color AccentHover = Color.FromArgb(158, 63, 246);
        public static readonly Color Success = Color.FromArgb(80, 200, 120);
        public static readonly Color Warning = Color.FromArgb(255, 180, 60);
        public static readonly Color Error = Color.FromArgb(255, 80, 80);
        public static readonly Color Info = Color.FromArgb(100, 180, 255);

        // Status colors
        public static readonly Color Online = Color.FromArgb(80, 200, 120);
        public static readonly Color Offline = Color.FromArgb(100, 100, 120);
        public static readonly Color Launching = Color.FromArgb(255, 180, 60);

        // Fonts
        public static readonly Font Title = new Font("Segoe UI", 14, FontStyle.Bold);
        public static readonly Font Subtitle = new Font("Segoe UI", 11, FontStyle.Regular);
        public static readonly Font Body = new Font("Segoe UI", 10, FontStyle.Regular);
        public static readonly Font Small = new Font("Segoe UI", 9, FontStyle.Regular);
        public static readonly Font Mono = new Font("Consolas", 9, FontStyle.Regular);

        public static void ApplyTo(Control control)
        {
            control.BackColor = Background;
            control.ForeColor = Text;
            control.Font = Body;

            foreach (Control child in control.Controls)
            {
                ApplyTo(child);
            }
        }
    }
}
