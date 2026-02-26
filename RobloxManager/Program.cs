using System;
using System.Windows.Forms;
using System.Threading;

namespace RobloxManager
{
    internal static class Program
    {
        private static Mutex? _mutex;

        [STAThread]
        static void Main()
        {
            // Single instance check for the manager itself
            bool createdNew;
            _mutex = new Mutex(true, "RobloxManager_SingleInstance", out createdNew);

            if (!createdNew)
            {
                MessageBox.Show("Roblox Manager is already running!", "Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            ApplicationConfiguration.Initialize();
            Application.Run(new MainForm());

            _mutex.ReleaseMutex();
        }
    }
}
