/*Data preparation*/
tempfile   mother                                                               /*Temp files should be declared before used. This is a processing file to extract data from different instuments: household female pregnancy.*/
local      pATh      = "/Users/lshjr3/Documents/SARMAAN"                        /*The path to the folder containing the KoboToolbox outputs.*/

local      M         = "household female pregnancy"                             /*KoboToolbox outputs have 5 sheets and these three are used for U5M estimation.*/
foreach sheet of local M {                                                      /*Repeats the same reading commands for each sheet.*/
	tempfile  `sheet'                                                           /*Temp files should be declared before used.*/
	clear                                                                       /*Clears all variables and observations.*/
	generate   cluster = ""                                                     /*Clusters represent batches of data collection; for example, Kano corresponds to clusters 1 and 2, while Kaduna corresponds to cluster 3, and so on.*/
	save     ``sheet'', replace                                                 /*Saves the temporary file for later use.*/
	forvalues cluster = 1(1)5 {                                                 /*Repeats the same commands for each cluster.*/
		quiet import excel "`pATh'/M_`cluster'.xlsx", sheet("`sheet'") firstrow case(lower) allstring clear /*Reads KoboToolbox outputs (excel files).*/
		generate   cluster = "C-`cluster'"                                      /*Generates an identifier for each cluster.*/
		append     using ``sheet''                                              /*Compiles data from different clusters but the same sheet.*/
		save     ``sheet'', replace                                             /*Saves the data of each sheet.*/
		}                                                                       /*Closes the loop.*/
	}

use       `household', clear                                                    /*Accesses the temporary file that contains household characteristics.*/
rename     starttime            sTArt                                           /*Renames time variables.*/
rename     endtime              eNd
rename     _submission_time     sUBmiSSion
replace    sUBmiSSion         = sUBmiSSion + ".000+00:00"                       /*Adds these extra characters to unify the format of date and times.*/

local      lISt               = "sTArt eNd sUBmiSSion"                          /*Creates a list consisting of the three date-and-time varibales.*/
foreach var of local lISt {                                                     /*Repeats the same commands for each date-and-time variable.*/
	rename    `var' temp                                                        /*Removes the name of the variable.*/
	generate   adj                = clock("2020-01-01" + " " + substr(temp,-5,2) + ":00:00","YMD hms") - clock("2020-01-01" + " " + "00:00:00","YMD hms") if substr(temp,-1,1) != "Z" /*Identifies if an observation requires format adjustments and the magnitude of the adjustment.*/
	recode     adj             (. = 0)
	replace    adj                = - adj             if substr(temp,-6,1) == "-" /*Identifies the direction of the adjustment.*/
	
	generate   double `var'       = clock(substr(temp,1,10) + " " + substr(temp,12,8),"YMD hms") /*Generates an ammended data-and-time variable.*/
	format     %tcMon_dd,_CCYY_hh:MM:SS_AM `var'                                /*Applies the proper format to the variable.*/
	replace   `var'               = `var' - adj                                 /*Adjust the variable, if necessary.*/
	drop       temp adj                                                         /*Eliminates temp variables used for the adjustment.*/
	}
order     `lISt'                                                                /*Moves the date-and-time variables to the front.*/

rename     _index               hOUseHOLd                                       /*Renames the generic index variable to accurately describe the database being used.*/
rename     states               state                                           /*Identifies the state.*/
rename     lgas                 localG                                          /*Identifies the local government area.*/
capture    drop                 ward
rename     wards                ward                                            /*Identifies the ward.*/
generate   UR                 = 1                     if settlement_type == "urban" /*Identifies the urban/rural place of residence.*/
replace    UR                 = 2                     if settlement_type == "rural"

generate   HH_size            = hh_females                                      /*SARMAAN project quntifies the total number of women 10-55, rather than the total number of household members*/
destring   HH_size, replace                                                     /*Transforms strings into numeric values, as all variables are strings by default.*/
generate   household          = 1                     if HH_size  < 5           /*Classifies household sizes into broad categories.*/
replace    household          = 2                     if HH_size  < 9  & household == . /*Continuation.*/
recode     household       (. = 3)                                              

generate   Electricity        = 1                                               /*Determines whether a household has access to electricity.*/
replace    Electricity        = 2                     if electricity == "yes"

generate   Water              = 1                                               /*Identifies safe sources of water.*/
replace    Water              = 2                     if water_source == "piped_into_dwelling"
replace    Water              = 2                     if water_source == "rainwater"
replace    Water              = 2                     if water_source == "public_tap"
replace    Water              = 2                     if water_source == "mairuwa_garuwa"
replace    Water              = 2                     if water_source == "covered_well"
replace    Water              = 2                     if water_source == "spring"
replace    Water              = 2                     if water_source == "borehole"
replace    Water              = 2                     if water_source == "others"  & substr(other_water_source,1,4) != "Tank" & substr(other_water_source,-4,.) != "tank"

/*C-4 is missing the enum_id*/
capture replace    enum_id    = substr("00000" + enum_id,-4,.) if enum_id != "" /*Identifies the code of the enumerator.*/
local      GPS                = "cluster sTArt eNd sUBmiSSion deviceid _id enum_id latitude longitude hOUseHOLd household HH_size Water Electricity state localG ward UR _validation" /*Makes a list of the variables to be retained.*/
keep      `GPS'                                                                 /*Keeps the previously listed variables.*/

