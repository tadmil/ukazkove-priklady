
/* ukázka zkrácení bìhu 2 èástí kódu z 15 minut na 8 vteøin a z 32 minut na 11 vteøin*/


/* info: pro testování byla vytvoøena tabulka temp.auta (v produkèním kódu je to tmp.auta)
   a následnì z ní temp.auta_SMLOUVA_VZT (v produkèním kódu je to tmp.SMLOUVA_VZT) 
   a pro porovnání temp.auta_mojetabulka (joinování v teradatì)

   stejným zpùsobem vznikla temp.auta_02 (v produkèním kódu je to tmp.auta_02) a 
   pro porovnání temp.auta_mojetabulka2 (joinování v teradatì) 
*/


/* Tento kód bìží s rsubmitem pøes 15 minut 
(nespouštìj ho, výsledná tabulka je na temp.auta_SMLOUVA_VZT) */

%meta_getdomainlogin(domain=TDAUTH);
libname DWH_CP teradata user="&userid" password="&password" server=SERVER_ID schema=SCHEMA_01;

proc sql;
CREATE TABLE tmp.SMLOUVA_VZT AS
SELECT
	a.*,
   SMLO.SMLO_PK,
   POD_SMLO_PK AS SMLO_POJI_PK,
   SMLOVL.SMLO_CISLO_SML,
   MIN(SMLOVL.dw_from) AS dw_from,
   MAX(SMLOVL.dw_to) AS dw_to
FROM temp.auta a 
INNER JOIN DWH_CP.SMLOVL_SMLOUVA AS SMLOVL
ON a.cpoj = input(SMLOVL.SMLO_CISLO_SML,10.)
INNER JOIN DWH_CP.SMLO_SMLOUVA AS SMLO
   ON SMLO.SMLO_PK = SMLOVL.SMLO_PK
   AND SMLO.SRC_SYS_ID = 22
  AND today() BETWEEN SMLOVL.dw_from AND SMLOVL.dw_to
INNER JOIN
 (SELECT VZ.NAD_SMLO_PK, VZ.POD_SMLO_PK 
   FROM DWH_CP.VZTSML_VZTAH_SML AS VZ
   INNER JOIN DWH_CP.TPVZSMVL_TYP_VZT_SML AS TPVZSMVL
      ON TPVZSMVL.TPVZSM_PK = VZ.TPVZSM_PK
      AND TPVZSMVL.TPVZSM_KOD= 'SMPOJ' 
      AND today() BETWEEN VZ.dw_from AND VZ.dw_to
   )  AS VZTSML
ON VZTSML.NAD_SMLO_PK = SMLO.SMLO_PK
GROUP BY
   1,2,3,4,5
;
QUIT;


/* Je potøeba ho zrychlit následovnì:

1.	namapuje se do SAS schema CRMBOX
2.	pro sichr se zkontroluje/smaže importní tabulka v CRMBOXu
3.	z prostøedí SAS se naplní importní tabulka v CRMBOX
4.	z prostøedí SAS se na stranì TD pustí SQL, které projoinuje importní tabulku z CRMBOX
    s potøebnými daty L1, L2 a vyrobí se výstupní tabulka v CRMBOX. Použije se pro to spouštìní SAS PASS-THROUGH
5.	z prostøedí SAS se do TMP naète výstupní tabulka z TD
6.	smaže se v TD vstupní, výstupní, odmapuje se CRMBOX

*/


/* 1.	namapuje se do SAS schema CRMBOX */
rsubmit;
%meta_getdomainlogin(domain=TDAUTH);
libname CRMBOX teradata user="&userid" password="&password" server=SERVER_ID schema=crmbox;
endrsubmit;
libname CRMBOX slibref=CRMBOX server=_srv;

/* 2.	pro sichr se zkontroluje/smaže importní tabulka v CRMBOXu */
rsubmit;
proc sql;
drop table crmbox.auta_temp; /* když tabulka neexistuje, neskonèí to errorem */
quit;

/* 3.	z prostøedí SAS se naplní importní tabulka v CRMBOX */
rsubmit;
data crmbox.auta_temp 
            (fastload=yes tpt=yes
             dbcreate_table_opts='primary index(cpoj)'
            );
