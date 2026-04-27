*&---------------------------------------------------------------------*
*&  Include           /MBSO/R_MAT_DISPO_CL1
*&---------------------------------------------------------------------*
*& Implementierung der lokalen Klasse(n) fuer den Materialdispo-Report
*&---------------------------------------------------------------------*

CLASS lcl_main IMPLEMENTATION.

  METHOD set_default_period.
*   Default: erster Tag (heutiger Monat - 11) bis letzter Tag (heutiger Monat)
    DATA(month_start) = sy-datum.
    month_start+6(2)  = '01'.

*   letzter Tag des aktuellen Monats: Anfang Folgemonat - 1 Tag
    DATA(next_month)  = month_start + 31.
    next_month+6(2)   = '01'.
    DATA(period_high) = next_month - 1.

*   erster Tag von vor 11 Monaten = 12-Monats-Window
    DATA(period_low) = month_start.
    DO 11 TIMES.
      period_low = period_low - 1.
      period_low+6(2) = '01'.
    ENDDO.

    s_fkdat = VALUE #( ( sign   = 'I'
                         option = 'BT'
                         low    = period_low
                         high   = period_high ) ).
  ENDMETHOD.


  METHOD check_selection.
    IF s_fkdat IS INITIAL.
      MESSAGE 'Bitte einen Zeitraum angeben.' TYPE 'E'.
    ENDIF.

    READ TABLE s_fkdat INTO DATA(period) INDEX 1.
    IF sy-subrc = 0 AND period-low IS NOT INITIAL AND period-high IS NOT INITIAL.
      DATA months_diff TYPE i.
      months_diff = ( period-high+0(4) - period-low+0(4) ) * 12
                  + ( period-high+4(2) - period-low+4(2) ) + 1.
      IF months_diff > c_mat_dispo-months_window.
        MESSAGE |Zeitraum umfasst { months_diff } Monate – Pivot zeigt nur die ersten { c_mat_dispo-months_window } Monate.|
                TYPE 'I'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD run.
    build_month_buckets( ).
    select_invoices( ).

    IF invoices IS INITIAL.
      MESSAGE 'Keine Fakturadaten zur Selektion gefunden.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    build_hierarchy( ).
    aggregate_data( ).
    display_alv( ).
  ENDMETHOD.


  METHOD build_month_buckets.
    READ TABLE s_fkdat INTO DATA(period) INDEX 1.
    IF sy-subrc <> 0 OR period-low IS INITIAL.
      RETURN.
    ENDIF.

    DATA(start_date) = period-low.
    start_date+6(2)  = '01'.   "auf Monatsanfang normieren

    DATA(month_names) = VALUE stringtab(
      ( |JAN| ) ( |FEB| ) ( |MAR| ) ( |APR| ) ( |MAI| ) ( |JUN| )
      ( |JUL| ) ( |AUG| ) ( |SEP| ) ( |OKT| ) ( |NOV| ) ( |DEZ| ) ).

    DATA(current) = start_date.
    DO c_mat_dispo-months_window TIMES.
      DATA(idx)        = sy-index.
      DATA(year)       = current+0(4).
      DATA(month_no)   = CONV i( current+4(2) ).
      DATA(month_text) = VALUE #( month_names[ month_no ] OPTIONAL ).

      INSERT VALUE ty_month_bucket(
        spmon       = |{ year }{ current+4(2) }|
        column_idx  = idx
        column_name = |M{ idx WIDTH = 2 ALIGN = RIGHT PAD = '0' }|
        header_text = |{ month_text } { year }|
      ) INTO TABLE months.

