using System.Text.Json;
using System.Text.Json.Serialization;

namespace Martha.Store.Api.Internal;

// Default means omitted, not null. Only a JSON null/GUID can specify an update;
// clients cannot supply a trusted presence flag or an authorization decision.
[JsonConverter(typeof(InternalBranchIdUpdateConverter))]
public readonly record struct InternalBranchIdUpdate
{
    public bool IsSpecified { get; }
    public Guid? Value { get; }
    private InternalBranchIdUpdate(Guid? value) { IsSpecified = true; Value = value; }
    public static InternalBranchIdUpdate Specified(Guid? value) => new(value);
}

public sealed class InternalBranchIdUpdateConverter : JsonConverter<InternalBranchIdUpdate>
{
    public override bool HandleNull => true;

    public override InternalBranchIdUpdate Read(ref Utf8JsonReader reader,
        Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Null)
            return InternalBranchIdUpdate.Specified(null);
        if (reader.TokenType == JsonTokenType.String && reader.TryGetGuid(out var id)
            && id != Guid.Empty) return InternalBranchIdUpdate.Specified(id);
        throw new JsonException("branchId must be null or a nonempty GUID.");
    }

    public override void Write(Utf8JsonWriter writer, InternalBranchIdUpdate value,
        JsonSerializerOptions options)
    {
        if (!value.IsSpecified)
            throw new JsonException("An absent branchId must be omitted.");
        if (value.Value is { } id) writer.WriteStringValue(id);
        else writer.WriteNullValue();
    }
}
