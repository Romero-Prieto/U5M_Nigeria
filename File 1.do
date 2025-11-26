/*Data preparation*/
tempfile   mother                                                               /*Temp files should be declared before used. This is a processing file to extract data from different instuments: household female pregnancy.*/
local      pATh      = "/Users/lshjr3/Documents/SARMAAN"                        /*The path to the folder containing the KoboToolbox outputs.*/

local      Mortality = "household female pregnancy"                             /*KoboToolbox outputs have 5 sheets and these three are used for U5M estimation.*/
foreach sheet of local Mortality {                                              /*Repeats the same reading commands for each sheet.*/
	tempfile  `sheet'                                                           /*Temp files should be declared before used.*/
	clear                                                                       /*Clears all variables and observations.*/
	generate   cluster = ""                                                     /*Clusters represent batches of data collection; for example, Kano corresponds to clusters 1 and 2, while Kaduna corresponds to cluster 3, and so on.*/
	save     ``sheet'', replace                                                 /*Saves the temporary file for later use.*/
	forvalues cluster = 1(1)3 {                                                 /*Repeats the same commands for each cluster.*/
		quiet import excel "`pATh'/Mortality_`cluster'.xlsx", sheet("`sheet'") firstrow case(lower) allstring clear /*Reads KoboToolbox outputs (excel files).*/
		generate   cluster = "C-`cluster'"                                      /*Generates an identifier for each cluster.*/
		append     using ``sheet''                                              /*Compiles data from different clusters but the same sheet.*/
		save     ``sheet'', replace                                             /*Saves the data of each sheet.*/
		}                                                                       /*Closes the loop.*/
	}

	
use       `household', clear                                                    /*Accesses the temporary file that contains household characteristics.*/
rename     start                sTArt                                           /*Renames time variables.*/
rename     end                  eNd
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
rename     q2state              state                                           /*Identifies the state.*/
rename     q3local              localG                                          /*Identifies the local government area.*/
rename     q4ward               ward                                            /*Identifies the ward.*/
generate   UR                 = 1                     if chooset == "Urban"     /*Identifies the urban/rural place of residence.*/
replace    UR                 = 2                     if chooset == "Rural"

generate   HH_size            = q37                                             /*SARMAAN project quntifies the total number of women 10-55, rather than the total number of household members*/
destring   HH_size, replace                                                     /*Transforms strings into numeric values, as all variables are strings by default.*/
generate   household          = 1                     if HH_size  < 5           /*Classifies household sizes into broad categories.*/
replace    household          = 2                     if HH_size  < 9  & household == . /*Continuation.*/
recode     household       (. = 3)                                              
generate   Electricity        = 1                                               /*Determines whether a household has access to electricity.*/
replace    Electricity        = 2                     if q21     == "Yes"

rename     kindly*watersource Sq27                                              /*Renames the variable that describes the source of water, using the notation "beginning*ending" and omitting any text in between.*/
generate   Water              = 1                                               /*Identifies safe sources of water.*/
replace    Water              = 2                     if q27     == "Piped into dwelling"
replace    Water              = 2                     if q27     == "Rainwater"
replace    Water              = 2                     if q27     == "Public tap"
replace    Water              = 2                     if q27     == "Cart with small tanks (Mairuwa/Garuwa)"
replace    Water              = 2                     if q27     == "Covered well"
replace    Water              = 2                     if q27     == "Spring"
replace    Water              = 2                     if q27     == "Borehole"
replace    Water              = 2                     if q27     == "Others"  & substr(Sq27,1,4) != "Tank" & substr(Sq27,-4,.) != "tank" 
replace    enumeratorid       = substr(enumeratorid,-4,.)                       /*Identifies the code of the enumerator.*/
local      GPS                = "cluster sTArt eNd sUBmiSSion deviceid _id enumerator latitude longitude hOUseHOLd household HH_size Water Electricity state localG ward UR _validation" /*Makes a list of the variables to be retained.*/
keep      `GPS'                                                                 /*Keeps the previously listed variables.*/

