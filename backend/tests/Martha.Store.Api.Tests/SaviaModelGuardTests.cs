using Martha.Store.Api;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class SaviaModelGuardTests
{
    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task Attempts_and_movements_refuse_rewrites_and_deletes_before_opening_SQL(bool movement, bool delete)
    {
        // No endpoint/configuration is read and no connection is opened: the change-tracker guard runs first.
        await using var db = new StoreDbContext(new DbContextOptionsBuilder<StoreDbContext>()
            .UseSqlServer("Server=127.0.0.1,1;Database=MarthaSynthetic_Guard;Integrated Security=true;Connect Timeout=1").Options);
        object entity = movement ? new SaviaMovement { Id = Guid.NewGuid() } : new SaviaAttempt { AttemptId = Guid.NewGuid() };
        db.Attach(entity);
        db.Entry(entity).State = delete ? EntityState.Deleted : EntityState.Modified;
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges());
        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
    }
}