*     Naechsten Monat berechnen: +31 Tage, dann auf 1. setzen
      current = current + 31.
      current+6(2) = '01'.
    ENDDO.
  ENDMETHOD.


  METHOD select_invoices.
    IF s_matnr IS INITIAL.
      MESSAGE 'Keine Materialeinschraenkung gewaehlt – Selektion kann lange dauern.'
              TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

    SELECT k~vbeln,
           p~posnr,
           k~fkdat,
           pa~kunnr AS kunwe,
           p~matnr,
           p~fkimg,
           p~vrkme
      FROM vbrk AS k
        INNER JOIN vbrp AS p
          ON p~vbeln = k~vbeln
        INNER JOIN vbpa AS pa
          ON  pa~vbeln = k~vbeln
          AND pa~posnr = @c_mat_dispo-posnr_header
          AND pa~parvw = @c_mat_dispo-parvw_we
      WHERE k~vkorg =  @p_vkorg
        AND k~vtweg =  @p_vtweg
        AND k~fkdat IN @s_fkdat
        AND k~fksto =  @space
        AND p~matnr IN @s_matnr
      INTO CORRESPONDING FIELDS OF TABLE @invoices.
  ENDMETHOD.


  METHOD build_hierarchy.
*   Liste der Warenempfaenger dedupliziert aus Fakturen
    DATA ship_to_keys TYPE STANDARD TABLE OF kunnr WITH EMPTY KEY.
    LOOP AT invoices ASSIGNING FIELD-SYMBOL(<inv>).
      INSERT <inv>-kunwe INTO TABLE ship_to_keys.
    ENDLOOP.
    SORT ship_to_keys.
    DELETE ADJACENT DUPLICATES FROM ship_to_keys.

    IF ship_to_keys IS INITIAL.
      RETURN.
    ENDIF.

*   ---------- Stufe 1: direkter Elternknoten in KNVH ----------
    SELECT kunnr, hkunnr
      FROM knvh
      FOR ALL ENTRIES IN @ship_to_keys
      WHERE kunnr =  @ship_to_keys-table_line
        AND hityp =  @p_hityp
        AND vkorg =  @p_vkorg
        AND vtweg =  @p_vtweg
        AND datab <= @sy-datum
        AND datbi >= @sy-datum
      INTO TABLE @DATA(level1).

*   ---------- Stufe 2: Elternknoten der Stufe-1-Knoten ----------
    DATA level1_parents TYPE STANDARD TABLE OF kunnr WITH EMPTY KEY.
    LOOP AT level1 ASSIGNING FIELD-SYMBOL(<l1>).
      INSERT <l1>-hkunnr INTO TABLE level1_parents.
    ENDLOOP.
    SORT level1_parents.
    DELETE ADJACENT DUPLICATES FROM level1_parents.

    DATA level2 LIKE level1.
    IF level1_parents IS NOT INITIAL.
      SELECT kunnr, hkunnr
        FROM knvh
        FOR ALL ENTRIES IN @level1_parents
        WHERE kunnr =  @level1_parents-table_line
          AND hityp =  @p_hityp
          AND vkorg =  @p_vkorg
          AND vtweg =  @p_vtweg
          AND datab <= @sy-datum
          AND datbi >= @sy-datum
        INTO TABLE @level2.
    ENDIF.

*   ---------- KNA1-Namen fuer alle beteiligten Kunden ----------
    DATA name_keys TYPE STANDARD TABLE OF kunnr WITH EMPTY KEY.
    name_keys = ship_to_keys.
    LOOP AT level1 ASSIGNING <l1>.
      INSERT <l1>-hkunnr INTO TABLE name_keys.
    ENDLOOP.
    LOOP AT level2 ASSIGNING FIELD-SYMBOL(<l2>).
      INSERT <l2>-hkunnr INTO TABLE name_keys.
    ENDLOOP.
    SORT name_keys.
    DELETE ADJACENT DUPLICATES FROM name_keys.

    SELECT kunnr, name1
      FROM kna1
      FOR ALL ENTRIES IN @name_keys
      WHERE kunnr = @name_keys-table_line
      INTO TABLE @DATA(customer_names).

    DATA names_lookup TYPE HASHED TABLE OF kna1 WITH UNIQUE KEY kunnr.
    LOOP AT customer_names ASSIGNING FIELD-SYMBOL(<n>).
      INSERT VALUE #( kunnr = <n>-kunnr name1 = <n>-name1 )
        INTO TABLE names_lookup.
    ENDLOOP.

