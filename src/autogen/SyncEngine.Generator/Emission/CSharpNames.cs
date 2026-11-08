using System.Text;

namespace SyncEngine.Generator.Emission;

internal static class CSharpNames
{
    private static readonly HashSet<string> Keywords = new(StringComparer.Ordinal)
    {
        "class", "struct", "record", "namespace", "using", "event", "delegate",
        "string", "int", "long", "bool", "object", "default", "base", "this",
        "params", "operator", "checked", "unchecked", "fixed", "lock",
    };

    public static string SanitizeIdentifier(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return "Entity";
        }

        var sb = new StringBuilder(name.Length);
        foreach (var ch in name)
        {
            sb.Append(char.IsLetterOrDigit(ch) || ch == '_' ? ch : '_');
        }

        var cleaned = sb.ToString();
        if (cleaned.Length == 0 || char.IsDigit(cleaned[0]))
        {
            cleaned = "E_" + cleaned;
        }

        if (Keywords.Contains(cleaned))
        {
            cleaned = "@" + cleaned;
        }

        return cleaned;
    }

    public static string TypeName(Type type)
    {
        if (type == typeof(string)) return "string";
        if (type == typeof(int)) return "int";
        if (type == typeof(long)) return "long";
        if (type == typeof(bool)) return "bool";
        if (type == typeof(decimal)) return "decimal";
        if (type == typeof(double)) return "double";
        if (type == typeof(float)) return "float";
        if (type == typeof(Guid)) return "Guid";
        if (type == typeof(DateTimeOffset)) return "DateTimeOffset";
        if (type == typeof(byte[])) return "byte[]";
        return type.Name;
    }

    public static string DefaultSuffix(Type type, bool nullable)
    {
        // Property already ends with `{ get; set; }` — only append an initializer when needed.
        if (type == typeof(string))
        {
            return nullable ? string.Empty : " = string.Empty;";
        }

        if (type == typeof(byte[]))
        {
            return nullable ? string.Empty : " = Array.Empty<byte>();";
        }

        return string.Empty;
    }

    public static string PropertyType(Type type, bool nullable)
    {
        var name = TypeName(type);
        if (!nullable || type == typeof(string) || type == typeof(byte[]))
        {
            // reference types: add ? when nullable
            if (nullable && (type == typeof(string) || type == typeof(byte[]) || !type.IsValueType))
            {
                return name + "?";
            }

            return name;
        }

        return name + "?";
    }
}
