namespace AntonioNadal.SGA;

/// <summary>
/// Table Buffer Mapa SGA (ID 51106).
/// Tabla temporal que alimenta la página "Mapa Almacen SGA". Cada fila es una altura de
/// un pasillo y cada columna "Columna NN" es la ubicación de la estantería NN, con su
/// texto de ocupación y su estilo de color en "Estilo NN".
///
/// Se rellena en memoria con Cod. "Gestion Mapa SGA"; no persiste datos.
/// El límite de 32 columnas es el de la rejilla: si un pasillo tiene más estanterías,
/// el mapa avisa y muestra las primeras 32.
/// </summary>
table 51106 "Buffer Mapa SGA"
{
    Caption = 'Buffer mapa SGA';
    DataClassification = ToBeClassified;
    TableType = Temporary;

    fields
    {
        field(10; "Cod. Almacen"; Code[10])
        {
            Caption = 'Cód. almacén';
            DataClassification = ToBeClassified;
        }
        field(30; Pasillo; Integer)
        {
            Caption = 'Pasillo';
            DataClassification = ToBeClassified;
        }
        field(40; Altura; Integer)
        {
            Caption = 'Altura';
            DataClassification = ToBeClassified;
        }
        field(50; Orden; Integer)
        {
            Caption = 'Orden';
            DataClassification = ToBeClassified;
        }
        field(100; "Columna 01"; Text[50])
        {
            Caption = 'E01';
            DataClassification = ToBeClassified;
        }
        field(101; "Columna 02"; Text[50])
        {
            Caption = 'E02';
            DataClassification = ToBeClassified;
        }
        field(102; "Columna 03"; Text[50])
        {
            Caption = 'E03';
            DataClassification = ToBeClassified;
        }
        field(103; "Columna 04"; Text[50])
        {
            Caption = 'E04';
            DataClassification = ToBeClassified;
        }
        field(104; "Columna 05"; Text[50])
        {
            Caption = 'E05';
            DataClassification = ToBeClassified;
        }
        field(105; "Columna 06"; Text[50])
        {
            Caption = 'E06';
            DataClassification = ToBeClassified;
        }
        field(106; "Columna 07"; Text[50])
        {
            Caption = 'E07';
            DataClassification = ToBeClassified;
        }
        field(107; "Columna 08"; Text[50])
        {
            Caption = 'E08';
            DataClassification = ToBeClassified;
        }
        field(108; "Columna 09"; Text[50])
        {
            Caption = 'E09';
            DataClassification = ToBeClassified;
        }
        field(109; "Columna 10"; Text[50])
        {
            Caption = 'E10';
            DataClassification = ToBeClassified;
        }
        field(110; "Columna 11"; Text[50])
        {
            Caption = 'E11';
            DataClassification = ToBeClassified;
        }
        field(111; "Columna 12"; Text[50])
        {
            Caption = 'E12';
            DataClassification = ToBeClassified;
        }
        field(112; "Columna 13"; Text[50])
        {
            Caption = 'E13';
            DataClassification = ToBeClassified;
        }
        field(113; "Columna 14"; Text[50])
        {
            Caption = 'E14';
            DataClassification = ToBeClassified;
        }
        field(114; "Columna 15"; Text[50])
        {
            Caption = 'E15';
            DataClassification = ToBeClassified;
        }
        field(115; "Columna 16"; Text[50])
        {
            Caption = 'E16';
            DataClassification = ToBeClassified;
        }
        field(116; "Columna 17"; Text[50])
        {
            Caption = 'E17';
            DataClassification = ToBeClassified;
        }
        field(117; "Columna 18"; Text[50])
        {
            Caption = 'E18';
            DataClassification = ToBeClassified;
        }
        field(118; "Columna 19"; Text[50])
        {
            Caption = 'E19';
            DataClassification = ToBeClassified;
        }
        field(119; "Columna 20"; Text[50])
        {
            Caption = 'E20';
            DataClassification = ToBeClassified;
        }
        field(120; "Columna 21"; Text[50])
        {
            Caption = 'E21';
            DataClassification = ToBeClassified;
        }
        field(121; "Columna 22"; Text[50])
        {
            Caption = 'E22';
            DataClassification = ToBeClassified;
        }
        field(122; "Columna 23"; Text[50])
        {
            Caption = 'E23';
            DataClassification = ToBeClassified;
        }
        field(123; "Columna 24"; Text[50])
        {
            Caption = 'E24';
            DataClassification = ToBeClassified;
        }
        field(124; "Columna 25"; Text[50])
        {
            Caption = 'E25';
            DataClassification = ToBeClassified;
        }
        field(125; "Columna 26"; Text[50])
        {
            Caption = 'E26';
            DataClassification = ToBeClassified;
        }
        field(126; "Columna 27"; Text[50])
        {
            Caption = 'E27';
            DataClassification = ToBeClassified;
        }
        field(127; "Columna 28"; Text[50])
        {
            Caption = 'E28';
            DataClassification = ToBeClassified;
        }
        field(128; "Columna 29"; Text[50])
        {
            Caption = 'E29';
            DataClassification = ToBeClassified;
        }
        field(129; "Columna 30"; Text[50])
        {
            Caption = 'E30';
            DataClassification = ToBeClassified;
        }
        field(130; "Columna 31"; Text[50])
        {
            Caption = 'E31';
            DataClassification = ToBeClassified;
        }
        field(131; "Columna 32"; Text[50])
        {
            Caption = 'E32';
            DataClassification = ToBeClassified;
        }
        field(200; "Estilo 01"; Text[20])
        {
            Caption = 'Estilo E01';
            DataClassification = ToBeClassified;
        }
        field(201; "Estilo 02"; Text[20])
        {
            Caption = 'Estilo E02';
            DataClassification = ToBeClassified;
        }
        field(202; "Estilo 03"; Text[20])
        {
            Caption = 'Estilo E03';
            DataClassification = ToBeClassified;
        }
        field(203; "Estilo 04"; Text[20])
        {
            Caption = 'Estilo E04';
            DataClassification = ToBeClassified;
        }
        field(204; "Estilo 05"; Text[20])
        {
            Caption = 'Estilo E05';
            DataClassification = ToBeClassified;
        }
        field(205; "Estilo 06"; Text[20])
        {
            Caption = 'Estilo E06';
            DataClassification = ToBeClassified;
        }
        field(206; "Estilo 07"; Text[20])
        {
            Caption = 'Estilo E07';
            DataClassification = ToBeClassified;
        }
        field(207; "Estilo 08"; Text[20])
        {
            Caption = 'Estilo E08';
            DataClassification = ToBeClassified;
        }
        field(208; "Estilo 09"; Text[20])
        {
            Caption = 'Estilo E09';
            DataClassification = ToBeClassified;
        }
        field(209; "Estilo 10"; Text[20])
        {
            Caption = 'Estilo E10';
            DataClassification = ToBeClassified;
        }
        field(210; "Estilo 11"; Text[20])
        {
            Caption = 'Estilo E11';
            DataClassification = ToBeClassified;
        }
        field(211; "Estilo 12"; Text[20])
        {
            Caption = 'Estilo E12';
            DataClassification = ToBeClassified;
        }
        field(212; "Estilo 13"; Text[20])
        {
            Caption = 'Estilo E13';
            DataClassification = ToBeClassified;
        }
        field(213; "Estilo 14"; Text[20])
        {
            Caption = 'Estilo E14';
            DataClassification = ToBeClassified;
        }
        field(214; "Estilo 15"; Text[20])
        {
            Caption = 'Estilo E15';
            DataClassification = ToBeClassified;
        }
        field(215; "Estilo 16"; Text[20])
        {
            Caption = 'Estilo E16';
            DataClassification = ToBeClassified;
        }
        field(216; "Estilo 17"; Text[20])
        {
            Caption = 'Estilo E17';
            DataClassification = ToBeClassified;
        }
        field(217; "Estilo 18"; Text[20])
        {
            Caption = 'Estilo E18';
            DataClassification = ToBeClassified;
        }
        field(218; "Estilo 19"; Text[20])
        {
            Caption = 'Estilo E19';
            DataClassification = ToBeClassified;
        }
        field(219; "Estilo 20"; Text[20])
        {
            Caption = 'Estilo E20';
            DataClassification = ToBeClassified;
        }
        field(220; "Estilo 21"; Text[20])
        {
            Caption = 'Estilo E21';
            DataClassification = ToBeClassified;
        }
        field(221; "Estilo 22"; Text[20])
        {
            Caption = 'Estilo E22';
            DataClassification = ToBeClassified;
        }
        field(222; "Estilo 23"; Text[20])
        {
            Caption = 'Estilo E23';
            DataClassification = ToBeClassified;
        }
        field(223; "Estilo 24"; Text[20])
        {
            Caption = 'Estilo E24';
            DataClassification = ToBeClassified;
        }
        field(224; "Estilo 25"; Text[20])
        {
            Caption = 'Estilo E25';
            DataClassification = ToBeClassified;
        }
        field(225; "Estilo 26"; Text[20])
        {
            Caption = 'Estilo E26';
            DataClassification = ToBeClassified;
        }
        field(226; "Estilo 27"; Text[20])
        {
            Caption = 'Estilo E27';
            DataClassification = ToBeClassified;
        }
        field(227; "Estilo 28"; Text[20])
        {
            Caption = 'Estilo E28';
            DataClassification = ToBeClassified;
        }
        field(228; "Estilo 29"; Text[20])
        {
            Caption = 'Estilo E29';
            DataClassification = ToBeClassified;
        }
        field(229; "Estilo 30"; Text[20])
        {
            Caption = 'Estilo E30';
            DataClassification = ToBeClassified;
        }
        field(230; "Estilo 31"; Text[20])
        {
            Caption = 'Estilo E31';
            DataClassification = ToBeClassified;
        }
        field(231; "Estilo 32"; Text[20])
        {
            Caption = 'Estilo E32';
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(PK; "Cod. Almacen", Pasillo, Orden)
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Asigna el texto y el estilo de una columna de la rejilla (1-32).
    /// </summary>
    procedure FijarColumna(prm_Columna: Integer; prm_Texto: Text; prm_Estilo: Text)
    begin
        case prm_Columna of
            1:
                begin
                    "Columna 01" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 01"));
                    "Estilo 01" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 01"));
                end;
            2:
                begin
                    "Columna 02" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 02"));
                    "Estilo 02" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 02"));
                end;
            3:
                begin
                    "Columna 03" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 03"));
                    "Estilo 03" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 03"));
                end;
            4:
                begin
                    "Columna 04" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 04"));
                    "Estilo 04" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 04"));
                end;
            5:
                begin
                    "Columna 05" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 05"));
                    "Estilo 05" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 05"));
                end;
            6:
                begin
                    "Columna 06" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 06"));
                    "Estilo 06" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 06"));
                end;
            7:
                begin
                    "Columna 07" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 07"));
                    "Estilo 07" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 07"));
                end;
            8:
                begin
                    "Columna 08" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 08"));
                    "Estilo 08" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 08"));
                end;
            9:
                begin
                    "Columna 09" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 09"));
                    "Estilo 09" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 09"));
                end;
            10:
                begin
                    "Columna 10" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 10"));
                    "Estilo 10" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 10"));
                end;
            11:
                begin
                    "Columna 11" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 11"));
                    "Estilo 11" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 11"));
                end;
            12:
                begin
                    "Columna 12" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 12"));
                    "Estilo 12" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 12"));
                end;
            13:
                begin
                    "Columna 13" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 13"));
                    "Estilo 13" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 13"));
                end;
            14:
                begin
                    "Columna 14" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 14"));
                    "Estilo 14" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 14"));
                end;
            15:
                begin
                    "Columna 15" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 15"));
                    "Estilo 15" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 15"));
                end;
            16:
                begin
                    "Columna 16" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 16"));
                    "Estilo 16" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 16"));
                end;
            17:
                begin
                    "Columna 17" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 17"));
                    "Estilo 17" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 17"));
                end;
            18:
                begin
                    "Columna 18" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 18"));
                    "Estilo 18" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 18"));
                end;
            19:
                begin
                    "Columna 19" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 19"));
                    "Estilo 19" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 19"));
                end;
            20:
                begin
                    "Columna 20" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 20"));
                    "Estilo 20" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 20"));
                end;
            21:
                begin
                    "Columna 21" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 21"));
                    "Estilo 21" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 21"));
                end;
            22:
                begin
                    "Columna 22" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 22"));
                    "Estilo 22" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 22"));
                end;
            23:
                begin
                    "Columna 23" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 23"));
                    "Estilo 23" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 23"));
                end;
            24:
                begin
                    "Columna 24" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 24"));
                    "Estilo 24" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 24"));
                end;
            25:
                begin
                    "Columna 25" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 25"));
                    "Estilo 25" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 25"));
                end;
            26:
                begin
                    "Columna 26" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 26"));
                    "Estilo 26" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 26"));
                end;
            27:
                begin
                    "Columna 27" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 27"));
                    "Estilo 27" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 27"));
                end;
            28:
                begin
                    "Columna 28" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 28"));
                    "Estilo 28" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 28"));
                end;
            29:
                begin
                    "Columna 29" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 29"));
                    "Estilo 29" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 29"));
                end;
            30:
                begin
                    "Columna 30" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 30"));
                    "Estilo 30" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 30"));
                end;
            31:
                begin
                    "Columna 31" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 31"));
                    "Estilo 31" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 31"));
                end;
            32:
                begin
                    "Columna 32" := CopyStr(prm_Texto, 1, MaxStrLen("Columna 32"));
                    "Estilo 32" := CopyStr(prm_Estilo, 1, MaxStrLen("Estilo 32"));
                end;
        end;
    end;
}