*   ---------- Hierarchie-Tabelle aufbauen ----------
    LOOP AT ship_to_keys ASSIGNING FIELD-SYMBOL(<sh>).
      DATA(entry) = VALUE ty_hierarchy( kunnr = <sh> ).

      READ TABLE level1 INTO DATA(l1_row) WITH KEY kunnr = <sh>.
      IF sy-subrc = 0.
        entry-hier1_kunnr = l1_row-hkunnr.
        READ TABLE names_lookup ASSIGNING FIELD-SYMBOL(<nm1>)
          WITH TABLE KEY kunnr = l1_row-hkunnr.
        IF sy-subrc = 0.
          entry-hier1_name = <nm1>-name1.
        ENDIF.

        READ TABLE level2 INTO DATA(l2_row) WITH KEY kunnr = l1_row-hkunnr.
        IF sy-subrc = 0.
          entry-hier2_kunnr = l2_row-hkunnr.
          READ TABLE names_lookup ASSIGNING FIELD-SYMBOL(<nm2>)
            WITH TABLE KEY kunnr = l2_row-hkunnr.
          IF sy-subrc = 0.
            entry-hier2_name = <nm2>-name1.
          ENDIF.
        ENDIF.
      ENDIF.

      INSERT entry INTO TABLE hierarchy.
    ENDLOOP.
  ENDMETHOD.


  METHOD aggregate_data.
*   ---------- Materialkurztexte (Sprache des Anwenders) ----------
    DATA matnr_keys TYPE STANDARD TABLE OF matnr WITH EMPTY KEY.
    LOOP AT invoices ASSIGNING FIELD-SYMBOL(<inv>).
      INSERT <inv>-matnr INTO TABLE matnr_keys.
    ENDLOOP.
    SORT matnr_keys.
    DELETE ADJACENT DUPLICATES FROM matnr_keys.

    SELECT matnr, maktx
      FROM makt
      FOR ALL ENTRIES IN @matnr_keys
      WHERE matnr = @matnr_keys-table_line
        AND spras = @sy-langu
      INTO TABLE @DATA(material_texts).

    DATA material_lookup TYPE HASHED TABLE OF makt WITH UNIQUE KEY matnr.
    LOOP AT material_texts ASSIGNING FIELD-SYMBOL(<mt>).
      INSERT VALUE #( matnr = <mt>-matnr maktx = <mt>-maktx spras = sy-langu )
        INTO TABLE material_lookup.
    ENDLOOP.

*   ---------- Kundennamen der Warenempfaenger ----------
    DATA ship_to_keys TYPE STANDARD TABLE OF kunnr WITH EMPTY KEY.
    LOOP AT invoices ASSIGNING <inv>.
      INSERT <inv>-kunwe INTO TABLE ship_to_keys.
    ENDLOOP.
    SORT ship_to_keys.
    DELETE ADJACENT DUPLICATES FROM ship_to_keys.

    SELECT kunnr, name1
      FROM kna1
      FOR ALL ENTRIES IN @ship_to_keys
      WHERE kunnr = @ship_to_keys-table_line
      INTO TABLE @DATA(ship_to_kna1).

    DATA ship_to_names TYPE HASHED TABLE OF kna1 WITH UNIQUE KEY kunnr.
    LOOP AT ship_to_kna1 ASSIGNING FIELD-SYMBOL(<k>).
      INSERT VALUE #( kunnr = <k>-kunnr name1 = <k>-name1 )
        INTO TABLE ship_to_names.
    ENDLOOP.

*   ---------- Pivot-Aggregation (HASHED-Lookup fuer O(1)-Zugriff) ----------
    DATA work TYPE HASHED TABLE OF ty_result
              WITH UNIQUE KEY hier2_kunnr hier1_kunnr kunnr matnr.

    LOOP AT invoices ASSIGNING <inv>.
