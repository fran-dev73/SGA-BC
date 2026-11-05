namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Abrir Ubicar Ensamblados SGA (ID 51110).
/// Abre "Ubicar entradas" en ensamblados. Existe para los menús: un rol center no admite
/// código en sus acciones (solo RunObject), y un filtro de RunPageView no llega a la página,
/// que es temporal.
/// </summary>
codeunit 51110 "Abrir Ubicar Ensamblados SGA"
{
    trigger OnRun()
    var
        cEntradas: Codeunit "Gestion Entradas SGA";
    begin
        cEntradas.AbrirUbicarEntradas("Origen Mov. SGA"::Produccion);
    end;
}