destring   latitude longitude, replace                                          /*Transforms strings into numeric values, as all variables are strings by default.*/
generate   wrongGPS           = 0                                               /*Assumes that all GPS coordinates are accurate.*/
replace    wrongGPS           = 1                     if latitud <= 4           | latitude  > 14 /*Identifies coordinates that fall outside the valid range.*/ 
replace    wrongGPS           = 1                     if longitu <= 2           | longitud  > 15 /*Idem.*/
bysort     cluster: egen float LAT   = median(latitude)  if wrongGPS == 0       /*Captures median latitude for each cluster.*/
bysort     cluster: egen float LONG  = median(longitude) if wrongGPS == 0       /*Captures median longitude for each cluster.*/
generate   Euclidean          = sqrt((latitude - LAT)^2 + (longitude - LONG)^2) /*Calculates planar distances to the median points.*/
save      `mother', replace                                                     /*Saves the processed household data.*/
	
use       `female', clear                                                       /*Accesses the temporary file that contains the characteristics of women in reproductive ages.*/
destring   age, replace                                                         /*Transforms strings into numeric values.*/
egen       GO                 = cut(age), at(10,15,20,25,30,35,40,45,50,55,60) icodes /*Classifies ages into broad categories.*/
replace    GO                 = min(GO,8) + 1                                   /*Truncates at 50, and starts at 1.*/

destring   q46, replace                                                         /*Transforms strings into numeric values.*/
generate   Education          = 1                                               /*Classifies education into broad categories.*/
replace    Education          = 2                     if (q45  == "Primary"   & q46 >= 6) | q45  == "Secondary"
replace    Education          = 3                     if (q45  == "Secondary" & q46 >= 6) | q45  == "Higher"
generate   double DOB         = date(q42dateofbirth,"YMD")                      /*Generates a variable with the date of birth (women).*/
format     %tdDD/NN/CCYY DOB                                                    /*Applies the proper format to the variable.*/
local      SPH                = "cluster DOB age GO mother_id q103* q105* q107* c_count p_count _parent_index _index Education _submission__id _submission__uuid" local      GPS                = "cluster sTArt eNd sUBmiSSion deviceid _id enumerator latitude longitude hOUseHOLd household HH_size Water Electricity state localG ward UR _validation" /*Makes a list of the variables to be retained.*/
keep      `SPH'                                                                 /*Keeps the previously listed variables.*/
rename     _parent_index hOUseHOLd 
destring   q103* q105* q107* c_count p_count, replace
recode     q103* q105* q107* c_count p_count (. = 0)
generate   sons               = q103a + q105a + q107a
generate   daughters          = q103b + q105b + q107b
generate   sonsD              = q107a
generate   daughtersD         = q107b
generate   Born               = q103a + q103b + q105a + q105b + q107a + q107b
generate   Dead               = q107a + q107b
generate   Away               = q105a + q105b
rename     c_count b_count
drop       q103* q105* q107*
merge m:1  cluster hOUseHOLd using `mother', keep(master match) nogenerate
rename     _index moTHer
save      `mother', replace

use       `Mortality_pregnancy', clear
local      FPH                = "cluster q113* q114* q115* q117* q119* q120* q121* q122* q123* q124* q125* q126* q127* q128* q129* q130* q131* _submission__id _parent_index _index"
keep      `FPH'
order     `FPH'
rename     _parent_index moTHer
merge m:1  cluster moTHer using `mother', nogenerate keep(master match) keepusing(sUBmiSSion)
rename     q117 sex

replace    q120inwhatyear     = substr(q120inwhatyear,1,4)
replace    q120inwhatday      = substr("0" + q120inwhatday,-2,.)                             if q120inwhatday != "" 
local      lISt               = "January February March April May June July August September October November December"
foreach m of local lISt {
	local      month              = `month' + 1
	replace    q120inwhatmonth    = substr("0`month'",-2,.) if q120inwhatmont == "`m'"
	}
generate   imputed_date       = "preg_end"                                                   if q120inwhatyear != "" & (q120inwhatday   == "" | q120inwhatmonth == "")
replace    q120inwhatday      = "01"                                                         if q120inwhatyear != "" &  q120inwhatday   == ""
replace    q120inwhatmonth    = "01"                                                         if q120inwhatyear != "" &  q120inwhatmonth == ""
replace    q120inwhatyear     = q120inwhatyear + "-" + q120inwhatmonth + "-" + q120inwhatday if q120inwhatyear != ""
replace    q120onwhatdaymon   = q120inwhatyear                                               if q120inwhatyear != ""
drop       q120inwhatyear q120inwhatmonth q120inwhatday
	