*     Monatsbucket bestimmen
      DATA(spmon_key) = CONV spmon( <inv>-fkdat+0(6) ).
      READ TABLE months ASSIGNING FIELD-SYMBOL(<bucket>)
        WITH TABLE KEY spmon = spmon_key.
      IF sy-subrc <> 0.
        CONTINUE.   "Datum liegt ausserhalb des 12-Monats-Windows
      ENDIF.

*     Hierarchie und Namen ermitteln
      DATA hier_entry TYPE ty_hierarchy.
      CLEAR hier_entry.
      READ TABLE hierarchy INTO hier_entry
        WITH TABLE KEY kunnr = <inv>-kunwe.
      hier_entry-kunnr = <inv>-kunwe.   "sicherstellen, auch ohne Hierarchieeintrag

      DATA(name_we) = VALUE name1( ).
      READ TABLE ship_to_names ASSIGNING FIELD-SYMBOL(<wename>)
        WITH TABLE KEY kunnr = <inv>-kunwe.
      IF sy-subrc = 0.
        name_we = <wename>-name1.
      ENDIF.

      DATA(maktx_text) = VALUE maktx( ).
      READ TABLE material_lookup ASSIGNING FIELD-SYMBOL(<mat>)
        WITH TABLE KEY matnr = <inv>-matnr.
      IF sy-subrc = 0.
        maktx_text = <mat>-maktx.
      ENDIF.

*     Ergebniszeile suchen oder neu anlegen
      READ TABLE work ASSIGNING FIELD-SYMBOL(<res>)
        WITH TABLE KEY hier2_kunnr = hier_entry-hier2_kunnr
                       hier1_kunnr = hier_entry-hier1_kunnr
                       kunnr       = <inv>-kunwe
                       matnr       = <inv>-matnr.
      IF sy-subrc <> 0.
        INSERT VALUE ty_result(
          hier2_kunnr = hier_entry-hier2_kunnr
          hier2_name  = hier_entry-hier2_name
          hier1_kunnr = hier_entry-hier1_kunnr
          hier1_name  = hier_entry-hier1_name
          kunnr       = <inv>-kunwe
          name1       = name_we
          matnr       = <inv>-matnr
          maktx       = maktx_text
          vrkme       = <inv>-vrkme
        ) INTO TABLE work ASSIGNING <res>.
      ENDIF.

*     Menge per dynamischem Komponentenzugriff in Pivot-Spalte addieren
      ASSIGN COMPONENT <bucket>-column_name OF STRUCTURE <res>
        TO FIELD-SYMBOL(<month_value>).
      IF <month_value> IS ASSIGNED.
        <month_value> = <month_value> + <inv>-fkimg.
      ENDIF.

      <res>-total = <res>-total + <inv>-fkimg.
    ENDLOOP.

*   Uebernahme in Standard-Ergebnistabelle fuer SALV
    LOOP AT work INTO DATA(result_line).
      APPEND result_line TO result.
    ENDLOOP.
    SORT result BY hier2_kunnr hier1_kunnr kunnr matnr.
  ENDMETHOD.


  METHOD display_alv.
    DATA alv TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = alv
          CHANGING  t_table      = result ).

*       Standard-ALV-Funktionen (Sortieren, Filtern, Exportieren)
        alv->get_functions( )->set_all( abap_true ).
        alv->get_display_settings( )->set_striped_pattern( abap_true ).
        alv->get_display_settings( )->set_list_header( 'Materialdispositions-Auswertung' ).

*       Spaltenbreiten automatisch anpassen
        DATA(columns) = alv->get_columns( ).
        columns->set_optimize( abap_true ).

