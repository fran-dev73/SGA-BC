namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Abrir Ubicar Recepciones SGA (ID 51109).
/// Abre "Ubicar entradas" en recepciones de compra. Existe para los menús: un rol center no
/// admite código en sus acciones (solo RunObject), y un filtro de RunPageView no llega a la
/// página, que es temporal.
/// </summary>
codeunit 51109 "Abrir Ubicar Recepciones SGA"
{
    trigger OnRun()
    var
        cEntradas: Codeunit "Gestion Entradas SGA";
    begin
        cEntradas.AbrirUbicarEntradas("Origen Mov. SGA"::Compra);
    end;
}