local      lISt               = "q119adateofbirthofchild q119bdateofbirthofchild q119cdateofbirthofchild q120onwhatdaymonthandye"
order     `lISt'
generate   B                  = .
format     %tdDD/NN/CCYY B
foreach d of local lISt {
	replace    B = date(`d',"YMD") if `d' != "" & B == . 
	}
drop      `lISt'
generate   mISSingDaTe        = 1                     if B       == .
recode     mISSingDaTe     (. = 0)

rename     q121*last q121
rename     q122*_idinw q122_idinw
rename     q122*_idinm q122_idinm
destring   q122_idin*, replace
generate   gestation          = .
replace    gestation          = q122_idinw            if q121 == "Weeks"
replace    gestation          = q122_idinm/12*52      if q121 == "Months"
generate   G28                = 1                     if gest >= 28 
recode     G28             (. = 0)                    if gest  < 28 & gest != .
generate   G24                = 1                     if gest >= 24 
recode     G24             (. = 0)                    if gest  < 24 & gest != .

generate   OuTComE            = "Livebirth"           if q114    == "Born Alive"
replace    OuTComE            = "Livebirth"           if q114    == "Born alive but dead later"
replace    OuTComE            = "Stillbirth"          if q114    == "Born dead"
replace    OuTComE            = "ReClass Livebirth"   if q115    == "Yes" 
replace    OuTComE            = "Miscarriage"         if q114    == "Miscarriage and Abortion"
replace    OuTComE            = "Miscarriage"         if q114    == "Born Dead, Miscarriage or Abortion" & G28      == 0
replace    OuTComE            = "Stillbirth"          if q114    == "Born Dead, Miscarriage or Abortion" & G28      == 1
replace    OuTComE            = "ReClass Stillbirth"  if OuTComE == "Miscarriage"                        & G28      == 1
replace    OuTComE            = "ReClass Miscarriage" if OuTComE == "Stillbirth"                         & G28      == 0

generate   survival           = "alive"               if q124    == "Yes"
replace    survival           = "dead"                if q124    == "No"
replace    survival           = "dead"                if OuTComE == "ReClass Livebirth"                  & survival == ""
replace    survival           = "unknown"             if OuTComE == "Livebirth"                          & survival == ""

generate   A                  = dofc(sUBmiSSion)      if B       != .                                    & q124     == "No"
replace    A                  = floor((A - B)/365.25)
replace    A                  = .                     if A        < 0 
destring   q125, replace
generate   Am                 = string(min(A,q125))   if q125    != .

generate   tIMe               = ""
generate   D_min              = ""
replace    tIMe               = "d"                   if q126    == "Less than 1 year"    & D_min == "" & q127aexactlyhowmanyd != ""    & q127aexactlyhowmanym == "1"
replace    D_min              = q127aexactlyhowmanyd  if q126    == "Less than 1 year"    & D_min == "" & q127aexactlyhowmanyd != ""    & q127aexactlyhowmanym == "1"
replace    tIMe               = "m"                   if q126    == "Less than 1 year"    & D_min == "" & q127aexactlyhowmanym != ""
replace    D_min              = q127aexactlyhowmanym  if q126    == "Less than 1 year"    & D_min == "" & q127aexactlyhowmanym != ""
replace    tIMe               = "m"                   if q126    == "12 months or 1 year" & D_min == "" & q129aexactlyhowmanym != ""    & q128                 == "No"
replace    D_min              = q129aexactlyhowmanym  if q126    == "12 months or 1 year" & D_min == "" & q129aexactlyhowmanym != ""    & q128                 == "No"
replace    tIMe               = "y"                   if q126    == "12 months or 1 year" & D_min == "" & q128                 == "Yes"
replace    D_min              = "1"                   if q126    == "12 months or 1 year" & D_min == "" & q128                 == "Yes"
replace    tIMe               = "y"                   if q126    == "Greater than 1 year" & D_min == ""
replace    D_min              = q129aexactlyhowmanyy  if q126    == "Greater than 1 year" & D_min == ""
replace    tIMe               = "y"                   if q124    == "No"                  & D_min == "" & Am                   != ""
replace    D_min              = Am                    if q124    == "No"                  & D_min == "" & Am                   != ""
replace    tIMe               = "d"                   if OuTComE == "ReClass Livebirth"   & D_min == ""
replace    D_min              = "1"                   if OuTComE == "ReClass Livebirth"   & D_min == ""
destring   D_min, replace force
replace    D_min              = D_min - 1             if tIMe    == "d"
generate   D_max              = D_min + 1
replace    tIMe               = "y"                   if q124    == "No"                  & D_min == .  & A                    != .
replace    D_min              = 0                     if q124    == "No"                  & D_min == .  & A                    != .
replace    D_max              = A                     if q124    == "No"                  & D_max == .  & A                    != .
drop       A Am

replace    D_min              = D_min/12*365.25       if tIMe    == "m"
replace    D_max              = D_max/12*365.25       if tIMe    == "m"
replace    D_min              = D_min*365.25          if tIMe    == "y"
replace    D_max              = D_max*365.25          if tIMe    == "y"
replace    D_max              = max(max(min(B + D_max,dofc(sUBmiSSion)) - B,0),D_min)   if D_min != .

generate   birth              = "livebirth"           if OuTComE == "Livebirth"   | OuTComE == "ReClass Livebirth" 
replace    birth              = "stillbirth"          if OuTComE == "Stillbirth"  | OuTComE == "ReClass Stillbirth" 
replace    birth              = "miscarriage"         if OuTComE == "Miscarriage" | OuTComE == "ReClass Miscarriage" 
generate   FlagBI             = 0

rename     sex temp
generate   sex                = 1                     if temp == "Male"
replace    sex                = 2                     if temp == "Female"
generate   mother             = 1

keep       cluster sex moTHer _index B gestation birth mISSingDaTe survival D_*	FlagBI mother OuTComE
merge m:1  cluster moTHer using `mother', nogenerate keep(match using)

