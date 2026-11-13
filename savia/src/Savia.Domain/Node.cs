namespace Savia.Domain;

/// <summary>One program, two modes (ADR-001 D3). A branch node sells offline; the cloud node serves web and sync.</summary>
public enum NodeKind { Cloud, Branch }

public static class Roles
{
    public const string Owner = "OWNER";
    public const string Seller = "SELLER";
    public const string Manager = "MANAGER";
    public const string Cashier = "CASHIER";
    public const string Inventory = "INVENTORY";
    public const string Accountant = "ACCOUNTANT";
}