destring   latitude longitude, replace                                          /*Transforms strings into numeric values, as all variables are strings by default.*/
generate   wrongGPS           = 0                                               /*Assumes that all GPS coordinates are accurate.*/
replace    wrongGPS           = 1                     if latitud <= 4           | latitude  > 14 /*Identifies coordinates that fall outside the valid range.*/ 
replace    wrongGPS           = 1                     if longitu <= 2           | longitud  > 15 /*Idem.*/
bysort     cluster: egen float LAT   = median(latitude)  if wrongGPS == 0       /*Captures median latitude for each cluster.*/
bysort     cluster: egen float LONG  = median(longitude) if wrongGPS == 0       /*Captures median longitude for each cluster.*/
generate   Euclidean          = sqrt((latitude - LAT)^2 + (longitude - LONG)^2) /*Calculates planar distances to the median points.*/
drop       LAT LONG
save      `mother', replace                                                     /*Saves the processed household data.*/


use       `female', clear                                                       /*Accesses the temporary file that contains the characteristics of women in reproductive ages.*/
destring   age, replace                                                         /*Transforms strings into numeric values.*/
egen       GO                 = cut(age), at(10,15,20,25,30,35,40,45,50,55,60) icodes /*Classifies ages into broad categories.*/
replace    GO                 = min(GO,8) + 1                                   /*Truncates at 50, and starts at 1.*/

generate   level              = ""
local      lISt               = "hh_women_education_level hh_education_level"
foreach var of local lISt {
	capture replace    level       = `var'   if level       == ""  & `var' != ""
	capture drop      `var'
	}

generate   duration           = ""
local      lISt               = "duration_level_pri_001 duration_level_sec_001 duration_level_001"
foreach var of local lISt {
	capture replace    duration    = `var'   if duration    == ""  & `var' != ""
	capture drop      `var'
	}

destring   duration, replace                                                    /*Transforms strings into numeric values.*/
recode     duration       (98 = .) (99 = .)                                     /*Unknown/unreported number of years of schooling.*/
generate   Education          = 1                                               /*Classifies education into broad categories.*/
replace    Education          = 2                     if (level  == "primary"   & duration >= 6) | level  == "secondary"
replace    Education          = 3                     if (level  == "secondary" & duration >= 6) | level  == "higher_e"

generate   dob                = ""
local      lISt               = "mother_dob birth_year"
foreach var of local lISt {
	capture replace    dob         = `var'   if dob         == ""  & `var' != ""
	capture drop      `var'
	}

generate   year               = substr(dob,1,4)                                 /*Generates a variable with the year of birth.*/
generate   month              = substr(dob,6,2)                                 /*Generates a variable with the month of birth.*/
generate   day                = substr(dob,9,2)                                 /*Generates a variable with the day of birth.*/
destring   year month day, replace                                              /*Transforms strings into numeric values.*/                   

generate   DOB_min            = mdy(month,day,year)                             /*Generates a variable with full DOB.*/
replace    DOB_min            = mdy(1,1,year)                  if DOB_min == . & (month > 12 | month < 1) /*Assumes January 1 if incorrect month.*/
replace    DOB_min            = mdy(month,1,year)              if DOB_min == . & (day   > 31 | day   < 1) /*Assumes 1 of the month if incorrect day.*/
replace    DOB_min            = mdy(mod(month,12) + 1,1,year + floor(month/12)) - 1 if DOB_min == . /*Fixes incorrect last day of the month (e.g., incorrect 31).*/
generate   DOB_max            = mdy(month,day,year)                             /*Generates a variable with full DOB.*/
replace    DOB_max            = mdy(1,1,year + 1)              if DOB_max == . & (month > 12 | month < 1) /*Assumes January 1 of next calendar year if incorrect month.*/
replace    DOB_max            = mdy(mod(month,12) + 1,1,year + floor(month/12)) if DOB_max == . & (day   > 31 | day   < 1) /*Assumes 1 of the next month if incorrect day.*/
replace    DOB_max            = mdy(mod(month,12) + 1,1,year + floor(month/12)) - 1 if DOB_max == . /*Fixes incorrect last day of the month (e.g., incorrect 31).*/
replace    DOB_max            = mdy(1,1,year + 1)              if month == 1   & day == 1 /*Assumes January 1 of next calendar year if imputed at January 1.*/
format     %tdDD/NN/CCYY DOB*                                                   /*Applies the proper format to the variable.*/ 
drop       year month day                                                       /*Drops temp variables.*/

local      SPH                = "cluster DOB* age GO mother_id *_son* *_daughter* c_count p_count _parent_index _index Education _submission__id _submission__uuid" /*Makes a list of the variables to be retained.*/
keep      `SPH'                                                                 /*Keeps the previously listed variables.*/
rename     _parent_index hOUseHOLd                                              /*Women are linked to each household using the variable _parent_index.*/
destring   *_son* *_daughter* c_count p_count, replace                          /*Transforms strings into numeric values: summary birth histories.*/
recode     *_son* *_daughter* c_count p_count (. = 0)                           
generate   sons               = living_sons     + living_sons1     + dead_sons 
generate   daughters          = living_daughter + living_daughter1 + dead_daughter
generate   sonsD              = dead_sons
generate   daughtersD         = dead_daughter
generate   Born               = sons + daughters
generate   Dead               = sonsD + daughtersD
generate   Away               = Born - Dead
rename     c_count b_count
drop       *_son* *_daughter*
merge m:1  cluster hOUseHOLd using `mother', keep(master match) nogenerate
rename     _index moTHer

sort       cluster hOUseHOLd moTHer
bysort     cluster hOUseHOLd: generate   h = _n
bysort     cluster hOUseHOLd: generate   H = _N
save      `mother', replace


use       `pregnancy', clear
generate   sex                = ""
local      lISt               = "gender gender1 q117_child_sex q117_child_sex_dup"
foreach var of local lISt {
	capture replace    sex         = `var'   if sex         == ""  & `var' != ""
	capture drop      `var'
	}

generate   G                  = ""
local      lISt               = "q121_pregnancy_duration_type q121_pregnancy_miscarriage_durat preg_report"
foreach var of local lISt {
	capture replace    G           = `var'   if G           == ""  & `var' != ""
	capture drop      `var'
	}

generate   gestation          = ""
local      lISt               = "q122_pregnancy_duration_weeks q122_pregnancy_duration_months q122_pregnancy_miscarriage_durat preg_length preg_length2"
foreach var of local lISt {
	capture replace    gestation   = `var'   if gestation   == ""  & `var' != ""
	capture drop      `var'
	}
destring   gestation, replace
replace    gestation          = floor(gestation/12*52) if G == "months"	
drop       G
  
generate   OuTComE            = ""
local      lISt               = "birth_form q114_pregnancy_outcome"
foreach var of local lISt {
	capture replace    OuTComE     = `var'   if OuTComE     == ""  & `var' != ""
	capture drop      `var'
	}
  
generate   BMC                = ""
local      lISt               = "birth_status q115_live_signs_at_birth"
foreach var of local lISt {
	capture replace    BMC         = `var'   if BMC         == ""  & `var' != ""
	capture drop      `var'
	}
  
generate   survival           = ""
local      lISt               = "q124_child_alive child_alive"
foreach var of local lISt {
	capture replace    survival    = `var'   if survival    == ""  & `var' != "" & `var' != "0"
	capture drop      `var'
	}
