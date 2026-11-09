namespace AntonioNadal.SGA;

using Microsoft.Inventory.Item;

/// <summary>
/// Table Clasificacion ABC SGA (ID 51113).
/// Una línea por producto y cálculo ABC: cuánto ha salido, en qué clase queda y cuántos de sus
/// palés están en un hueco de esa misma clase. Lo genera Cod. "Analisis ABC SGA".
/// </summary>
table 51113 "Clasificacion ABC SGA"
{
    Caption = 'Clasificación ABC SGA';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "No. Calculo"; Integer)
        {
            ToolTip = 'Cálculo ABC al que pertenece la línea.';
            Caption = 'Nº cálculo';
            DataClassification = ToBeClassified;
            TableRelation = "Calculo ABC SGA";
        }
        field(2; "No. Producto"; Code[20])
        {
            ToolTip = 'Producto clasificado.';
            Caption = 'Nº producto';
            DataClassification = ToBeClassified;
            TableRelation = Item;
        }
        field(10; "Cod. Almacen"; Code[10])
        {
            ToolTip = 'Almacén analizado.';
            Caption = 'Almacén';
            DataClassification = ToBeClassified;
        }
        field(11; Descripcion; Text[100])
        {
            ToolTip = 'Descripción del producto.';
            Caption = 'Descripción';
            DataClassification = ToBeClassified;
        }
        field(20; Posicion; Integer)
        {
            Caption = 'Posición';
            DataClassification = ToBeClassified;
            ToolTip = 'Puesto del producto ordenando de más a menos palés salidos.';
        }
        field(21; Clase; Enum "Clase ABC SGA")
        {
            ToolTip = 'Clase de rotación: A los que más palés salen, C los que menos.';
            Caption = 'Clase';
            DataClassification = ToBeClassified;
        }
        field(22; "Clase Anterior"; Enum "Clase ABC SGA")
        {
            Caption = 'Clase anterior';
            DataClassification = ToBeClassified;
            ToolTip = 'Clase que tenía en el cálculo anterior del mismo almacén. En blanco si no salía.';
        }
        field(23; "Cambia Clase"; Boolean)
        {
            ToolTip = 'La clase es distinta de la del cálculo anterior.';
            Caption = 'Cambia de clase';
            DataClassification = ToBeClassified;
        }
        field(30; "Cantidad Salida Base"; Decimal)
        {
            ToolTip = 'Ventas netas del periodo en la unidad base del producto.';
            Caption = 'Cantidad vendida (UM base)';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(31; "Unidad Pale"; Code[10])
        {
            ToolTip = 'Unidad de palé del producto, con la que se pasan las ventas a palés.';
            Caption = 'Unidad de palé';
            DataClassification = ToBeClassified;
        }
        field(32; "Sin Unidad Pale"; Boolean)
        {
            Caption = 'Sin unidad de palé';
            DataClassification = ToBeClassified;
            ToolTip = 'El producto no tiene unidad de palé: sus ventas no se pueden pasar a palés y queda como C.';
        }
        field(33; "Palets Salidos"; Decimal)
        {
            ToolTip = 'Palés vendidos en el periodo (ventas netas entre lo que lleva un palé).';
            Caption = 'Palés salidos';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 1;
        }
        field(34; "% Salidas"; Decimal)
        {
            ToolTip = 'Parte de los palés salidos del almacén que corresponde a este producto.';
            Caption = '% de las salidas';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 1;
        }
        field(35; "% Acumulado"; Decimal)
        {
            Caption = '% acumulado';
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 1;
            ToolTip = 'Suma de las salidas de este producto y de todos los que salen más que él.';
        }
        field(40; "Palets en Almacen"; Integer)
        {
            ToolTip = 'Palés del producto que hay ahora en huecos de picking y almacenamiento.';
            Caption = 'Palés en almacén';
            DataClassification = ToBeClassified;
        }
        field(41; "Palets Hueco Su Clase"; Integer)
        {
            ToolTip = 'Palés del producto que están en un hueco de su misma clase.';
            Caption = 'Palés en hueco de su clase';
            DataClassification = ToBeClassified;
        }
        field(42; "Mal Ubicado"; Boolean)
        {
            ToolTip = 'Tiene algún palé en un hueco de otra clase.';
            Caption = 'Con palés fuera de su clase';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; "No. Calculo", "No. Producto")
        {
            Clustered = true;
        }
        key(Orden; "No. Calculo", Posicion)
        {
        }
        key(Salidas; "No. Calculo", "Palets Salidos")
        {
        }
    }

    /// <summary>
    /// Estilo de la columna Clase: A en verde, B en ámbar y C apagada.
    /// </summary>
    procedure EstiloClaseABC(): Text
    begin
        case Clase of
            Clase::A:
                exit('Favorable');
            Clase::B:
                exit('Ambiguous');
        end;

        exit('Subordinate');
    end;

    /// <summary>
    /// Estilo de la clase anterior: en rojo si el producto cambia de clase.
    /// </summary>
    procedure EstiloClaseAnterior(): Text
    begin
        exit(EstiloAviso("Cambia Clase"));
    end;

    /// <summary>
    /// Estilo de los palés en hueco de su clase: en rojo si tiene palés fuera de su clase.
    /// </summary>
    procedure EstiloHuecoSuClase(): Text
    begin
        exit(EstiloAviso("Mal Ubicado"));
    end;

    /// <summary>
    /// Estilo de la unidad de palé: en rojo si el producto no la tiene.
    /// </summary>
    procedure EstiloUnidadPale(): Text
    begin
        exit(EstiloAviso("Sin Unidad Pale"));
    end;

    local procedure EstiloAviso(prm_Aviso: Boolean): Text
    begin
        if prm_Aviso then
            exit('Unfavorable');

        exit('Standard');
    end;
}
