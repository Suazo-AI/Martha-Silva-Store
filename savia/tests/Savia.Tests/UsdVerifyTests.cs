using System.Diagnostics;

namespace Savia.Tests;

public sealed class UsdVerifyTests
{
    [Fact]
    public async Task Spec17_quick_verification_preserves_pilot()
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo("python", "tools/verify.py --quick")
            {
                WorkingDirectory = TestSql.SaviaRoot,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false
            }
        };
        process.Start();
        var output = process.StandardOutput.ReadToEndAsync();
        var errors = process.StandardError.ReadToEndAsync();
        using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(3));
        await process.WaitForExitAsync(timeout.Token);
        Assert.True(process.ExitCode == 0, await output + await errors);
    }
}