set temp.auta;
run;
   
/* 4.	z prostøedí SAS se na stranì TD pustí SQL, které projoinuje importní tabulku z CRMBOX
        s potøebnými daty L1, L2 a vyrobí se výstupní tabulka v CRMBOX. Použije se pro to spouštìní SAS PASS-THROUGH */
/* výsledná tabulka je na temp.mojetabulka */
/* místo 15 minut bìží 8 vteøin */

rsubmit;
PROC SQL;       

	  CONNECT TO TERADATA as MYCON (USER=&userid. PASSWORD="&password." SERVER=SERVER_ID MODE=TERADATA);  
      create table tmp.mojetabulka /* 5.	z prostøedí SAS se do TMP naète výstupní tabulka z TD */
      as Select * From Connection to MYCON ( 
          SELECT a.*, 
				SMLO.SMLO_PK,
   				POD_SMLO_PK AS SMLO_POJI_PK,
			    SMLOVL.SMLO_CISLO_SML,
			    MIN(SMLOVL.dw_from) AS dw_from,
			    MAX(SMLOVL.dw_to) AS dw_to
          FROM  crmbox.auta_temp a
          JOIN  PROD_V1_A_01.SMLOVL_SMLOUVA AS SMLOVL
		  	on a.cpoj = to_number(SMLOVL.SMLO_CISLO_SML) /* TD asi nezná BIGINT, cast nefungovalo */
		  JOIN  PROD_V1_A_01.SMLO_SMLOUVA AS SMLO
		    on SMLO.SMLO_PK = SMLOVL.SMLO_PK AND SMLO.SRC_SYS_ID = 22 AND CURRENT_DATE BETWEEN SMLOVL.dw_from AND SMLOVL.dw_to
		  JOIN
 			    (SELECT VZ.NAD_SMLO_PK, VZ.POD_SMLO_PK 
   				FROM PROD_V1_A_01.VZTSML_VZTAH_SML AS VZ
  				JOIN PROD_V1_A_01.TPVZSMVL_TYP_VZT_SML AS TPVZSMVL
   				   ON TPVZSMVL.TPVZSM_PK = VZ.TPVZSM_PK AND TPVZSMVL.TPVZSM_KOD= 'SMPOJ' AND CURRENT_DATE BETWEEN VZ.dw_from AND VZ.dw_to
				) AS VZTSML
			ON VZTSML.NAD_SMLO_PK = SMLO.SMLO_PK
		  GROUP BY 1,2,3,4,5	
		);
	  DISCONNECT FROM MYCON;
QUIT;


/*********************************************************************************************
*********************************************************************************************/

/* kód, který trvá s rsubmitem více než 32 minut 
(nespouštìj ho, výsledná tabulka je na temp.auta_02) */

proc sql; 
create table tmp.auta_02 AS
SELECT 
   SML_VZT.CPOJ,
   SML_VZT.IDSYS,
   SML_VZT.SMLO_PK,
   SML_VZT.SMLO_CISLO_SML,
   SML_VZT.dw_from,
   SML_VZT.dw_to,
   VOZI.VOZI_SPZ_VOZI,
   VOZI.VOZI_VIN_VOZI,
   VOZI.OBJEKT_PK
FROM TEMP.auta_SMLOUVA_VZT SML_VZT
INNER JOIN DWH_CP.POJRIZVL_POJ_RIZIKO POJRIZVL
   ON POJRIZVL.SMLO_PK = SML_VZT.SMLO_POJI_PK
   AND today() BETWEEN POJRIZVL.dw_from AND POJRIZVL.dw_to

INNER JOIN DWH_CP.PRIZOB_POJ_RIZIKO_OBJEKT PRIZOB
   ON PRIZOB.POJRIZ_PK = POJRIZVL.POJRIZ_PK
   AND today() BETWEEN PRIZOB.dw_from AND PRIZOB.dw_to

INNER JOIN DWH_CP.POJOBVL_POJ_OBJEKT POJOBVL
   ON POJOBVL.POJOB_PK = PRIZOB.POJOB_PK
   AND today() BETWEEN POJOBVL.dw_from AND POJOBVL.dw_to

