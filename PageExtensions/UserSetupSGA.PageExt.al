namespace AntonioNadal.SGA;

using System.Security.User;

/// <summary>
/// PageExtension User Setup SGA (ID 51105) extends Page "User Setup".
/// Muestra los permisos por usuario de SGA junto a los demás de la configuración de usuarios.
/// </summary>
pageextension 51105 "User Setup SGA" extends "User Setup"
{
    layout
    {
        addlast(Control1)
        {
            field("Responsable Picking SGA"; Rec."Responsable Picking SGA")
            {
                ApplicationArea = All;
            }
        }
    }
}
