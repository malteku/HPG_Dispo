*&---------------------------------------------------------------------*
*&  Include           /MBSO/R_MAT_DISPO_TOP
*&---------------------------------------------------------------------*
*& Globale Definitionen, Datentypen und Klassen-Definition fuer den
*& Materialdispo-Report.
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Konstanten
*----------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF c_mat_dispo,
    parvw_we      TYPE parvw VALUE 'WE',     "Warenempfaenger
    posnr_header  TYPE posnr VALUE '000000', "Kopf-Partner
    months_window TYPE i     VALUE 12,       "Anzahl Monatsspalten
  END OF c_mat_dispo.

*----------------------------------------------------------------------*
* Rohdaten der Faktura inkl. Warenempfaenger (Join-Ergebnis)
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_invoice_raw,
    vbeln TYPE vbrk-vbeln,
    posnr TYPE vbrp-posnr,
    fkdat TYPE vbrk-fkdat,
    kunwe TYPE kunnr,        "Warenempfaenger (aus VBPA)
    matnr TYPE vbrp-matnr,
    fkimg TYPE vbrp-fkimg,
    vrkme TYPE vbrp-vrkme,
  END OF ty_invoice_raw,
  tt_invoice_raw TYPE STANDARD TABLE OF ty_invoice_raw WITH EMPTY KEY.

*----------------------------------------------------------------------*
* Aufgeloeste Kundenhierarchie (zwei Stufen ueber Warenempfaenger)
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_hierarchy,
    kunnr       TYPE kunnr,        "Warenempfaenger
    hier1_kunnr TYPE kunnr,        "1. uebergeordnete Stufe
    hier1_name  TYPE name1,
    hier2_kunnr TYPE kunnr,        "2. uebergeordnete Stufe
    hier2_name  TYPE name1,
  END OF ty_hierarchy,
  tt_hierarchy TYPE HASHED TABLE OF ty_hierarchy WITH UNIQUE KEY kunnr.

*----------------------------------------------------------------------*
* Bestand pro Material (Summe LABST ueber alle Werke / Lagerorte)
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_stock,
    matnr   TYPE matnr,
    meins   TYPE meins,        "Basismengeneinheit (aus MARA)
    bestand TYPE labst,        "Frei verwendbarer Bestand
  END OF ty_stock,
  tt_stock TYPE HASHED TABLE OF ty_stock WITH UNIQUE KEY matnr.

*----------------------------------------------------------------------*
* Ergebniszeile fuer ALV-Ausgabe (Pivot 12 Monate)
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_result,
    "-- 2. Hierarchiestufe (oberste relevante)
    hier2_kunnr TYPE kunnr,
    hier2_name  TYPE name1,
    "-- 1. Hierarchiestufe (direkter Vorgesetzter)
    hier1_kunnr TYPE kunnr,
    hier1_name  TYPE name1,
    "-- Warenempfaenger
    kunnr       TYPE kunnr,
    name1       TYPE name1,
    "-- Material
    matnr       TYPE matnr,
    maktx       TYPE maktx,
    meins       TYPE meins,        "Basismengeneinheit
    bestand     TYPE labst,        "aktueller Bestand alle Werke/Lager
    vrkme       TYPE vrkme,        "Verkaufsmengeneinheit aus Faktura
    "-- 12 Monatsspalten (M01 = aeltester Monat im Zeitraum)
    m01         TYPE vbrp-fkimg,
    m02         TYPE vbrp-fkimg,
    m03         TYPE vbrp-fkimg,
    m04         TYPE vbrp-fkimg,
    m05         TYPE vbrp-fkimg,
    m06         TYPE vbrp-fkimg,
    m07         TYPE vbrp-fkimg,
    m08         TYPE vbrp-fkimg,
    m09         TYPE vbrp-fkimg,
    m10         TYPE vbrp-fkimg,
    m11         TYPE vbrp-fkimg,
    m12         TYPE vbrp-fkimg,
    "-- Gesamtsumme ueber den Zeitraum
    total       TYPE vbrp-fkimg,
  END OF ty_result,
  tt_result TYPE STANDARD TABLE OF ty_result
            WITH NON-UNIQUE KEY hier2_kunnr hier1_kunnr kunnr matnr.

*----------------------------------------------------------------------*
* Monatsbucket - Zuordnung Periode -> Spalte M01..M12
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_month_bucket,
    spmon       TYPE spmon,        "JJJJMM
    column_idx  TYPE i,            "1..12 -> M01..M12
    column_name TYPE fieldname,    "M01..M12
    header_text TYPE scrtext_m,    "z.B. 'MAI 2025'
  END OF ty_month_bucket,
  tt_month_bucket TYPE HASHED TABLE OF ty_month_bucket
                  WITH UNIQUE KEY spmon.

*----------------------------------------------------------------------*
* Lokale Klassen-Definition (Implementierung in _CL1-Include)
*----------------------------------------------------------------------*
CLASS lcl_main DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "! Dummy-Bezugsfeld fuer SELECT-OPTIONS s_matnr (kein TABLES noetig)
    CLASS-DATA matnr_dummy TYPE matnr.

    CLASS-METHODS:
      "! Setzt den Zeitraum-Default (letzte 12 Monate)
      set_default_period,

      "! Pruefung der Eingaben am Selektionsbild
      check_selection.

    METHODS:
      "! Steuerung des gesamten Reports
      run.

  PRIVATE SECTION.
    DATA:
      months    TYPE tt_month_bucket,
      invoices  TYPE tt_invoice_raw,
      hierarchy TYPE tt_hierarchy,
      result    TYPE tt_result.

    METHODS:
      "! Aufbau der 12 Monatsbuckets aus dem Selektionszeitraum
      build_month_buckets,

      "! Selektion der Fakturadaten inkl. Warenempfaenger
      select_invoices,

      "! Aufbau Kundenhierarchie (zwei uebergeordnete Stufen)
      build_hierarchy,

      "! Aggregation der Mengen je Kunde/Material/Monat (Pivot)
      aggregate_data,

      "! Anzeige der Ergebnisse mit CL_SALV_TABLE
      display_alv.

ENDCLASS.
