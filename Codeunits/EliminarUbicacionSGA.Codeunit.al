namespace AntonioNadal.SGA;

using Microsoft.Warehouse.Structure;

/// <summary>
/// Codeunit Eliminar Ubicacion SGA (ID 51112).
/// Borra una ubicación entera: su ficha SGA y el Bin estándar, con el borrado de BC (que se
/// lleva el contenido de ubicación de BC y no deja borrar un hueco con stock en almacén o con
/// documentos pendientes). Va aparte para lanzarlo con Codeunit.Run, un hueco por transacción:
/// el que BC no deja borrar se queda entero y no tumba el resto. Lo llama EliminarUbicaciones
/// de Cod. "Gestion Ubicaciones SGA".
/// </summary>
codeunit 51112 "Eliminar Ubicacion SGA"
{
    Access = Internal;
    TableNo = Bin;

    trigger OnRun()
    var
        rUbicacionSGA: Record "Ubicacion SGA";
    begin
        if rUbicacionSGA.Get(Rec."Location Code", Rec.Code) then
            rUbicacionSGA.Delete(true);
        Rec.Delete(true);
    end;
}
