using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalOwnerRecoveryConsoleTests
{
    private const string Marker = "SECRET_MARKER_987654321";
    private static OwnerRecoveryManifest Manifest() => new("fixture", "SaviaInternalTest_fixture", 7,
        Guid.NewGuid(), "S-1-5-21-1", "01", Guid.NewGuid(), "OWNER", Guid.NewGuid());
    [Theory]
    [InlineData("--internal-recover-owner", true)]
    [InlineData("--INTERNAL-RECOVER-OWNER", true)]
    [InlineData("--internal-recover-owner=secret", true)]
    [InlineData(" --internal-recover-owner", true)]
    [InlineData("---internal-recover-owner", true)]
    [InlineData("--internal-bootstrap-owner", false)]
    [InlineData("--migrate", false)]
    public void Dispatch_captures_attempts(string argument, bool expected) => Assert.Equal(expected,
        InternalOwnerRecoveryConsole.IsInvocation([argument]));
    [Theory]
    [InlineData("--INTERNAL-RECOVER-OWNER")]
    [InlineData("--internal-recover-owner=secret")]
    [InlineData(" --internal-recover-owner")]
    [InlineData("---internal-recover-owner")]
    public async Task Invalid_dispatch_never_opens(string argument)
    {
        var calls = 0;
        var code = await InternalOwnerRecoveryConsole.Run([argument], new Terminal(""), _ => { calls++; throw new Exception(Marker); });
        Assert.Equal(2, code); Assert.Equal(0, calls);
    }
    [Fact]
    public async Task Mixed_and_redirected_refuse_before_access()
    {
        foreach (var args in new[] { new[] { InternalOwnerRecoveryConsole.Argument, "--migrate" }, new[] { InternalOwnerRecoveryConsole.Argument } })
        {
            var c = new Terminal("") { Redirected = args.Length == 1 };
            Assert.Equal(2, await InternalOwnerRecoveryConsole.Run(args, c, _ => throw new Exception(Marker)));
            Assert.DoesNotContain(Marker, c.Output);
        }
    }
    [Theory]
    [InlineData(14, false)] [InlineData(15, true)] [InlineData(128, true)] [InlineData(129, false)]
    public async Task Bounded_actual_reader_and_console(int length, bool accepted)
    { await Check(new string('x', length), new string('x', length), accepted); }
    [Fact]
    public async Task Controls_whitespace_mismatch_escape_overflow_are_rejected()
    {
        await Check(new string(' ', 15), new string(' ', 15), false);
        await Check(Marker + "\t", Marker, false);
        await Check(Marker + "\u0003", Marker, false);
        await Check(Marker, Marker + "x", false);
        await Check(Marker + "\u001b", Marker, false);
        await Check(new string('x', 129) + "\b", new string('x', 128), false);
        await Check(Marker + "z\b", Marker, true);
    }
    private static async Task Check(string password, string repeat, bool accepted)
    {
        var m = Manifest(); var calls = 0;
        var c = new Terminal("PRIVATE\n" + m.Confirmation + "\n" + password + "\n" + repeat + "\n");
        var result = await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument], c,
            _ => Task.FromResult(new RecoverySession(m, new Journal(), (_, _, privacy, _) =>
            { calls++; Assert.True(privacy()); return Task.FromResult(OwnerRecoveryOutcome.Committed); }, () => ValueTask.CompletedTask)));
        Assert.Equal(accepted ? 0 : 2, result); Assert.Equal(accepted ? 1 : 0, calls);
        Assert.DoesNotContain(Marker, c.Output);
    }
    [Fact]
    public void Rejected_line_is_drained_and_buffer_does_not_truncate()
    {
        var c = new Terminal(new string('x',129) + "\b\nOK\n");
        Assert.Null(InternalOwnerConsole.ReadValue(c,128,out var error,true)); Assert.NotNull(error);
        Assert.Equal("OK",InternalOwnerConsole.ReadValue(c,128,out _));
    }
    [Fact]
    public async Task Access_failure_and_uncertain_service_never_print_exception_or_success()
    {
        var m=Manifest();
        var c = new Terminal("PRIVATE\n"+m.Confirmation+"\n"+Marker+"\n"+Marker+"\n");
        var calls=0;
        Assert.Equal(4,await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument],c,
            _=>Task.FromResult(new RecoverySession(m,new Journal(),(_,_,_,_)=>{calls++;throw new IOException(Marker);},()=>ValueTask.CompletedTask))));
        Assert.Equal(1,calls); Assert.DoesNotContain(Marker,c.Output); Assert.DoesNotContain("committed",c.Output);
        c=new Terminal("");
        Assert.Equal(2,await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument],c,_=>throw new IOException(Marker)));
        Assert.DoesNotContain(Marker,c.Output);
    }
    [Fact]
    public void Actual_journal_allowlist_exclusive_writer_and_flush()
    {
        var path=Path.GetTempFileName();
        try
        {
            using(var journal=new RecoveryFileJournal(path,Manifest()))
            {
                Assert.Throws<InvalidOperationException>(()=>journal.Write(Marker,Guid.NewGuid(),Guid.NewGuid()));
                journal.Write("INTENT",Guid.NewGuid(),Guid.NewGuid());
                Assert.Throws<IOException>(()=>new RecoveryFileJournal(path,Manifest()));
                journal.Write("COMMITTED",Guid.NewGuid(),Guid.NewGuid());
            }
            var output=File.ReadAllText(path); Assert.DoesNotContain(Marker,output);
            Assert.Equal(2,File.ReadAllLines(path).Length);
        }
        finally { File.Delete(path); }
    }
    [Theory]
    [InlineData("")] [InlineData("garbage")] [InlineData("AA==")] [InlineData("AQAAAAAAAAAAAAAAAA==")]
    public void Malformed_hash_is_refused(string value) => Assert.ThrowsAny<Exception>(()=>InternalOwnerRecoveryService.ValidateStoredHash(value));
    [Theory]
    [InlineData("--INTERNAL-RECOVER-OWNER")]
    [InlineData("--internal-recover-owner=bad")]
    [InlineData("--internal-recover-owner --migrate")]
    [InlineData("---internal-recover-owner")]
    public async Task F1_actual_process_refuses_before_host(string arguments)
    {
        var start=new System.Diagnostics.ProcessStartInfo("dotnet", typeof(InternalOwnerRecoveryConsole).Assembly.Location+" "+arguments)
        { RedirectStandardOutput=true,RedirectStandardError=true,UseShellExecute=false };
        using var process=System.Diagnostics.Process.Start(start)!;
        await process.WaitForExitAsync();
        Assert.Equal(2,process.ExitCode);
        Assert.DoesNotContain("Now listening",await process.StandardOutput.ReadToEndAsync());
        Assert.DoesNotContain("Now listening",await process.StandardError.ReadToEndAsync());
    }
    [Fact]
    public async Task F2_cancellation_never_opens_access()
    {
        using var ct=new CancellationTokenSource();ct.Cancel();var calls=0;
        Assert.Equal(2,await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument],new Terminal(""),
            _=>{calls++;throw new Exception(Marker);},ct.Token));
        Assert.Equal(0,calls);
    }
    [Fact]
    public async Task F10_disposed_actual_journal_failure_cannot_report_success()
    {
        var path=Path.GetTempFileName();
        try
        {
            var manifest=Manifest();var journal=new RecoveryFileJournal(path,manifest);journal.Dispose();
            var c=new Terminal("PRIVATE\n"+manifest.Confirmation+"\n"+Marker+"\n"+Marker+"\n");
            var calls=0;
            Assert.Equal(4,await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument],c,
                _=>Task.FromResult(new RecoverySession(manifest,journal,(_,audit,_,_)=>
                {calls++;audit.Write("COMMITTED",Guid.NewGuid(),Guid.NewGuid());return Task.FromResult(OwnerRecoveryOutcome.Committed);},()=>ValueTask.CompletedTask))));
            Assert.Equal(1,calls);Assert.DoesNotContain("committed",c.Output);Assert.DoesNotContain(Marker,c.Output);
            Assert.Empty(File.ReadAllText(path));
        }
        finally {File.Delete(path);}
    }
    [Fact]
    public async Task F10_known_commit_receipt_is_not_overridden_by_cleanup_failure()
    {
        var path=Path.GetTempFileName();
        try
        {
            var m=Manifest();var journal=new RecoveryFileJournal(path,m);
            var c=new Terminal("PRIVATE\n"+m.Confirmation+"\n"+Marker+"\n"+Marker+"\n");
            Assert.Equal(0,await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument],c,
                _=>Task.FromResult(new RecoverySession(m,journal,(_,audit,_,_)=>
                {audit.Write("COMMITTED",Guid.NewGuid(),Guid.NewGuid());return Task.FromResult(OwnerRecoveryOutcome.Committed);},()=>{journal.Dispose();throw new IOException(Marker);} ))));
            Assert.Contains("committed",c.Output);Assert.DoesNotContain("UNKNOWN",c.Output);Assert.DoesNotContain(Marker,c.Output);
            Assert.Contains("COMMITTED",File.ReadAllText(path));
        }
        finally {File.Delete(path);}
    }
    [Fact]
    public async Task F2_redirection_after_password_prompt_refuses_before_service()
    {
        var m=Manifest();var c=new Terminal("PRIVATE\n"+m.Confirmation+"\n"+Marker+"\n"+Marker+"\n")
            { RedirectAtPrompt=true };var calls=0;
        Assert.Equal(2,await InternalOwnerRecoveryConsole.Run([InternalOwnerRecoveryConsole.Argument],c,
            _=>Task.FromResult(new RecoverySession(m,new Journal(),(_,_,_,_)=>
            {calls++;return Task.FromResult(OwnerRecoveryOutcome.Committed);},()=>ValueTask.CompletedTask))));
        Assert.Equal(0,calls);Assert.DoesNotContain(Marker,c.Output);
    }
    [Fact]
    public void F2_actual_operator_and_sql_policy_seams_refuse_sid_and_missing_metadata()
    {
        var m=Manifest();InternalOwnerRecoveryConsole.ValidateOperatorSid(m.OperatorSid,m.OperatorSid);
        foreach(var sid in new string?[]{null,"", "S-1-5-21-2",m.OperatorSid+" "})
            Assert.Throws<InvalidOperationException>(()=>InternalOwnerRecoveryConsole.ValidateOperatorSid(m.OperatorSid,sid));
        object[] correct=[m.Server,m.Catalog,m.DatabaseId,m.DatabaseGuid,new byte[]{1}];
        InternalOwnerRecoveryService.ValidateSqlIdentity(m,correct);
        foreach(var changed in new object[]{"wrong",DBNull.Value,0,Guid.Empty,new byte[]{2}}.Select((v,i)=>(v,i)))
        {var values=(object[])correct.Clone();values[changed.i]=changed.v;
         Assert.Throws<InvalidOperationException>(()=>InternalOwnerRecoveryService.ValidateSqlIdentity(m,values));}
        Assert.Throws<InvalidOperationException>(()=>InternalOwnerRecoveryService.ValidateSqlIdentity(m,[]));
    }
    [Fact]
    public async Task F10_process_crash_after_actual_intent_flush_has_no_success_receipt()
    {
        const string key="SAVIA_RECOVERY_OFFLINE_CRASH_PATH";
        if(Environment.GetEnvironmentVariable(key) is { } childPath)
        {var journal=new RecoveryFileJournal(childPath,Manifest());journal.Write("INTENT",Guid.NewGuid(),Guid.NewGuid());Environment.Exit(23);}
        var path=Path.GetTempFileName();
        try
        {
            var start=new System.Diagnostics.ProcessStartInfo("dotnet") {RedirectStandardOutput=true,RedirectStandardError=true,UseShellExecute=false};
            foreach(var arg in new[]{"vstest",typeof(InternalOwnerRecoveryConsoleTests).Assembly.Location,"--TestCaseFilter:FullyQualifiedName~F10_process_crash_after_actual_intent_flush_has_no_success_receipt"})start.ArgumentList.Add(arg);
            start.Environment[key]=path;
            using var child=System.Diagnostics.Process.Start(start)!;
            var stdout=child.StandardOutput.ReadToEndAsync();var stderr=child.StandardError.ReadToEndAsync();
            await child.WaitForExitAsync();Assert.NotEqual(0,child.ExitCode);await Task.WhenAll(stdout,stderr);
            var bytes=File.ReadAllText(path);Assert.Contains("INTENT",bytes);Assert.DoesNotContain("COMMITTED",bytes);Assert.DoesNotContain(Marker,bytes);
            Assert.Single(File.ReadAllLines(path));
        }
        finally {File.Delete(path);}
    }
    [Theory]
    [InlineData(false,false,0)] [InlineData(true,false,4)] [InlineData(false,true,4)]
    public async Task F10_actual_completion_seam_orders_cleanup_and_receipt(bool cleanupFails,bool receiptFails,int expected)
    {
        var path=Path.GetTempFileName();
        try
        {
            var journal=new RecoveryFileJournal(path,Manifest());journal.Write("INTENT",Guid.NewGuid(),Guid.NewGuid());
            if(receiptFails)journal.Dispose();var cleanups=0;
            var result=await InternalOwnerRecoveryService.Complete(OwnerRecoveryOutcome.Committed,()=>
            {cleanups++;if(cleanupFails)throw new IOException(Marker);return ValueTask.CompletedTask;},journal,Guid.NewGuid(),Guid.NewGuid());
            journal.Dispose();Assert.Equal(expected,(int)result);Assert.Equal(1,cleanups);
            var bytes=File.ReadAllText(path);Assert.Equal(expected==0,bytes.Contains("COMMITTED",StringComparison.Ordinal));Assert.DoesNotContain(Marker,bytes);
        }
        finally {File.Delete(path);}
    }
    [Fact]
    public void F2_actual_connection_builder_retains_integrated_TLS_and_zero_retry()
    {
        var m=Manifest();var b=new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(m.Connection());
        Assert.True(b.IntegratedSecurity);Assert.False(b.TrustServerCertificate);Assert.False(b.MultipleActiveResultSets);
        Assert.Equal(Microsoft.Data.SqlClient.SqlConnectionEncryptOption.Mandatory,b.Encrypt);
        Assert.Equal(0,b.ConnectRetryCount);Assert.False(b.Pooling);
        Assert.ThrowsAny<Exception>(()=>(m with {Catalog="production"}).Connection());
        Assert.ThrowsAny<Exception>(()=>(m with {SecurityVersion=Guid.Empty}).Connection());
    }
    private sealed class Journal:IOwnerRecoveryJournal { public void Write(string result,Guid operation,Guid version){} }
    private sealed class Terminal(string input):IInternalOwnerConsole
    {
        private readonly Queue<char> keys=new(input); public string Output=""; public bool Redirected; public bool RedirectAtPrompt;
        public bool IsInputRedirected=>Redirected; public bool IsOutputRedirected=>false; public bool IsErrorRedirected=>false;
        public void WriteLine(string value) { Output+=value+"\n"; if(RedirectAtPrompt && value=="Repeat password:")Redirected=true; }
        public void WriteInputFeedback(string value)=>Output+=value;
        public ConsoleKeyInfo ReadKey(bool intercept)
        {
            var c=keys.Dequeue(); if(c=='\u0003')return new(c,ConsoleKey.C,false,false,true); return new(c,c switch {'\n'=>ConsoleKey.Enter,'\b'=>ConsoleKey.Backspace,'\u001b'=>ConsoleKey.Escape,_=>ConsoleKey.A},false,false,false);
        }
    }
}
