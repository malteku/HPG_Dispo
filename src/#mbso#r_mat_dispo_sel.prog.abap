*&---------------------------------------------------------------------*
*&  Include           /MBSO/R_MAT_DISPO_SEL
*&---------------------------------------------------------------------*
*& Selektionsbild fuer den Materialdispo-Report
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Block 1: Vertriebsdaten
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_org WITH FRAME TITLE TEXT-b01.

PARAMETERS:
  p_vkorg TYPE vbrk-vkorg OBLIGATORY,
  p_vtweg TYPE vbrk-vtweg OBLIGATORY.

SELECTION-SCREEN END OF BLOCK b_org.

*----------------------------------------------------------------------*
* Block 2: Material
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_mat WITH FRAME TITLE TEXT-b02.

SELECT-OPTIONS:
  s_matnr FOR lcl_main=>matnr_dummy.

SELECTION-SCREEN END OF BLOCK b_mat.

*----------------------------------------------------------------------*
* Block 3: Zeitraum (Default: Letzte 12 Monate, aber frei aenderbar)
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_per WITH FRAME TITLE TEXT-b03.

SELECT-OPTIONS:
  s_fkdat FOR sy-datum.

SELECTION-SCREEN END OF BLOCK b_per.

*----------------------------------------------------------------------*
* Block 4: Kundenhierarchie
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_hir WITH FRAME TITLE TEXT-b04.

PARAMETERS:
  p_hityp TYPE knvh-hityp DEFAULT 'A'.

SELECTION-SCREEN END OF BLOCK b_hir.
