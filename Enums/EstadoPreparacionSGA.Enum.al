namespace AntonioNadal.SGA;

/// <summary>
/// Enum Estado Preparacion SGA (ID 51111).
/// Cuánto está preparado (recogido en picking) de lo que queda por enviar de un pedido de
/// venta. Se calcula al momento con EstadoPreparacionVenta de "Gestion Picking SGA".
/// </summary>
enum 51111 "Estado Preparacion SGA"
{
    Extensible = true;
    Caption = 'Estado preparación SGA';

    value(0; " ")
    {
        Caption = ' ', Comment = 'El pedido no tiene nada pendiente de enviar.';
    }
    value(1; "Sin Preparar")
    {
        Caption = 'Sin preparar';
    }
    value(2; Parcial)
    {
        Caption = 'Parcial';
    }
    value(3; Preparado)
    {
        Caption = 'Preparado';
    }
}
