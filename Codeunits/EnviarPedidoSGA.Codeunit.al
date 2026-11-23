namespace AntonioNadal.SGA;

using Microsoft.Sales.Document;

/// <summary>
/// Codeunit Enviar Pedido SGA (ID 51110).
/// Envía a SGA el pedido de venta que recibe (EnviarPedidoASGA). Existe para lanzarlo con
/// Codeunit.Run desde la segunda ronda: un pedido que no se puede enviar no para a los demás.
/// </summary>
codeunit 51110 "Enviar Pedido SGA"
{
    Access = Internal;
    TableNo = "Sales Header";

    var
        Creadas: Integer;

    trigger OnRun()
    var
        cPicking: Codeunit "Gestion Picking SGA";
        faltas: Text;
    begin
        Creadas := cPicking.EnviarPedidoASGA(Rec."No.", faltas);
    end;

    /// <summary>
    /// Órdenes de picking creadas en el último envío.
    /// </summary>
    procedure OrdenesCreadas(): Integer
    begin
        exit(Creadas);
    end;
}
