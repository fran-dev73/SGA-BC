namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Consulta Ubicaciones SGA (ID 51112).
/// Abre "Ubicaciones SGA" en solo consulta (AbrirSoloConsulta). Existe porque las acciones de
/// un rol center no pueden llevar código: las entradas de Consultas lo lanzan con RunObject.
/// </summary>
codeunit 51112 "Consulta Ubicaciones SGA"
{
    Access = Internal;

    trigger OnRun()
    var
        pUbicaciones: Page "Ubicaciones SGA";
    begin
        pUbicaciones.AbrirSoloConsulta();
    end;
}
