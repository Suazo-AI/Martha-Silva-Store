namespace Savia.Domain;

/// <summary>One program, two modes (ADR-001 D3). A branch node sells offline; the cloud node serves web and sync.</summary>
public enum NodeKind { Cloud, Branch }
