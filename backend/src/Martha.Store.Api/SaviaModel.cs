using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Martha.Store.Api;

internal static class SaviaModel
{
    internal static void Configure(ModelBuilder model)
    {
        model.Entity<SaviaBalance>(b =>
        {
            b.HasKey(x => new { x.VariantId, x.LocationId });
            Authority(b);
            b.Property(x => x.Sku).HasMaxLength(80); b.HasIndex(x => x.Sku).IsUnique();
            b.Property(x => x.Name).HasMaxLength(200);
            b.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            b.ToTable("SaviaBalances", t =>
            {
                t.HasCheckConstraint("CK_SaviaBalances_Stock", "[OnHand] >= [Reserved] AND [Reserved] >= 0");
                t.HasCheckConstraint("CK_SaviaBalances_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [Currency] = 'XXX'");
                t.HasCheckConstraint("CK_SaviaBalances_Authority", AuthoritySql);
            });
        });
        model.Entity<SaviaReservation>(r =>
        {
            r.HasKey(x => x.Id);
            r.HasOne<SaviaBalance>().WithMany().HasForeignKey(x => new { x.VariantId, x.LocationId }).OnDelete(DeleteBehavior.Restrict);
            r.HasOne<SaviaAttempt>().WithMany().HasForeignKey(x => x.CreateAttemptId).OnDelete(DeleteBehavior.Restrict);
            r.HasIndex(x => x.CreateAttemptId).IsUnique();
            r.Property(x => x.State).HasMaxLength(16).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            r.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            r.ToTable("SaviaReservations", t =>
            {
                t.UseSqlOutputClause(false);
                t.HasTrigger("TR_SaviaReservations_ImmutableCreation");
                t.HasCheckConstraint("CK_SaviaReservations_Quantity", "[Quantity] >= 1 AND [Quantity] <= 100");
                t.HasCheckConstraint("CK_SaviaReservations_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] = [UnitPriceMinor] * [Quantity] AND [Currency] = 'XXX'");
                t.HasCheckConstraint("CK_SaviaReservations_State", "([State] = 'active' AND [CancelledAt] IS NULL) OR ([State] = 'cancelled' AND [CancelledAt] IS NOT NULL)");
                t.HasCheckConstraint("CK_SaviaReservations_Receipt", "ISJSON([CreationJson]) = 1");
            });
        });
        model.Entity<SaviaAttempt>(a =>
        {
            a.HasKey(x => x.AttemptId); Authority(a);
            a.Property(x => x.IdempotencyKey).HasMaxLength(128).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            a.Property(x => x.Operation).HasMaxLength(16).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            a.Property(x => x.CanonicalPayload).HasMaxLength(2000).UseCollation("Latin1_General_100_BIN2");
            a.Property(x => x.Outcome).HasMaxLength(16).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            a.Property(x => x.Error).HasMaxLength(64).IsUnicode(false);
            a.HasIndex(x => new { x.Operation, x.IdempotencyKey }).IsUnique();
            a.ToTable("SaviaAttempts", t =>
            {
                t.UseSqlOutputClause(false);
                t.HasTrigger("TR_SaviaAttempts_AppendOnly");
                t.HasCheckConstraint("CK_SaviaAttempts_Authority", AuthoritySql);
                t.HasCheckConstraint("CK_SaviaAttempts_Operation", "[Operation] IN ('reserve','cancel')");
                t.HasCheckConstraint("CK_SaviaAttempts_Result", "([Outcome] = 'succeeded' AND [ResultJson] IS NOT NULL AND ISJSON([ResultJson]) = 1 AND [Error] IS NULL) OR ([Outcome] = 'rejected' AND [ResultJson] IS NULL AND [Error] IS NOT NULL)");
            });
        });
        model.Entity<SaviaMovement>(m =>
        {
            m.HasKey(x => x.Id); Authority(m);
            m.HasOne<SaviaReservation>().WithMany().HasForeignKey(x => x.ReservationId).OnDelete(DeleteBehavior.Restrict);
            m.HasOne<SaviaAttempt>().WithMany().HasForeignKey(x => x.AttemptId).OnDelete(DeleteBehavior.Restrict);
            m.HasOne<SaviaBalance>().WithMany().HasForeignKey(x => new { x.VariantId, x.LocationId }).OnDelete(DeleteBehavior.Restrict);
            m.HasIndex(x => x.AttemptId).IsUnique();
            m.Property(x => x.Kind).HasMaxLength(16).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            m.ToTable("SaviaMovements", t =>
            {
                t.UseSqlOutputClause(false);
                t.HasTrigger("TR_SaviaMovements_AppendOnly");
                t.HasCheckConstraint("CK_SaviaMovements_Authority", AuthoritySql);
                t.HasCheckConstraint("CK_SaviaMovements_Delta", "[OnHandDelta] = 0 AND (([Kind] = 'reserve' AND [ReservedDelta] BETWEEN 1 AND 100) OR ([Kind] = 'cancel' AND [ReservedDelta] BETWEEN -100 AND -1))");
            });
        });
    }
    private const string AuthoritySql = "[Mode] = 'savia' AND [InstanceId] = 'savia-synthetic-v2' AND [Epoch] = 1";
    private static void Authority<TEntity>(EntityTypeBuilder<TEntity> entity) where TEntity : class
    {
        entity.Property<string>("Mode").HasMaxLength(16).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
        entity.Property<string>("InstanceId").HasMaxLength(80).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
    }
}
