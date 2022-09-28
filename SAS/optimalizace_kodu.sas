
/* uk�zka zkr�cen� b�hu 2 ��st� k�du z 15 minut na 8 vte�in a z 32 minut na 11 vte�in*/


/* info: pro testov�n� byla vytvo�ena tabulka temp.auta (v produk�n�m k�du je to tmp.auta)
   a n�sledn� z n� temp.auta_SMLOUVA_VZT (v produk�n�m k�du je to tmp.SMLOUVA_VZT) 
   a pro porovn�n� temp.auta_mojetabulka (joinov�n� v teradat�)

   stejn�m zp�sobem vznikla temp.auta_02 (v produk�n�m k�du je to tmp.auta_02) a 
   pro porovn�n� temp.auta_mojetabulka2 (joinov�n� v teradat�) 
*/


/* Tento k�d b�� s rsubmitem p�es 15 minut 
(nespou�t�j ho, v�sledn� tabulka je na temp.auta_SMLOUVA_VZT) */

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


/* Je pot�eba ho zrychlit n�sledovn�:

1.	namapuje se do SAS schema CRMBOX
2.	pro sichr se zkontroluje/sma�e importn� tabulka v CRMBOXu
3.	z prost�ed� SAS se napln� importn� tabulka v CRMBOX
4.	z prost�ed� SAS se na stran� TD pust� SQL, kter� projoinuje importn� tabulku z CRMBOX
    s pot�ebn�mi daty L1, L2 a vyrob� se v�stupn� tabulka v CRMBOX. Pou�ije se pro to spou�t�n� SAS PASS-THROUGH
5.	z prost�ed� SAS se do TMP na�te v�stupn� tabulka z TD
6.	sma�e se v TD vstupn�, v�stupn�, odmapuje se CRMBOX

*/


/* 1.	namapuje se do SAS schema CRMBOX */
rsubmit;
%meta_getdomainlogin(domain=TDAUTH);
libname CRMBOX teradata user="&userid" password="&password" server=SERVER_ID schema=crmbox;
endrsubmit;
libname CRMBOX slibref=CRMBOX server=_srv;

/* 2.	pro sichr se zkontroluje/sma�e importn� tabulka v CRMBOXu */
rsubmit;
proc sql;
drop table crmbox.auta_temp; /* kdy� tabulka neexistuje, neskon�� to errorem */
quit;

/* 3.	z prost�ed� SAS se napln� importn� tabulka v CRMBOX */
rsubmit;
data crmbox.auta_temp 
            (fastload=yes tpt=yes
             dbcreate_table_opts='primary index(cpoj)'
            );
set temp.auta;
run;
   
/* 4.	z prost�ed� SAS se na stran� TD pust� SQL, kter� projoinuje importn� tabulku z CRMBOX
        s pot�ebn�mi daty L1, L2 a vyrob� se v�stupn� tabulka v CRMBOX. Pou�ije se pro to spou�t�n� SAS PASS-THROUGH */
/* v�sledn� tabulka je na temp.mojetabulka */
/* m�sto 15 minut b�� 8 vte�in */

rsubmit;
PROC SQL;       

	  CONNECT TO TERADATA as MYCON (USER=&userid. PASSWORD="&password." SERVER=SERVER_ID MODE=TERADATA);  
      create table tmp.mojetabulka /* 5.	z prost�ed� SAS se do TMP na�te v�stupn� tabulka z TD */
      as Select * From Connection to MYCON ( 
          SELECT a.*, 
				SMLO.SMLO_PK,
   				POD_SMLO_PK AS SMLO_POJI_PK,
			    SMLOVL.SMLO_CISLO_SML,
			    MIN(SMLOVL.dw_from) AS dw_from,
			    MAX(SMLOVL.dw_to) AS dw_to
          FROM  crmbox.auta_temp a
          JOIN  PROD_V1_A_01.SMLOVL_SMLOUVA AS SMLOVL
		  	on a.cpoj = to_number(SMLOVL.SMLO_CISLO_SML) /* TD asi nezn� BIGINT, cast nefungovalo */
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

/* k�d, kter� trv� s rsubmitem v�ce ne� 32 minut 
(nespou�t�j ho, v�sledn� tabulka je na temp.auta_02) */

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

/* 2.	pro sichr se zkontroluje/sma�e importn� tabulka v CRMBOXu */
rsubmit;
proc sql;
drop table crmbox.auta_mojetabulka_temp; /* kdy� tabulka neexistuje, neskon�� to errorem */
quit;

/* 3.	z prost�ed� SAS se napln� importn� tabulka v CRMBOX */
rsubmit;
data temp.auta_mojetabulka_format (rename = (new_var=dw_from new_var2=dw_to));
set temp.auta_mojetabulka;
new_var = input(dw_from, ddmmyyp10.); /* form�tov�n�, aby byl v�stup toto�n� se star�m k�dem */
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
   
/* 4.	z prost�ed� SAS se na stran� TD pust� SQL, kter� projoinuje importn� tabulku z CRMBOX
        s pot�ebn�mi daty L1, L2 a vyrob� se v�stupn� tabulka v CRMBOX. Pou�ije se pro to spou�t�n� SAS PASS-THROUGH */
/* v�sledn� tabulka je na temp.mojetabulka2 */
/* m�sto 32 minut b�� 11 vte�in */
rsubmit;
PROC SQL;       

	  CONNECT TO TERADATA as MYCON (USER=&userid. PASSWORD="&password." SERVER=SERVER_ID MODE=TERADATA);  
      create table tmp.mojetabulka2 /* 5.	z prost�ed� SAS se do TMP na�te v�stupn� tabulka z TD */
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
