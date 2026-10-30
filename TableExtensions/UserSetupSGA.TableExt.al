namespace AntonioNadal.SGA;

using System.Security.User;

/// <summary>
/// TableExtension User Setup SGA (ID 51100) extends Record "User Setup".
/// Permisos por usuario del módulo SGA.
///
/// Va en una extensión propia, y no en Tab-Ext50110 "User Setup", para que el módulo siga
/// siendo autocontenido dentro de su carpeta.
/// </summary>
tableextension 51100 "User Setup SGA" extends "User Setup"
{
    fields
    {
        field(51100; "Responsable Picking SGA"; Boolean)
        {
            Caption = 'Responsable picking SGA';
            DataClassification = ToBeClassified;
            ToolTip = 'Puede repartir las órdenes de picking entre preparadores y cambiar su prioridad. Solo se comprueba si la configuración de SGA exige asignación de picking.';
        }
    }
}