INNER JOIN DWH_CP.VOZI_VOZIDLO VOZI
   ON VOZI.OBJEKT_PK = POJOBVL.OBJEKT_PK
GROUP BY
   1,2,3,4,5,6,7,8,9
;
quit;


/* 1.	namapuje se do SAS schema CRMBOX */
rsubmit;
%meta_getdomainlogin(domain=TDAUTH);
libname CRMBOX teradata user="&userid" password="&password" server=SERVER_ID schema=crmbox;
endrsubmit;
libname CRMBOX slibref=CRMBOX server=_srv;

/* 2.	pro sichr se zkontroluje/smaže importní tabulka v CRMBOXu */
rsubmit;
proc sql;
drop table crmbox.auta_mojetabulka_temp; /* když tabulka neexistuje, neskonèí to errorem */
quit;

/* 3.	z prostøedí SAS se naplní importní tabulka v CRMBOX */
rsubmit;
data temp.auta_mojetabulka_format (rename = (new_var=dw_from new_var2=dw_to));
set temp.auta_mojetabulka;
new_var = input(dw_from, ddmmyyp10.); /* formátování, aby byl výstup totožný se starým kódem */
new_var2 = input(dw_to, ddmmyyp10.);
drop dw_from dw_to;
run;

rsubmit;
data crmbox.auta_mojetabulka_temp 
            (fastload=yes tpt=yes
             dbcreate_table_opts='primary index(SMLO_POJI_PK)'
            );
set temp.auta_mojetabulka_format;
run;
   
/* 4.	z prostøedí SAS se na stranì TD pustí SQL, které projoinuje importní tabulku z CRMBOX
        s potøebnými daty L1, L2 a vyrobí se výstupní tabulka v CRMBOX. Použije se pro to spouštìní SAS PASS-THROUGH */
/* výsledná tabulka je na temp.mojetabulka2 */
/* místo 32 minut bìží 11 vteøin */
rsubmit;
PROC SQL;       

	  CONNECT TO TERADATA as MYCON (USER=&userid. PASSWORD="&password." SERVER=SERVER_ID MODE=TERADATA);  
      create table tmp.mojetabulka2 /* 5.	z prostøedí SAS se do TMP naète výstupní tabulka z TD */
      as Select * From Connection to MYCON ( 
          SELECT 
			   SML_VZT.CPOJ,
			   SML_VZT.IDSYS,
			   SML_VZT.SMLO_PK,
			   SML_VZT.SMLO_CISLO_SML,
			   SML_VZT.dw_from,
			   SML_VZT.dw_to,
			   VOZI.VOZI_SPZ_VOZI,
			   VOZI.VOZI_VIN_VOZI,
			   VOZI.OBJEKT_PK
			FROM crmbox.auta_mojetabulka_temp SML_VZT
			 JOIN PROD_V1_A_01.POJRIZVL_POJ_RIZIKO POJRIZVL
			   ON POJRIZVL.SMLO_PK = SML_VZT.SMLO_POJI_PK
			   AND CURRENT_DATE BETWEEN POJRIZVL.dw_from AND POJRIZVL.dw_to

			 JOIN PROD_V1_A_01.PRIZOB_POJ_RIZIKO_OBJEKT PRIZOB
			   ON PRIZOB.POJRIZ_PK = POJRIZVL.POJRIZ_PK
			   AND CURRENT_DATE BETWEEN PRIZOB.dw_from AND PRIZOB.dw_to

			 JOIN PROD_V1_A_01.POJOBVL_POJ_OBJEKT POJOBVL
			   ON POJOBVL.POJOB_PK = PRIZOB.POJOB_PK
			   AND CURRENT_DATE BETWEEN POJOBVL.dw_from AND POJOBVL.dw_to

			 JOIN PROD_V1_A_01.VOZI_VOZIDLO VOZI
			   ON VOZI.OBJEKT_PK = POJOBVL.OBJEKT_PK
			ORDER BY 1,2,3,4,5,6,7,8,9	
		);
	  DISCONNECT FROM MYCON;
QUIT;
