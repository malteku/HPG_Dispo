# Projekt-Richtlinien: ABAP Entwicklung (/MBSO/)

## System-Umgebung
- **SAP Basis Release:** 750 (Non-S/4HANA)
- **Namespace:** `/MBSO/`
- **Fokus:** Clean ABAP, Objektorientierung, S/4HANA-Readiness

## Report-Struktur (Standard)
Jeder Report muss zwingend nach folgendem Muster mit drei Includes aufgebaut sein:
1. `INCLUDE /mbso/*reportname*_top.`  - Globale Definitionen (Datentypen, Klassen-Definitionen)
2. `INCLUDE /mbso/*reportname*_sel.`  - Selektionsbilder (PARAMETERS, SELECT-OPTIONS)
3. `INCLUDE /mbso/*reportname*_cl1.`  - Logik (Klassen-Implementierungen)

*Hinweis: Die eigentliche Programmlogik muss in lokalen Klassen innerhalb des `_cl1`-Includes gekapselt werden. Das Hauptprogramm führt lediglich den Instanziierungs- und Startaufruf aus.*

## Coding-Standards (Clean ABAP)
- **Objektorientierung:** Nutze ausschließlich Klassen und Methoden. Vermeide `FORM`-Routinen.
- **Moderne Syntax (7.50):** - Nutze Inline-Deklarationen: `DATA(lt_data) = ...` oder `READ TABLE ... ASSIGNING FIELD-SYMBOL(<fs_data>)`.
  - Nutze Konstruktor-Operatoren: `VALUE`, `NEW`, `CORRESPONDING`.
  - Nutze String-Templates: `|Text { lv_var }|`.
- **Benennung:** - Variablen: Sprechende Namen (z.B. `sales_order` statt `lv_vbeln`).
  - Präfixe: Minimalistisch gemäß ABAP Clean Code (keine ungarische Notation wie `gt_`, `ls_`, außer es dient der Klarheit).
- **Vermeide Obsoleten Code:** Kein `TABLES`, kein `OCCURS`, keine `HEADER LINE`.

## S/4HANA Migration & Kompatibilität
- **Tabellenzugriffe:** Vermeide direkte Zugriffe auf Tabellen, die in S/4HANA durch Views ersetzt wurden oder wegfallen 
- **Open SQL:** Nutze die neue Open-SQL-Syntax (Kommas als Trenner, Host-Variablen mit `@`).
- **Funktionsbausteine:** Prüfe, ob es für Standard-Aufgaben bereits modernere Klassen gibt (z.B. `CL_SALV_TABLE` statt `REUSE_ALV`).
- **Strikte Typisierung:** Nutze immer `TYPE` statt `LIKE` (außer bei Datenbankbezügen im `SELECT`).

## Befehle & Workflows
- **Dokumentation:** Kommentare auf Deutsch, technischer Fokus. Komplexe Logik wird in der Methode per ABAP Doc erklärt.
