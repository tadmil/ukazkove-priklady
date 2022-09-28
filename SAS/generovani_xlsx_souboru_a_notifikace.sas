
/* generování týdenního reportu podle byznysového požadavku */


/* pomocná tabulka */

data tmp.vsechny_tydny;
	do tyden=1 to 52;
	pocet = 0;
		output;
	end;
run;


/* data z CP */

data tmp.da_cp_week;
set l0.Dacp_datbl_datdocuments_f (where = (year(datepart(created)) = year("&sysdate9"d) and 
										  (name = "Informace o výši odbytného/odkupného"))
								  keep = name created);
week_no = week(datepart(created));
run;


proc sql;
create table tmp.da_cp_final as
	select week_no as tyden, count(week_no) as pocet, "CP" as DA
	from tmp.da_cp_week
	group by week_no;
quit;


data tmp.da_cp_final2;
merge tmp.vsechny_tydny tmp.da_cp_final;
by tyden;
if pocet = 0 then pocet = .;
run;


PROC TRANSPOSE DATA=tmp.da_cp_final2 OUT=tmp.da_cp_final_transpose;
RUN;


/* data z GLI */

data tmp.da_gli_week;
set l0.Dagli_datdocuments_f (where = (year(datepart(created)) = year("&sysdate9"d) and 
								     (name = "Sdìlení stavu pojistné smlouvy"))
							 keep = name created);
week_no = week(datepart(created));
run;


proc sql;
create table tmp.da_gli_final as
	select week_no as tyden, count(week_no) as pocet, "GLI" as DA
	from tmp.da_gli_week
	group by week_no;
quit;


data tmp.da_gli_final2;
merge tmp.vsechny_tydny tmp.da_gli_final;
by tyden;
if pocet = 0 then pocet = .;
run;


PROC TRANSPOSE DATA=tmp.da_gli_final2 OUT=tmp.da_gli_final_transpose;
RUN;


/* export do excelu a smazání záložního (*.bak) souboru */

proc export data=tmp.da_cp_final_transpose
    outfile="\\czcsma\ma_export\Data_KRZ\Preventivni_retence\Odbytne_ZP_TAS\Odbytne_ZP_TAS_2022.xlsx"
    dbms=xlsx
    replace;
	putnames=no;
    sheet="CP";
run;

proc export data=tmp.da_gli_final_transpose
    outfile="\\czcsma\ma_export\Data_KRZ\Preventivni_retence\Odbytne_ZP_TAS\Odbytne_ZP_TAS_2022.xlsx"
    dbms=xlsx
    replace;
	putnames=no;
    sheet="GLI";
run;

%macro xlsx_bak_delete(file) / des='Delete backup spreadsheets';
option mprint notes;
data _null_;
fname = 'todelete';
rc = filename(fname, "&file..xlsx.bak");
rc = fdelete(fname);
rc = filename(fname);
run;
%mend xlsx_bak_delete;
%xlsx_bak_delete(file=\\czcsma\ma_export\Data_KRZ\Preventivni_retence\Odbytne_ZP_TAS\Odbytne_ZP_TAS_2022)


/* notifikace */

data _null_;
file sendit email
from="tadeas.prijmeni@generaliceska.cz"
to=("jan.prijmeni@generaliceska.cz" "ales.prijmeni@generaliceska.cz")
cc=("tadeas.prijmeni@generaliceska.cz")
subject="Odbytne_ZP_TAS";
put "Ahoj Honzo a Aleši,";
put;
put"byl vygenerován soubor \\czcsma\ma_export\Data_KRZ\Preventivni_retence\Odbytne_ZP_TAS\Odbytne_ZP_TAS_2022.xlsx";
put;
put "Robot";
run;