replace    survival           = "dead" 	              if survival     == "no"
replace    survival           = "alive"               if survival     == "yes"

generate   dead               = ""
local      lISt               = "q126_age_at_death_exact dead_category"
foreach var of local lISt {
	capture replace    dead        = `var'   if dead        == ""  & `var' != ""
	capture drop      `var'
	} 

generate   dead_1y            = ""
local      lISt               = "first_birthday q128_had_first_birthday"
foreach var of local lISt {
	capture replace    dead_1y     = `var'   if dead_1y     == ""  & `var' != ""
	capture drop      `var'
	} 
	
generate   D_days             = ""
local      lISt               = "q127a_age_at_death_days_1 q127a_age_at_death_days_2 q129a_age_at_death_days_dup age_days"
foreach var of local lISt {
	capture replace    D_days      = `var'   if D_days      == ""  & `var' != "" & survival == "dead"
	capture replace   `var'        = ""      if survival    == "dead"
	}
  
generate   D_months           = ""
local      lISt               = "q127a_age_at_death_months q129a_age_at_death_months_dup q129a_age_at_death_months_dup_du date_birth11 date_birth111"
foreach var of local lISt {
	capture replace    D_months    = `var'   if D_months    == ""  & `var' != "" & survival == "dead"
	capture replace   `var'        = ""      if survival    == "dead"
	}
  
generate   D_years            = ""
local      lISt               = "q129a_age_at_death_years date_birth21"
foreach var of local lISt {
	capture replace    D_years     = `var'   if D_years     == ""  & `var' != "" & survival == "dead"
	capture replace   `var'        = ""      if survival    == "dead"
	}

replace    D_years            = "1"                   if dead         == "equal_1" & dead_1y == "yes" & D_months == ""
replace    D_years            = "0"                   if dead         == "equal_1" & dead_1y == "no"  & D_months == ""
/*few observations of Yobe pilots have reported first birthday but less than 12 months of age at death.*/

generate   tIMe               = ""
generate   D_min              = ""
replace    tIMe               = "d"                   if D_days       != ""        & D_min   == ""
replace    D_min              = D_days                if tIMe         == "d"
replace    tIMe               = "m"                   if D_months     != ""        & D_min   == ""
replace    D_min              = D_months              if tIMe         == "m"
replace    tIMe               = "y"                   if D_years      != ""        & D_min   == ""
replace    D_min              = D_years               if tIMe         == "y"
destring   D_min, replace force
drop       D_days D_months D_years

generate   aiv_year           = ""
generate   aiv_month          = ""
generate   aiv_day            = ""
local      lISt               = "q119aiv_dob_child_less_1 q119aiv_dob_child_1_11m q119aiv_dob_child_12_59m"
foreach var of local lISt {
	capture replace   `var'            = ""                                                      if substr(`var',-1,.) == "-" | substr(`var',-2,.) == "--"
	capture replace    aiv_year        = substr(`var',1,4)                                       if aiv_year           == ""  & `var'              != ""
	capture replace    aiv_month       = substr("0" + subinstr(substr(`var',6,2),"-","",.),-2,.) if aiv_month          == ""  & `var'              != ""
	capture replace    aiv_day         = "99"                                                    if aiv_day            == ""  & `var'              != ""
	}
capture replace    aiv_day    = subinstr(substr(q119aiv_dob_child_less_1,-2,.),"-","0",.) if aiv_day            == "99"  & q119aiv_dob_child_less_1 != ""
foreach var of local lISt {
	capture drop      `var'
	}

generate   date_birth12X      = date_birth12
local      lISt_1             = "q119a_dob_child_less_1 date_birth12X q119a_dob_child_1_11m q119a_dob_child_12_59m q119a_dob_child_greaterthan5"
local      lISt_2             = "q119ai_dob_child_day_less_1 date_birth12_day q119ai_dob_child_day_1_11m q119ai_dob_child_12_59m q119ai_dob_child_greaterthan5 q120iii_pregnancy_end_day aiv_day"
local      lISt_3             = "q119aii_dob_child_month_less_1 date_birth12_month q119aii_dob_child_month_1_11m q119aii_dob_child_12_59m q119aii_dob_child_greaterthan5 q120ii_pregnancy_end_month aiv_month"
local      lISt_4             = "q119aiii_dob_child_year_less_1 date_birth12_year q119aiii_dob_child_year_1_11m q119aiii_dob_child_12_59m q119aiii_dob_child_greaterthan5 q120i_pregnancy_end_year aiv_year"
forvalues n = 1(1)4 {
	generate   DOB_`n' = ""
	foreach var of local lISt_`n' {
		capture replace    DOB_`n'     = `var'   if DOB_`n'     == ""  & `var' != ""
		capture drop      `var'
		}
	}	

replace    DOB_4              = substr(DOB_4,1,4)
local      lISt               = "DOB_2 DOB_3"
foreach    var of local lISt {
	replace   `var'        = "99"                     if  DOB_4 != "" & `var' == ""
	replace   `var'        = substr("0" + `var',-2,.) if `var'  != ""
	}
	
generate   B                  = ""
replace    B                  = DOB_4 + "-" + DOB_3 + "-" + DOB_2  if DOB_4 != "" & B == ""
replace    B                  = DOB_1                              if DOB_1 != "" & B == ""
drop       DOB_*

capture replace    date_year          = substr(date_year,1,4)
local      lISt               = "date_month date_day"
foreach var of local lISt {
	capture replace   `var'        = "99"                     if date_year != "" & `var' == ""
	capture replace   `var'        = substr("0" + `var',-2,.) if `var' != ""  
	}
capture replace    B                  = date_year + "-" + date_month + "-" + date_day if date_year != ""	
capture drop       date_year `lISt'

local      lISt               = "date_birth1 date_birth12 date_birth2 date_birth3 date_birth"
foreach var of local lISt {	
	capture replace    B           = `var'   if B           == ""  & `var' != ""
	capture drop      `var'
	}

generate   year               = substr(B,1,4)
generate   month              = substr(B,6,2)
generate   day                = substr(B,9,2)
destring   year month day, replace
generate   B_min              = mdy(month,day,year)                             /*Generates a variable with full DOB.*/
replace    B_min              = mdy(1,1,year)                  if B_min == . & (month > 12 | month < 1) /*Assumes January 1 if incorrect month.*/
replace    B_min              = mdy(month,1,year)              if B_min == . & (day   > 31 | day   < 1) /*Assumes 1 of the month if incorrect day.*/
replace    B_min              = mdy(mod(month,12) + 1,1,year + floor(month/12)) - 1 if B_min == . /*Fixes incorrect last day of the month (e.g., incorrect 31).*/
generate   B_max              = mdy(month,day,year)                             /*Generates a variable with full DOB.*/
replace    B_max              = mdy(1,1,year + 1)              if B_max == . & (month > 12 | month < 1) /*Assumes January 1 of next calendar year if incorrect month.*/
replace    B_max              = mdy(mod(month,12) + 1,1,year + floor(month/12)) if B_max == . & (day   > 31 | day   < 1) /*Assumes 1 of the next month if incorrect day.*/
replace    B_max              = mdy(mod(month,12) + 1,1,year + floor(month/12)) - 1 if B_max == . /*Fixes incorrect last day of the month (e.g., incorrect 31).*/
replace    B_max              = mdy(1,1,year + 1)              if month == 1   & day == 1 /*Assumes January 1 of next calendar year if imputed at January 1.*/
format     %tdDD/NN/CCYY B_*                                                    /*Applies the proper format to the variable.*/ 
drop       day month year B
  

generate   birth              = "livebirth"                    if OuTComE   == "alive"
replace    birth              = "livebirth"                    if BMC       == "yes"
replace    birth              = "stillbirth"                   if gestation >= 28 & gestation != . & birth == ""
replace    birth              = "miscarriage"                  if birth     == ""  
replace    survival           = "dead"                         if BMC       == "yes"

replace    tIMe               = "d"                            if BMC       == "yes"
replace    D_min              = 1                              if BMC       == "yes"
replace    D_min              = D_min - 1                      if tIMe      == "d"
generate   D_max              = D_min + 1
replace    D_min              = D_min/12*365.25                if tIMe      == "m"
replace    D_max              = D_max/12*365.25                if tIMe      == "m"
replace    D_min              = D_min*365.25                   if tIMe      == "y"
replace    D_max              = D_max*365.25                   if tIMe      == "y"

local      FPH                = "cluster sex gestation OuTComE birth survival D_* B_* _parent_index _index"
keep      `FPH'
order     `FPH'

rename     _parent_index moTHer
generate   c                  = 1                              if B_min     == .
bysort     cluster moTHer: egen       missedDoB  = sum(c)
replace    c                  = 1                              if D_min     == . & survival == "dead"
bysort     cluster moTHer: egen       missedAaD  = sum(c)
generate   mother             = 1

merge m:1  cluster moTHer using `mother', nogenerate keep(match using)
replace    D_max              = max(max(min(B_max + D_max,dofc(sTArt)) - B_max,0),D_min)   if D_min != .
  
generate   b                  = 1                              if OuTComE  == "alive"
generate   d                  = 1                              if survival == "dead"
bysort     cluster moTHer: egen       BornR      = sum(b)  
bysort     cluster moTHer: egen       DeadR      = sum(d)
drop       b d c

replace    sex                = "1"                            if sex      == "male"
replace    sex                = "2"                            if sex      == "female"
destring   sex, replace force

destring   moTHer _index, replace
sort       cluster moTHer _index
bysort     cluster moTHer: generate   k = _n
bysort     cluster moTHer: generate   K = _N
sort       cluster moTHer k
destring   p_count hOUseHOLd latitude longitude, replace
format     %-tcDD/NN/CCYY_HH:MM:SS sUBmiSSion* sTArt eNd
rename     _* x_*
drop if    x_validation      == "validation_status_not_approved"
rename     enum_id enumeratorid
replace    sTArt              = .                              if year(dofc(sTArt)) < 2025
export     delimited using "`pATh'/bASe.csv", replace
save     "`pATh'/bASe.dta", replace



local      pATh               = "/Users/lshjr3/Documents/SARMAAN"
use      "`pATh'/bASe.dta", clear
generate   temp               = 1 if                        sex   == 1 
bysort     cluster moTHer: egen       boys  = sum(temp)
drop       temp
generate   temp               = 1 if                        sex   == 2
bysort     cluster moTHer: egen       girls = sum(temp)
drop       temp
generate   temp               = 1 if                        gestation < 24 & birth == "livebirth"
bysort     cluster moTHer: egen       G24   = sum(temp)
drop       temp


keep if    k                 == 1
generate   neverEXp           = 1 if                        x_index == .

generate   A                  = dofc(sTArt)
generate   O                  = dofc(sTArt)
generate   duration           = abs(eNd - sTArt)/(60000*60) if h == 1

generate   errorB             = abs(BornR - Born)
generate   errorD             = abs(DeadR - Dead)
generate   women              = 1
generate   hOUseholds         = 1   if h == 1
generate   kIDs               = BornR
generate   pregnancies        = K
generate   urban              = 1   if UR == 1 & h == 1
generate   rural              = 1   if UR == 2 & h == 1

replace    cluster            = "Kano"   if cluster == "C-1" | cluster == "C-2"
replace    cluster            = "Kaduna" if cluster == "C-3"
replace    cluster            = "Yobe"   if cluster == "C-4" | cluster == "C-5"

collapse (sum) missedDoB missedAaD errorB errorD women hOUseholds duration kIDs pregnancies urban rural boys girls neverEXp G24 (min) A (max) O, by(cluster enumeratorid)
replace    duration           = duration/hOUsehold
generate   kIDsWoMan          = kIDs/women
replace    rural              = rural/(urban + rural)*100
replace    neverEXp           = neverEXp/women*100
generate   SRB                = boys/girls
replace    G24                = G24/kIDs*100
format     %tdDD/NN/CCYY A O
drop       urban

label      variable A             "First day of fieldwork"
label      variable O             "Last day of fieldwork"
label      variable rural         "Percentage of rural households"
label      variable neverEXp      "Percentage of nulligravid women"
label      variable boys          "Number of ever born boys"
label      variable girls         "Number of ever born girls"
label      variable SRB           "Sex Ratio at Birth (reported livebirths)"
label      variable missedDoB     "Date of Outcome is missing"
label      variable missedAaD     "Age of Death is not stablished"
label      variable errorB        "Mismatched births SBH vs FPH"
label      variable errorD        "Mismatched deaths SBH vs FPH"
label      variable women         "Interviewed women"
label      variable hOUseholds    "Interviewed households"
label      variable duration      "Average duration per household (hours)"
label      variable kIDsWoMan     "Average number of livebirths per woman"
label      variable kIDs          "Number of livebirths"
label      variable pregnancies   "Number of pregnancies"
label      variable G24           "Percentage of livebirhts g < 24w"
format     %10.2f duration rural neverEXp G24 kIDsWoMan SRB
export     delimited using "`pATh'/performance.csv", replace
save     "`pATh'/performance.dta", replace



*/
tempfile   mics
tempfile   dhs
tempfile   temp
tempfile   temp2
tempfile   temp3

local      pATh      = "/Users/lshjr3/Documents/SARMAAN"   
import     spss using "`pATh'/Nigeria MICS6 SPSS/hh.sav", clear
keep       HH1 HH2 HH6 HH7 HH12 HH48 WS1 HC5 HC8
keep if    HH12          == 1 /*consented interviews*/

generate   UR             = HH6
generate   State          = HH7
generate   Region         = 0
replace    Region         = 1     if HH7   == 17 | HH7   == 18 | HH7   == 19 | HH7   == 20 | HH7   == 21 | HH7   == 33 | HH7   == 36
generate   Roofing        = 0     if HC5   != .
recode     Roofing     (0 = 1)    if HC5   == 31 | HC5   == 33 | HC5   == 34 | HC5   == 35 | HC5   == 36
generate   Electricity    = 0
recode     Electricity (0 = 1)    if HC8   ==  1 | HC8   ==  2
generate   Water          = 0     if WS1   != .
recode     Water       (0 = 1)    if WS1   == 11 | WS1   == 12 | WS1   == 13 | WS1   == 14 | WS1   == 21 | WS1   == 31 | WS1   == 41 | WS1   == 51 | WS1   == 71 | WS1   == 72 | WS1   == 91
generate   household      = 1     if HH48   < 5
replace    household      = 2     if HH48   < 9  & house == .
recode     household   (. = 3)
replace    household      = .   /*SARMAAN project quntifies the total number of women 10-55, rather than the total number of household members*/
recode     Electricity Roofing Water (0 = 1) (1 = 2)
keep       HH1 HH2 UR Region State Electricity Roofing Water household
save      `mics', replace

import     spss using "`pATh'/Nigeria MICS6 SPSS/wm.sav", clear
keep if    WM9           == 1 /*consented interviews*/
keep       HH1 HH2 PSU stratum WDOB WM1 WM2 WM3 WM6D WM6M WM6Y WM9 WM17 WM7H WM7M WM10H WM10M WB3M WB3Y WB4 MT11 MT12 CM1 CM2 CM3 CM4 CM5 CM6 CM7 CM8 CM9 CM10 CM11 CM12 CM15 CM17 HH7 wmweight wscore WB6A WB6B welevel
generate   caseid         = _n

generate   Education      = 1
replace    Education      = 2                                                       if  (WB6A == 11 & WB6B == 6)  | WB6A == 21 | WB6A == 22 | WB6A == 31 | WB6A == 32 
replace    Education      = 3                                                       if ((WB6A == 31 | WB6A == 32) & WB6B >=  3 & WB6B  < 98)
replace    Education      = 3                                                       if   WB6A == 41
  
rename     WB4 age
generate   interview      = mdy(WM6M,WM6D,WM6Y)
recode     WB3M       (99 = .) (98 = .)
recode     WB3Y     (9999 = .) (9998 = .)
replace    WB3M           = 1 + mod(WDOB - 1,12)                                    if WB3M    == .
replace    WB3Y           = 1900 + floor((WDOB - 1)/12)                             if WB3Y    == .

generate   DOB_min        = mdy(WB3M,1,WB3Y)
generate   DOB_max        = mdy(1 + mod(WB3M,12),1,WB3Y + floor(WB3M/12))
replace    DOB_min        = mdy(1,1,WB3Y)                                           if DOB_min == .
replace    DOB_max        = mdy(1,1,WB3Y + 1)                                       if DOB_max == .
replace    DOB_min        = mdy(1,1,WM6Y - age - 1)                                 if DOB_min == .
replace    DOB_max        = mdy(1,1,WM6Y - age)                                     if DOB_max == .
format     %tdDD/NN/CCYY interview DOB_*

rename     HH7 region
rename     wmweight W
keep if    W              > 0                
generate   mobile         = 0
recode     mobile      (0 = 1)                                                      if MT11 == 1
rename     PSU cluster
keep       caseid HH1 HH2 WM1 WM2 WM3 interview DOB_* Education age W mobile cluster stratum wscore
sort       WM1 WM2 WM3

sort       cluster caseid
bysort     cluster: generate   woman          = _n
bysort     cluster: generate   Women          = _N
generate   w              = Women                                                   if woman   == 1
generate   iNDeX          = sum(w)
replace    iNDeX          = iNDeX - Women
drop       w
egen       GO             = cut(age), at(10,15,20,25,30,35,40,45,50,55,60) icodes
replace    GO             = min(GO,8) + 1
merge m:1  HH1 HH2 using `mics', nogenerate keep(master match)
drop       HH1 HH2
save      `mics', replace

import     spss using "`pATh'/Nigeria MICS6 SPSS/bh.sav", clear
recode     BH4M BH4D  (99 = .) (98 = .)
recode     BH4Y     (9999 = .) (9998 = .)
replace    BH4M           = 1 + mod(BH4C - 1,12)                                    if BH4M    == .
replace    BH4Y           = 1900 + floor((BH4C - 1)/12)                             if BH4Y    == .

generate   B_min          = mdy(BH4M,BH4D,BH4Y)
replace    B_min          = mdy(1 + mod(BH4M,12),1,BH4Y + floor((BH4M + 1)/12)) - 1 if B_min   == . & BH4D    != .
generate   B_max          = B_min
replace    B_min          = mdy(BH4M,1,BH4Y)                                        if B_min   == . 
replace    B_min          = mdy(1,1,BH4Y)                                           if B_min   == .
replace    B_max          = mdy(1 + mod(BH4M,12),1,BH4Y + floor(BH4M/12))           if B_max   == .
replace    B_max          = mdy(1,1,BH4Y + 1)                                       if B_max   == .
format     %tdDD/NN/CCYY B_*

generate   D_min          = BH9N                                                     if BH9U == 1
generate   D_max          = BH9N + 1                                                 if BH9U == 1
replace    D_min          = BH9N*365.25/12                                           if BH9U == 2
replace    D_max          = (BH9N + 1)*365.25/12                                     if BH9U == 2
replace    D_min          = BH9N*365.25                                              if BH9U == 3
replace    D_max          = (BH9N + 1)*365.25                                        if BH9U == 3

replace    D_min          = BH9C*365.25/12                                           if BH9U == 9
replace    D_max          = (BH9C + 1)*365.25/12                                     if BH9U == 9
rename     BH3 sex
rename     BH2 multiple
generate   mother         = 1
sort       WM1 WM2 WM3 B_min
bysort     WM1 WM2 WM3:  generate   bidx      = _n
keep       WM1 WM2 WM3 B_* D_* sex multiple mother bidx
merge m:1  WM1 WM2 WM3 using `mics', nogenerate

replace    B_max          = max(min(B_max,interview),B_min)                          if B_min != .
replace    D_max          = max(max(min(B_max + D_max,interview) - B_max,0),D_min)   if D_min != .    

sort       caseid B_min
bysort     caseid:  generate   k              = _n
bysort     caseid:  generate   K              = _N 
drop       WM1 WM2 WM3
order      cluster caseid 
label drop _all
sort       cluster caseid k
save      `mics', replace

generate   temp         = substr("0000000000" + string(caseid),-10,.)
drop       caseid
rename     temp caseid
order      cluster caseid
sort       cluster caseid k
save     "`pATh'/MICS.dta", replace
export     delimited using "`pATh'/MICSnigeria.csv", replace


local      sEL            = "caseid v001 v002 v003 v005 v006 v007 v016 v009 v010 v012 v023 v024 v025 v169a vcal_1 v008 v018"
use       `sEL' using "`pATh'/NGIR8BFL.DTA", clear
save      `temp', replace

local      sEL            = "caseid v001 v002 v003 v006 v007 v016 v008 v009 v010 v012 v023 v024 v025 bidx b0 b1 b2 b3 b4 b6 b7 b17"
use       `sEL' using "`pATh'/NGBR8BFL.DTA", clear
generate   mother         = 1
merge m:1  caseid v001 v002 v003 v006 v007 v016 v008 v009 v010 v012 v023 v024 v025 using `temp', nogenerate
sort       caseid bidx
bysort     caseid: generate   k = _n
bysort     caseid: generate   K = _N

generate   cluster        = v001
generate   HH             = v002
generate   respondent     = v003

sort       cluster HH caseid k
generate   woman          = 1                                               if k     == 1
bysort     cluster: egen       Women          = sum(woman)
bysort     cluster: replace    woman          = sum(woman)
generate   w              = Women                                           if k     == 1 & woman == 1
generate   iNDeX          = sum(w)
replace    iNDeX          = iNDeX - Women
drop       w

generate   interview      = mdy(v006,v016,v007)
generate   DOB_min        = mdy(v009,1,v010)
generate   DOB_max        = mdy(1 + mod(v009,12),1,v010 + floor(v009/12))
replace    DOB_min        = mdy(1,1,v010)                                           if DOB_min == .
replace    DOB_max        = mdy(1,1,v010 + 1)                                       if DOB_max == .
format     %tdDD/NN/CCYY interview DOB_*

sort       b3 b17
if b17[1] == . {
	generate   B_min          = mdy(b3 - floor((b3 - 1)/12)*12,1,floor((b3 - 1)/12) + 1900)                        if b3    != .
	generate   B_max          = mdy(b3 + 1 - floor(b3/12)*12,1,floor(b3/12) + 1900)                                if b3    != .
	}
else {
	generate   B_min          = mdy(b3 - floor((b3 - 1)/12)*12,b17,floor((b3 - 1)/12) + 1900)                      if b3    != .
	replace    B_min          = mdy(b3 + 1 - floor((b3 - 1)/12)*12,1,floor((b3 - 1)/12) + 1900) - 1                if B_min == . & b3  != .
	generate   B_max          = B_min
	}

replace    B_max          = max(min(B_max,interview),B_min)	                         if B_mi != .
format     %tdDD/NN/CCYY B_*
rename     b4 sex
rename     v012 age
rename     v169a mobile

generate   D_min          = b6 - 100                                                 if b6   != .   & b6 <= 200
generate   D_max          = D_min + 1                                                if b6   != .   & b6 <= 200
replace    D_min          = 0                                                        if b6   == 198 | b6 == 199  
replace    D_max          = 365.25/12                                                if b6   == 198 | b6 == 199	
replace    D_min          = (b6 - 200)*365.25/12                                     if b6   != .   & b6 >= 200 & b6  < 300 
replace    D_max          = (b6 - 200 + 1)*365.25/12                                 if b6   != .   & b6 >= 200 & b6  < 300
replace    D_min          = 0                                                        if b6   == 298 | b6 == 299  
replace    D_max          = 24*365.25/12                                             if b6   == 298 | b6 == 299
replace    D_min          = (b6 - 300)*365.25                                        if b6   != .   & b6 >= 300 
replace    D_max          = (b6 - 300 + 1)*365.25                                    if b6   != .   & b6 >= 300
replace    D_min          = 0                                                        if b6   == 398 | b6 == 399  
replace    D_max          = max(year(interview) - year(B_min),0)*365.25              if b6   == 398 | b6 == 399
replace    D_max          = max(max(min(B_max + D_max,interview) - B_max,0),D_min)   if D_min != .

generate   W              = v005/1000000
generate   CAL            = "C" + vcal_1                                             if k    == 1 | k  == .
generate   row            = v018                                                     if k    == 1 | k  == .
keep       cluster HH respondent age sex interview B_* D_* mobile W bidx caseid DOB_* k K woman Women iNDeX mother CAL row
order      cluster HH respondent age sex interview B_* D_* mobile W bidx caseid DOB_* k K woman Women iNDeX mother CAL row
generate   reproductive = 1
egen       GO             = cut(age), at(10,15,20,25,30,35,40,45,50,55,60) icodes
replace    GO             = min(GO,8) + 1
save      `dhs', replace

contract   caseid cluster HH respondent age W mobile reproductive
keep       caseid cluster HH respondent age W mobile reproductive
save      `temp2', replace

local      sEL            = "hhid hvidx hv001 hv002 hv104 hv109 hv023 hv024 hv025 hv206 hv215 hv201 hv102"
use       `sEL' using "`pATh'/NGPR8BFL.DTA", clear
generate   cluster        = hv001
generate   HH             = hv002
generate   respondent     = hvidx
merge 1:1  cluster HH respondent using `temp2', nogenerate

generate   Education      = hv109
recode     Education   (8 = 1)
recode     Education   (0 = 1) (3 = 2) (4 = 3) (5 = 3)

generate   State          = hv023
generate   Region         = hv024
generate   UR             = hv025
generate   Electricity    = hv206
generate   Roofing        = 0
recode     Roofing     (0 = 1)    if hv215 == 31 | hv215 == 33 | hv215 == 34 | hv215 == 35 | hv215 == 36 /* good material excluding wood*/
generate   Water          = 0
recode     Water       (0 = 1)    if hv201 == 11 | hv201 == 12 | hv201 == 13 | hv201 == 14 | hv201 == 21 | hv201 == 31 | hv201 == 41 | hv201 == 51 | hv201 == 62 | hv201 == 71
generate   jure           = hv102 if age   >= 10 & age   <= 55 & hv104 == 2 /*SARMAAN project quntifies the total number of women 10-55, rather than the total number of household members*/
bysort     hhid: egen   HH_size = sum(jure)

generate   household      = 1     if HH_si  < 5
replace    household      = 2     if HH_si  < 9  & house == .
recode     household   (. = 3)
recode     Electricity Roofing Water (0 = 1) (1 = 2)
keep       cluster HH respondent jure UR Region State household Education Electricity Roofing Water HH_size
save      `temp2', replace

use       `dhs', clear
merge m:1  cluster HH respondent using `temp2', nogenerate keep(master match)
label drop _all
sort       cluster HH caseid k
save     "`pATh'/DHS.dta", replace
export     delimited using "`pATh'/DHSnigeria.csv", replace