destring   moTHer _index, replace
sort       cluster moTHer _index
bysort     cluster moTHer: generate   k = _n
bysort     cluster moTHer: generate   K = _N
sort       cluster moTHer k
destring   p_count hOUseHOLd latitude longitude, replace
format     %-tcDD/NN/CCYY_HH:MM:SS sUBmiSSion* sTArt eNd
rename     _* x_*
export     delimited using "`pATh'/bASe.csv", replace
save     "`pATh'/bASe.dta", replace

generate   d_SBH              = Dead                  if k       == 1
generate   temp               = 1                     if OuTComE == "Livebirth" & survival == "dead"
bysort     cluster moTHer: egen d_FPH = sum(temp)
keep if    k                 == 1
keep       cluster moTHer mother_id age b_count p_count hOUseHOLd x_submission__id x_submission__uuid sTArt eNd sUBmiSSion deviceid x_id enumeratorid latitude longitude d_* state localG ward UR
keep if    d_SBH             != d_FPH
rename     moTHer x_index
label      variable x_index "female"
order      sTArt eNd sUBmiSSion
generate   diff               = d_SBH - d_FPH
keep if    diff > 0
save     "`pATh'/list_missingD.dta", replace

tempfile   temp
local      pATh      = "/Users/lshjr3/Documents/SARMAAN"       
use      "`pATh'/list_missingD.dta", clear
generate   inconsistent       = 1
collapse  (sum) inconsistent diff, by(enumeratorid)
save      `temp', replace

use      "`pATh'/bASe.dta", clear
generate   missing            = 1                     if OuTComE == "Livebirth" & survival == "dead"  & D_min == .
generate   interviews         = 1                     if k       == 1
generate   rural              = 1                     if k       == 1           & UR       == 2
generate   A                  = dofc(sTArt)
bysort     enumeratorid A: generate   n   = _n
generate   days               = 1                     if n       == 1
generate   d                  = Dead                  if k       == 1
generate   O                  = A
format     %tdCCYY-NN-DD A O

