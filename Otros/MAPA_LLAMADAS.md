# Mapa de llamadas de SGA

Qué codeunit de SGA llama a cuál. Lo genera `GenerarMapaLlamadas.ps1`: no se edita a mano, se vuelve a generar.

Una flecha `A --> B` significa que el código de A nombra a B; no dice cuántas veces ni en qué orden. Páginas, informes y tablas no salen.

## Codeunits entre sí

La puerta de escritura es *Gestion Contenido SGA*; el motor de propuesta, *Gestion Ubicaciones SGA*.

```mermaid
flowchart LR
    n1[["Analisis ABC SGA"]]
    n9[["Gestion Ubicaciones SGA"]]
    n11[["Unidades Producto SGA"]]
    n2[["Carga Inicial SGA"]]
    n4[["Consulta Stock SGA"]]
    n5[["Gestion Contenido SGA"]]
    n12[["Ventana Progreso SGA"]]
    n6[["Gestion Entradas SGA"]]
    n8[["Gestion Picking SGA"]]
    n10[["Reubicaciones SGA"]]
    n7[["Gestion Mapa SGA"]]
    n3[["Codigos Barras SGA"]]
    n1 --> n9
    n1 --> n11
    n2 --> n4
    n2 --> n5
    n2 --> n9
    n2 --> n11
    n2 --> n12
    n4 --> n5
    n4 --> n6
    n4 --> n11
    n4 --> n12
    n5 --> n4
    n5 --> n8
    n5 --> n9
    n5 --> n10
    n5 --> n11
    n6 --> n4
    n6 --> n5
    n6 --> n9
    n6 --> n11
    n7 --> n1
    n7 --> n5
    n7 --> n9
    n7 --> n11
    n8 --> n4
    n8 --> n5
    n8 --> n11
    n9 --> n3
    n9 --> n5
    n9 --> n11
    n9 --> n12
    n10 --> n8
    n10 --> n9
    n10 --> n11
```

## Codeunits: qué usan y quién los llama

| Codeunit | Usa | Lo llaman |
|---|---|---|
| **Analisis ABC SGA** | Gestion Ubicaciones SGA, Unidades Producto SGA | Gestion Mapa SGA |
| **Carga Inicial SGA** | Consulta Stock SGA, Gestion Contenido SGA, Gestion Ubicaciones SGA, Unidades Producto SGA, Ventana Progreso SGA | — |
| **Codigos Barras SGA** | — | Gestion Ubicaciones SGA |
| **Consulta Stock SGA** | Gestion Contenido SGA, Gestion Entradas SGA, Unidades Producto SGA, Ventana Progreso SGA | Carga Inicial SGA, Gestion Contenido SGA, Gestion Entradas SGA, Gestion Picking SGA |
| **Gestion Contenido SGA** | Consulta Stock SGA, Gestion Picking SGA, Gestion Ubicaciones SGA, Reubicaciones SGA, Unidades Producto SGA | Carga Inicial SGA, Consulta Stock SGA, Gestion Entradas SGA, Gestion Mapa SGA, Gestion Picking SGA, Gestion Ubicaciones SGA |
| **Gestion Entradas SGA** | Consulta Stock SGA, Gestion Contenido SGA, Gestion Ubicaciones SGA, Unidades Producto SGA | Consulta Stock SGA |
| **Gestion Mapa SGA** | Analisis ABC SGA, Gestion Contenido SGA, Gestion Ubicaciones SGA, Unidades Producto SGA | — |
| **Gestion Picking SGA** | Consulta Stock SGA, Gestion Contenido SGA, Unidades Producto SGA | Gestion Contenido SGA, Reubicaciones SGA |
| **Gestion Ubicaciones SGA** | Codigos Barras SGA, Gestion Contenido SGA, Unidades Producto SGA, Ventana Progreso SGA | Analisis ABC SGA, Carga Inicial SGA, Gestion Contenido SGA, Gestion Entradas SGA, Gestion Mapa SGA, Reubicaciones SGA |
| **Reubicaciones SGA** | Gestion Picking SGA, Gestion Ubicaciones SGA, Unidades Producto SGA | Gestion Contenido SGA |
| **Unidades Producto SGA** | — | Analisis ABC SGA, Carga Inicial SGA, Consulta Stock SGA, Gestion Contenido SGA, Gestion Entradas SGA, Gestion Mapa SGA, Gestion Picking SGA, Gestion Ubicaciones SGA, Reubicaciones SGA |
| **Ventana Progreso SGA** | — | Carga Inicial SGA, Consulta Stock SGA, Gestion Ubicaciones SGA |

## Codeunits que ningún objeto de SGA nombra

No quiere decir que sobren: pueden ejecutarse desde el buscador, la cola de proyectos o una URL. Es la lista que hay que mirar al buscar código muerto.

Ninguno.

