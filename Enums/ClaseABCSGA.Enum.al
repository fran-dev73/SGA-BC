namespace AntonioNadal.SGA;

/// <summary>
/// Enum Clase ABC SGA (ID 51110).
/// Clase de rotación de un producto, o de calidad de un hueco: A lo que más sale (o los mejores
/// huecos), C lo que menos. En blanco, sin clasificar.
/// </summary>
enum 51110 "Clase ABC SGA"
{
    Extensible = true;
    Caption = 'Clase ABC SGA';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; A)
    {
        Caption = 'A';
    }
    value(2; B)
    {
        Caption = 'B';
    }
    value(3; C)
    {
        Caption = 'C';
    }
}
