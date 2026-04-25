*&---------------------------------------------------------------------*
*& Report /MBSO/R_MAT_DISPO
*&---------------------------------------------------------------------*
*& Materialdisposition - Auswertung Fakturamengen pro Material
*& je Warenempfaenger und Kundenhierarchie als Pivot ueber 12 Monate.
*&
*& Hilft dem Einkauf bei der Disposition (Mengen / Zeitpunkte) durch
*& Auswertung der Fakturahistorie der letzten 12 Monate.
*&---------------------------------------------------------------------*
REPORT /mbso/r_mat_dispo.

INCLUDE /mbso/r_mat_dispo_top.
INCLUDE /mbso/r_mat_dispo_sel.
INCLUDE /mbso/r_mat_dispo_cl1.

*----------------------------------------------------------------------*
* Selektionsbild-Voreinstellung: Letzte 12 Monate
*----------------------------------------------------------------------*
INITIALIZATION.
  lcl_main=>set_default_period( ).

*----------------------------------------------------------------------*
* Plausibilitaetspruefung der Selektion
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  lcl_main=>check_selection( ).

*----------------------------------------------------------------------*
* Verarbeitung
*----------------------------------------------------------------------*
START-OF-SELECTION.
  NEW lcl_main( )->run( ).
