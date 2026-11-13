using System.Text.Json;

namespace Savia.Application;

/// <summary>The CSV export of a report that travels as SQL JSON: one row per leaf, no figure recalculated.</summary>
public static class ReportCsv
{
    // Serialize every leaf of the same SQL response. No totals are recalculated in the export.
    public static byte[] From(JsonElement report)
    {
        var rows = new List<string> { "campo,valor" };
        static string Cell(string value) => "\"" + value.Replace("\"", "\"\"") + "\"";
        void Walk(JsonElement value, string path)
        {
            if (value.ValueKind == JsonValueKind.Object)
                foreach (var property in value.EnumerateObject()) Walk(property.Value, path.Length == 0 ? property.Name : path + "." + property.Name);
            else if (value.ValueKind == JsonValueKind.Array)
            {
                var index = 0;
                foreach (var entry in value.EnumerateArray()) Walk(entry, path + "[" + index++ + "]");
            }
            else rows.Add(Cell(path) + "," + Cell(value.ToString()));
        }
        Walk(report, "");
        return System.Text.Encoding.UTF8.GetBytes("\uFEFF" + string.Join("\r\n", rows) + "\r\n");
    }
}