collapse  (sum) interviews rural missing days d (min) A (max) O, by(enumeratorid)
merge 1:1  enumeratorid using `temp', nogenerate

replace    rural              = rural/interviews*100
generate   Error_I            = (missing + max(inconsistent,0))/interviews*100
generate   Error_II           = max(diff,0)/d*100
generate   InterviewRate      = interviews/days

label      variable A             "First day of fieldwork"
label      variable O             "Last day of fieldwork"
label      variable rural         "Percentage rural interviews"
label      variable missing       "DoB is missing, AaD not stablished"
label      variable interviews    "Women interviewed"
label      variable days          "Fieldwork days"
label      variable inconsistent  "Inconsistent SBH and FPH"
label      variable Error_I       "Mistakes per 100 interviews"
label      variable Error_II      "Percentage of missing deaths"
label      variable InterviewRate "Women interviewed per day"
label      variable d             "Reported deaths from SBH"
label      variable diff          "Missing deaths"
save     "`pATh'/list_performance.dta", replace
*/
tempfile   mics
tempfile   dhs
tempfile   temp
tempfile   temp2
tempfile   temp3
local      pATh      = "/Users/lshjr3/Documents/SARMAAN"   

import     delimited "`pATh'/UN IGME 2024.csv", clear
keep if    geographicarea  == "Nigeria"
keep if    seriesname      == "UN IGME estimate"
keep if    wealthquintile  == "Total" 
keep       indicator observationvalue lowerbound upperbound referencedate sex

generate   name             = ""
replace    name             = "child"                  if indicator == "Child Mortality rate age 1-4"
replace    name             = "infant"                 if indicator == "Infant mortality rate"
replace    name             = "non_neonatal_under5"    if indicator == "Mortality rate 1-59 months"
replace    name             = "post_neonatal"          if indicator == "Mortality rate age 1-11 months"
replace    name             = "neonatal"               if indicator == "Neonatal mortality rate"
replace    name             = "stillbirth"             if indicator == "Stillbirth rate"
replace    name             = "under5"                 if indicator == "Under-five mortality rate"
drop if    name            == ""

drop       indicator
rename     referencedate Year
order      sex Year name
label      variable sex              ""
label      variable Year             ""
label      variable observationvalue ""
label      variable lowerbound       ""
label      variable upperbound       ""
save      `temp'

local      lISt             = "neonatal infant under5 stillbirth post_neonatal child non_neonatal_under5"
drop if    Year            != .
keep       sex Year
save      `temp2'

foreach var of local lISt {
	dis       "`var'"
	use       `temp', clear
	keep if    name         == "`var'"
	rename     observationvalue `var'
	rename     lowerbound `var'_LB
	rename     upperbound `var'_UB
	keep       sex Year `var'*
	save      `temp3', replace
	
	use       `temp2', clear
	merge 1:1  sex Year using `temp3', nogenerate noreport
	save      `temp2', replace
	}

keep if    sex             == "Total"
drop       sex
gsort     -Year
export     delimited using "`pATh'/IGMEnigeria.csv", replace


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
sort       cluster caseid k
export     delimited using "`pATh'/MICSnigeria.csv", replace


local      sEL            = "caseid v001 v002 v003 v005 v006 v007 v016 v009 v010 v012 v023 v024 v025 v169a vcal_1 v008 v018"
use       `sEL' using "`pATh'/NGIR7BFL.DTA", clear
save      `temp', replace

local      sEL            = "caseid v001 v002 v003 v006 v007 v016 v008 v009 v010 v012 v023 v024 v025 bidx b0 b1 b2 b3 b4 b6 b7 b17"
use       `sEL' using "`pATh'/NGBR7BFL.DTA", clear
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

generate   DOB            = mdy(v009,1,v010)
generate   interview      = mdy(v006,v016,v007)

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
format     %tdDD/NN/CCYY interview B_* DOB
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
keep       cluster HH respondent age sex interview B_* D_* mobile W bidx caseid DOB k K woman Women iNDeX mother CAL row
order      cluster HH respondent age sex interview B_* D_* mobile W bidx caseid DOB k K woman Women iNDeX mother CAL row
generate   reproductive = 1
egen       GO             = cut(age), at(10,15,20,25,30,35,40,45,50,55,60) icodes
replace    GO             = min(GO,8) + 1
save      `dhs', replace

contract   caseid cluster HH respondent age W mobile reproductive
keep       caseid cluster HH respondent age W mobile reproductive
save      `temp2', replace

local      sEL            = "hhid hvidx hv001 hv002 hv104 hv109 hv023 hv024 hv025 hv206 hv215 hv201 hv102"
use       `sEL' using "`pATh'/NGPR7BFL.DTA", clear
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
export     delimited using "`pATh'/DHSnigeria.csv", replace
