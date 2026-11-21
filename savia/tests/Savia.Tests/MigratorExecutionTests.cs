using System.Data;
using System.Data.Common;
using System.Diagnostics.CodeAnalysis;
using Microsoft.Data.SqlClient;

namespace Savia.Tests;

public sealed class MigratorExecutionTests
{
    [Fact]
    public async Task Marked_success_encloses_batches_and_parameterized_ledger_in_one_transaction()
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection();
        await MigrationExecution.ApplyAsync(db, file.Migration);
        Assert.Equal(new[] { "options", "abort-on", "begin", "batch1", "batch2", "validate", "ledger", "validate", "commit", "dispose", "abort-off" }, db.Trace);
        Assert.Equal(new[] { "batch1", "batch2", "ledger" }, db.Persisted);
        Assert.All(db.WorkTransactions, t => Assert.Same(db.Transaction, t));
        Assert.Equal(new[] { file.Migration.Version, file.Migration.FileName, file.Migration.Sha256 }, db.LedgerValues);
        Assert.Equal(new[] { 1800, 1800, 30 }, db.WorkTimeouts);
    }

    [Theory]
    [InlineData("batch1")]
    [InlineData("batch2")]
    [InlineData("ledger")]
    [InlineData("commit")]
    public async Task Failure_rolls_back_all_pending_effects_and_preserves_original(string point)
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { FailAt = point };
        Assert.Same(db.Original, await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration)));
        Assert.Empty(db.Persisted);
        Assert.Contains("rollback", db.Trace);
        Assert.Equal("abort-off", db.Trace.Last());
    }

    [Theory]
    [InlineData(0, 0)]
    [InlineData(1, -1)]
    [InlineData(2, 1)]
    [InlineData(1, 0)]
    public async Task Invalid_state_blocks_registration_and_commit(int count, int state)
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { TransactionCount = count, TransactionState = state };
        await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration));
        Assert.DoesNotContain("ledger", db.Trace);
        Assert.DoesNotContain("commit", db.Trace);
        Assert.Contains("rollback", db.Trace);
        Assert.Empty(db.Persisted);
    }

    [Fact]
    public async Task Invalid_state_after_registration_blocks_commit()
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { InvalidateAfterLedger = true };
        await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration));
        Assert.Contains("ledger", db.Trace);
        Assert.DoesNotContain("commit", db.Trace);
        Assert.Contains("rollback", db.Trace);
        Assert.Empty(db.Persisted);
    }

    [Theory]
    [InlineData("rollback")]
    [InlineData("dispose")]
    [InlineData("restore")]
    public async Task Cleanup_failure_does_not_replace_original(string point)
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { FailAt = "batch2", CleanupFailure = point };
        Assert.Same(db.Original, await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration)));
        Assert.DoesNotContain("commit", db.Trace);
    }

    [Theory]
    [InlineData("batch1")]
    [InlineData("ledger")]
    [InlineData("validate")]
    public async Task Command_disposal_failure_preserves_original_operation_error(string point)
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { FailAt = point, CommandDisposalFailureAt = point };
        Assert.Same(db.Original, await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration)));
        Assert.Contains(point, db.DisposedCommands);
        Assert.Contains("rollback", db.Trace);
        Assert.DoesNotContain("commit", db.Trace);
        Assert.Empty(db.Persisted);
    }

    [Theory]
    [InlineData("batch1")]
    [InlineData("ledger")]
    [InlineData("validate")]
    public async Task Command_disposal_failure_after_success_is_not_hidden(string point)
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { CommandDisposalFailureAt = point };
        Assert.Same(db.CommandDisposalError, await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration)));
        Assert.Contains(point, db.DisposedCommands);
        Assert.Contains("rollback", db.Trace);
        Assert.DoesNotContain("commit", db.Trace);
        Assert.Empty(db.Persisted);
    }

    [Fact]
    public async Task Unknown_commit_outcome_is_never_reported_success()
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { FailAt = "commit", CleanupFailure = "rollback" };
        Assert.Same(db.Original, await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(db, file.Migration)));
        Assert.Contains("rollback", db.Trace);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Restores_prior_xact_abort_setting(bool enabled)
    {
        using var file = new Script("-- savia:transactional\nfirst\nGO\nsecond\n");
        var db = new RecordingConnection { XactAbort = enabled };
        await MigrationExecution.ApplyAsync(db, file.Migration);
        Assert.Equal(enabled ? "abort-on" : "abort-off", db.Trace.Last());
    }

    [Fact]
    public async Task Unmarked_preserves_independent_commands_and_partial_failure_semantics()
    {
        using var file = new Script("first\nGO\nsecond\n");
        var db = new RecordingConnection();
        await MigrationExecution.ApplyAsync(db, file.Migration);
        Assert.Equal(new[] { "batch1", "batch2", "ledger" }, db.Trace);
        Assert.All(db.WorkTransactions, Assert.Null);
        var failed = new RecordingConnection { FailAt = "batch2" };
        await Assert.ThrowsAsync<InvalidOperationException>(() => MigrationExecution.ApplyAsync(failed, file.Migration));
        Assert.Equal(new[] { "batch1" }, failed.Persisted);
        Assert.DoesNotContain("rollback", failed.Trace);
    }

    [Theory]
    [InlineData("-- savia:transactional\n", true)]
    [InlineData("-- savia:transactional\r\n", true)]
    [InlineData("\uFEFF-- savia:transactional\n", false)]
    [InlineData("-- savia:transactional-extra\n", true)]
    [InlineData(" -- savia:transactional\n", false)]
    [InlineData("\n-- savia:transactional\n", false)]
    [InlineData("-- SAVIA:transactional\n", false)]
    public void Marker_matches_python_leading_startswith_rule(string prefix, bool marked)
    {
        using var file = new Script(prefix + "first\r\nGO\r\nsecond\r\n");
        Assert.Equal(marked, file.Migration.Transactional);
        Assert.Equal(new[] { prefix.Replace("\r\n", "\n") + "first\n", "second\n" }, file.Migration.Batches());
    }

    private sealed class Script : IDisposable
    {
        private readonly string path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "V028__" + Guid.NewGuid().ToString("N") + ".sql");
        public Migration Migration { get; }
        public Script(string sql) { File.WriteAllText(path, sql); Migration = new Migration(path); }
        public void Dispose() => File.Delete(path);
    }

    // Records actual DbCommand.Transaction assignments and models pending versus committed effects.
    // This is an offline oracle, not SQL Server transaction or DDL proof.
    private sealed class RecordingConnection : DbConnection
    {
        public List<string> Trace { get; } = [];
        public List<string> Persisted { get; } = [];
        public List<string> Pending { get; } = [];
        public List<DbTransaction?> WorkTransactions { get; } = [];
        public List<int> WorkTimeouts { get; } = [];
        public string[] LedgerValues { get; private set; } = [];
        public string? FailAt { get; init; }
        public string? CleanupFailure { get; init; }
        public string? CommandDisposalFailureAt { get; init; }
        public List<string> DisposedCommands { get; } = [];
        public InvalidOperationException CommandDisposalError { get; } = new("command disposal failure");
        public int TransactionCount { get; init; } = 1;
        public int TransactionState { get; init; } = 1;
        public bool InvalidateAfterLedger { get; init; }
        public bool XactAbort { get; init; }
        public InvalidOperationException Original { get; } = new("original injected failure");
        public RecordingTransaction? Transaction { get; private set; }
        private int batch;
        [AllowNull] public override string ConnectionString { get; set; } = "";
        public override string Database => "offline";
        public override string DataSource => "offline";
        public override string ServerVersion => "offline";
        public override ConnectionState State => ConnectionState.Open;
        public override void ChangeDatabase(string databaseName) => throw new NotSupportedException();
        public override void Close() { }
        public override void Open() => throw new NotSupportedException("No runtime connections allowed");
        protected override DbCommand CreateDbCommand() => new RecordingCommand(this);
        protected override DbTransaction BeginDbTransaction(IsolationLevel isolationLevel)
        {
            Trace.Add("begin");
            return Transaction = new RecordingTransaction(this);
        }
        public object Run(RecordingCommand command)
        {
            var sql = command.CommandText;
            if (sql == "SELECT @@OPTIONS & 16384;") { Trace.Add("options"); return XactAbort ? 16384 : 0; }
            if (sql.StartsWith("SET XACT_ABORT"))
            {
                var restore = Trace.Contains("dispose");
                Trace.Add(sql.Contains(" ON;") ? "abort-on" : "abort-off");
                if (restore && CleanupFailure == "restore") throw new Exception("restore failed");
                return 0;
            }
            if (sql.StartsWith("SELECT CASE"))
            {
                command.Step = "validate";
                Trace.Add("validate");
                Assert.Contains("@@TRANCOUNT = 1 AND XACT_STATE() = 1", sql);
                Assert.Same(Transaction, command.AssignedTransaction);
                if (FailAt == "validate") throw Original;
                return TransactionCount == 1 && TransactionState == 1 && !(InvalidateAfterLedger && Trace.Contains("ledger")) ? 1 : 0;
            }
            var step = sql.StartsWith("INSERT INTO dbo.SaviaMigrations") ? "ledger" : "batch" + ++batch;
            command.Step = step;
            Trace.Add(step);
            WorkTransactions.Add(command.AssignedTransaction);
            WorkTimeouts.Add(command.CommandTimeout);
            if (step == "ledger") LedgerValues = command.Parameters.Cast<DbParameter>().Select(p => (string)p.Value!).ToArray();
            if (FailAt == step) throw Original;
            (command.AssignedTransaction is null ? Persisted : Pending).Add(step);
            return 1;
        }
        public sealed class RecordingTransaction(RecordingConnection db) : DbTransaction
        {
            public override IsolationLevel IsolationLevel => IsolationLevel.ReadCommitted;
            protected override DbConnection DbConnection => db;
            public override void Commit()
            {
                db.Trace.Add("commit");
                if (db.FailAt == "commit") throw db.Original;
                db.Persisted.AddRange(db.Pending); db.Pending.Clear();
            }
            public override void Rollback()
            {
                db.Trace.Add("rollback");
                if (db.CleanupFailure == "rollback") throw new Exception("rollback failed");
                db.Pending.Clear();
            }
            protected override void Dispose(bool disposing)
            {
                db.Trace.Add("dispose");
                if (db.CleanupFailure == "dispose") throw new Exception("dispose failed");
            }
        }
        public sealed class RecordingCommand(RecordingConnection db) : DbCommand
        {
            private readonly SqlCommand parameters = new();
            public string? Step { get; set; }
            public DbTransaction? AssignedTransaction => DbTransaction;
            [AllowNull] public override string CommandText { get; set; } = "";
            public override int CommandTimeout { get; set; }
            public override CommandType CommandType { get; set; }
            public override bool DesignTimeVisible { get; set; }
            public override UpdateRowSource UpdatedRowSource { get; set; }
            protected override DbConnection? DbConnection { get; set; } = db;
            protected override DbTransaction? DbTransaction { get; set; }
            protected override DbParameterCollection DbParameterCollection => parameters.Parameters;
            public override void Cancel() => throw new NotSupportedException();
            public override int ExecuteNonQuery() => (int)db.Run(this);
            public override object ExecuteScalar() => db.Run(this);
            public override void Prepare() => throw new NotSupportedException();
            protected override DbParameter CreateDbParameter() => new SqlParameter();
            protected override DbDataReader ExecuteDbDataReader(CommandBehavior behavior) => throw new NotSupportedException();
            public override ValueTask DisposeAsync()
            {
                parameters.Dispose();
                if (Step is not null) db.DisposedCommands.Add(Step);
                if (Step is not null && db.CommandDisposalFailureAt == Step) throw db.CommandDisposalError;
                return ValueTask.CompletedTask;
            }
        }
    }
}
