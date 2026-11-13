namespace Savia.Application;

/// <summary>The words TagParser recognizes on a tag: labels, sizes, colors and materials.</summary>
public static partial class TagParser
{
    private static readonly string[] SkuLabels = ["SKU", "REF", "REFERENCIA", "CODIGO", "COD", "ART", "ARTICULO", "ESTILO", "STYLE", "MODELO", "MOD", "ITEM"];
    private static readonly string[] SizeLabels = ["TALLA", "SIZE", "TALLE", "TAL", "TLL"];
    private static readonly string[] ColorLabels = ["COLOR", "COLOUR", "COL"];
    private static readonly string[] BrandLabels = ["MARCA", "BRAND"];
    private static readonly string[] NameLabels = ["DESCRIPCION", "DESC", "PRODUCTO", "PRENDA", "DESCRIPTION"];
    private static readonly string[] PriceLabels = ["PRECIO", "PRICE", "PVP"];
    private static readonly HashSet<string> Sizes = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL"];

    private static readonly Dictionary<string, string> Colors = new(StringComparer.Ordinal)
    {
        ["AZUL"] = "Azul",
        ["BLUE"] = "Azul",
        ["NAVY"] = "Azul marino",
        ["NEGRO"] = "Negro",
        ["BLACK"] = "Negro",
        ["ROJO"] = "Rojo",
        ["RED"] = "Rojo",
        ["BLANCO"] = "Blanco",
        ["WHITE"] = "Blanco",
        ["VERDE"] = "Verde",
        ["GREEN"] = "Verde",
        ["GRIS"] = "Gris",
        ["GREY"] = "Gris",
        ["GRAY"] = "Gris",
        ["AMARILLO"] = "Amarillo",
        ["YELLOW"] = "Amarillo",
        ["ROSADO"] = "Rosado",
        ["ROSA"] = "Rosado",
        ["PINK"] = "Rosado",
        ["MORADO"] = "Morado",
        ["PURPLE"] = "Morado",
        ["CAFE"] = "Café",
        ["MARRON"] = "Café",
        ["BROWN"] = "Café",
        ["BEIGE"] = "Beige",
        ["NARANJA"] = "Naranja",
        ["ORANGE"] = "Naranja",
        ["CELESTE"] = "Celeste",
        ["CREMA"] = "Crema",
        ["VINO"] = "Vino",
        ["DORADO"] = "Dorado",
        ["PLATEADO"] = "Plateado",
        ["TURQUESA"] = "Turquesa",
        ["FUCSIA"] = "Fucsia",
        ["LILA"] = "Lila",
        ["KAKI"] = "Kaki",
        ["KHAKI"] = "Kaki",
        ["CAQUI"] = "Caqui",
        ["MOSTAZA"] = "Mostaza",
        ["CORAL"] = "Coral",
        ["AZUL MARINO"] = "Azul marino",
    };

    private static readonly Dictionary<string, string> Materials = new(StringComparer.Ordinal)
    {
        ["ALGODON"] = "Algodón",
        ["COTTON"] = "Algodón",
        ["POLIESTER"] = "Poliéster",
        ["POLYESTER"] = "Poliéster",
        ["ELASTANO"] = "Elastano",
        ["ELASTANE"] = "Elastano",
        ["SPANDEX"] = "Elastano",
        ["LYCRA"] = "Elastano",
        ["VISCOSA"] = "Viscosa",
        ["VISCOSE"] = "Viscosa",
        ["RAYON"] = "Rayón",
        ["ACRILICO"] = "Acrílico",
        ["ACRYLIC"] = "Acrílico",
        ["ACRILIC"] = "Acrílico",
        ["LANA"] = "Lana",
        ["WOOL"] = "Lana",
        ["LINO"] = "Lino",
        ["LINEN"] = "Lino",
        ["SEDA"] = "Seda",
        ["SILK"] = "Seda",
        ["NYLON"] = "Nailon",
        ["NAILON"] = "Nailon",
        ["POLIAMIDA"] = "Poliamida",
        ["POLYAMIDE"] = "Poliamida",
        ["MODAL"] = "Modal",
        ["CUERO"] = "Cuero",
        ["LEATHER"] = "Cuero",
    };
}
