namespace AntonioNadal.SGA;

/// <summary>
/// Codeunit Ventana Progreso SGA (ID 51111).
/// Ventana de progreso de los procesos largos (carga inicial, pendiente de ubicar): qué se está
/// haciendo y una barra. Solo con interfaz; sin ella no hace nada. Refrescarla cuesta, así que
/// Avanzar la repinta como mucho unas tres veces por segundo. Si el proceso acaba en error
/// (también el fin de una simulación), BC la cierra sola.
/// </summary>
codeunit 51111 "Ventana Progreso SGA"
{
    Access = Public;

    /// <summary>
    /// Abre la ventana con prm_Titulo encima. prm_Total es cuántas veces se llamará a Avanzar;
    /// si aún no se sabe, 0 y luego FijarTotal.
    /// </summary>
    procedure Abrir(prm_Titulo: Text; prm_Total: Integer)
    var
        // Va debajo del título: #1 = qué se está haciendo, @2 = barra de progreso.
        ControlesTok: Label '\\#1##############################\@2@@@@@@@@@@@@@@@@@@@@@@@@@@@@@', Locked = true;
    begin
        Abierta := GuiAllowed();
        if not Abierta then
            exit;
        Total := prm_Total;
        Hechos := 0;
        UltimaVez := CurrentDateTime();
        Ventana.Open(prm_Titulo + ControlesTok);
    end;

    procedure FijarTotal(prm_Total: Integer)
    begin
        Total := prm_Total;
    end;

    /// <summary>
    /// Enseña ya qué se está haciendo, sin esperar ni avanzar la barra.
    /// </summary>
    procedure Fase(prm_Texto: Text)
    begin
        if Abierta then
            Ventana.Update(1, prm_Texto);
    end;

    /// <summary>
    /// Un paso más de Total, con lo que se está haciendo.
    /// </summary>
    procedure Avanzar(prm_Texto: Text)
    begin
        if not Abierta then
            exit;
        Hechos += 1;
        if CurrentDateTime() - UltimaVez < 300 then
            exit;
        Ventana.Update(1, prm_Texto);
        if Total > 0 then
            Ventana.Update(2, Round(Hechos / Total * 10000, 1));
        UltimaVez := CurrentDateTime();
    end;

    procedure Cerrar()
    begin
        if Abierta then
            Ventana.Close();
        Abierta := false;
    end;

    var
        Ventana: Dialog;
        Abierta: Boolean;
        Total: Integer;
        Hechos: Integer;
        UltimaVez: DateTime;
}