*       Hierarchiestufen – Spaltenbezeichner (scrtext_s max. 10 Zeichen)
        DATA(col) = columns->get_column( 'HIER2_KUNNR' ).
        col->set_short_text( 'Hier2-Nr.' ).
        col->set_medium_text( 'Hierarchie 2' ).
        col->set_long_text( 'Hierarchie Stufe 2' ).

        col = columns->get_column( 'HIER2_NAME' ).
        col->set_short_text( 'Name H2' ).
        col->set_medium_text( 'Name Hier.2' ).
        col->set_long_text( 'Name Hierarchie 2' ).

        col = columns->get_column( 'HIER1_KUNNR' ).
        col->set_short_text( 'Hier1-Nr.' ).
        col->set_medium_text( 'Hierarchie 1' ).
        col->set_long_text( 'Hierarchie Stufe 1' ).

        col = columns->get_column( 'HIER1_NAME' ).
        col->set_short_text( 'Name H1' ).
        col->set_medium_text( 'Name Hier.1' ).
        col->set_long_text( 'Name Hierarchie 1' ).

        col = columns->get_column( 'KUNNR' ).
        col->set_short_text( 'Warenempf.' ).
        col->set_medium_text( 'Warenempfaenger' ).
        col->set_long_text( 'Warenempfaenger' ).

        col = columns->get_column( 'NAME1' ).
        col->set_short_text( 'Name' ).
        col->set_medium_text( 'Kundenname' ).
        col->set_long_text( 'Kundenname' ).

        col = columns->get_column( 'MATNR' ).
        col->set_short_text( 'Material' ).
        col->set_medium_text( 'Materialnummer' ).
        col->set_long_text( 'Materialnummer' ).

        col = columns->get_column( 'MAKTX' ).
        col->set_short_text( 'Mat.Text' ).
        col->set_medium_text( 'Materialtext' ).
        col->set_long_text( 'Materialkurztext' ).

        col = columns->get_column( 'VRKME' ).
        col->set_short_text( 'VkME' ).
        col->set_medium_text( 'Verkaufs-ME' ).
        col->set_long_text( 'Verkaufsmengeneinheit' ).

*       Monatsspalten M01..M12 dynamisch beschriften
*       Spalten ohne Bucket-Eintrag (Zeitraum < 12 Monate) ausblenden
        DO c_mat_dispo-months_window TIMES.
          DATA(col_name) = CONV lvc_fname(
            |M{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }| ).
          DATA(month_col) = columns->get_column( col_name ).

          READ TABLE months ASSIGNING FIELD-SYMBOL(<m>)
            WITH KEY column_name = col_name.
          IF sy-subrc = 0.
            month_col->set_short_text( CONV scrtext_s( <m>-header_text ) ).
            month_col->set_medium_text( CONV scrtext_m( <m>-header_text ) ).
            month_col->set_long_text( CONV scrtext_l( <m>-header_text ) ).
          ELSE.
            month_col->set_visible( abap_false ).
          ENDIF.
        ENDDO.

        col = columns->get_column( 'TOTAL' ).
        col->set_short_text( 'Gesamt' ).
        col->set_medium_text( 'Gesamtsumme' ).
        col->set_long_text( 'Gesamtsumme Zeitraum' ).

*       Sortierung mit Subtotalen je Hierarchiestufe / Kunde
        DATA(sorts) = alv->get_sorts( ).
        sorts->add_sort( columnname = 'HIER2_KUNNR' subtotal = abap_true ).
        sorts->add_sort( columnname = 'HIER1_KUNNR' subtotal = abap_true ).
        sorts->add_sort( columnname = 'KUNNR'       subtotal = abap_true ).
        sorts->add_sort( columnname = 'MATNR' ).

*       Aggregationen: Summe fuer alle Monats- und Gesamtspalten
        DATA(aggs) = alv->get_aggregations( ).
        DO c_mat_dispo-months_window TIMES.
          col_name = |M{ sy-index WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
          aggs->add_aggregation( columnname  = col_name
                                 aggregation = if_salv_c_aggregation=>total ).
        ENDDO.
        aggs->add_aggregation( columnname  = 'TOTAL'
                               aggregation = if_salv_c_aggregation=>total ).

        alv->display( ).

      CATCH cx_salv_msg
            cx_salv_not_found
            cx_salv_existing
            cx_salv_data_error INTO DATA(salv_error).
        MESSAGE salv_error TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
