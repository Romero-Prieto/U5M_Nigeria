tempfile   temp
tempfile   temp2
tempfile   wide


use       "/Users/lshjr3/Documents/SARMAAN/bASe.dta", clear
keep if    cluster    == "C-4" | cluster == "C-5"
replace    B_min       = . if birth != "livebirth"
replace    B_max       = . if birth != "livebirth"
generate   Is          = dofc(sTArt)
generate   I           = (year(Is) - 1900)*12 + month(Is)
generate   W           = 1
keep       cluster moTHer DOB_* B_* I* W k K

/*
use       "/Users/lshjr3/Documents/SARMAAN/DHS.dta", clear
generate   moTHer      = caseid
generate   Is          = interview
generate   I           = (year(Is) - 1900)*12 + month(Is)
keep       cluster moTHer DOB_* B_* I* W k K
*/

generate   p           = 0.5
generate   Bs          = floor(B_min + (B_max - B_min)*p)
generate   B           = (year(Bs) - 1900)*12 + month(Bs)
format     %tdDD/NN/CCYY Is Bs
save      `temp', replace

contract   cluster moTHer DOB_* I* W 
generate   p           = 0.5
generate   WBs         = floor(DOB_min + (DOB_max - DOB_min)*p)
generate   WB          = (year(WBs) - 1900)*12 + month(WBs)
keep       cluster moTHer I* W WB*
format     %tdDD/NN/CCYY WBs
save      `wide', replace

merge 1:m  cluster moTHer I* W using `temp', nogenerate noreport
drop       DOB_* B_* p
save      `temp', replace

forvalues i = 1/25 {
	use       `temp', clear
	keep if    k == `i'
	keep       cluster moTHer B
	rename     B B_`i'
	save      `temp2', replace
	
	use       `wide', clear
	merge 1:1  cluster moTHer using `temp2', nogenerate noreport
	save      `wide', replace
	}
	
tfr2 [pw = W], bvar(B_*) length(3) dates(I) wbirth(WB) ageg(1)



use       `temp', clear
egen       upper    = min(Is)
generate   AU       = (upper - WBs)/365.25
generate   AS       = (Is - WBs)/365.25
generate   exposure = 0 if k == 1
generate   events   = 0

forvalues i = 15/49 {
	generate   a            = max(min(min(AS,AU) - 3,`i' + 1),`i')
	generate   o            = max(min(min(AS,AU),`i' + 1),`i')
	generate   exposure_`i' = (o - a)*W if k == 1
	replace    exposure     = exposure + max(exposure_`i',0)
	generate   events_`i'   = W if (upper - Bs)/365.25 <= 3 & (upper - Bs)/365.25 > 0 & (Bs - WBs)/365.25 >= `i' & (Bs - WBs)/365.25 < `i' + 1 
	replace    events       = events + max(events_`i',0)
	drop       a o
	}
	
collapse (sum) events exposure events_* exposure_*	
	
generate   F        = 0
forvalues i = 15/49 {
	generate   f_`i' = events_`i'/exposure_`i'
	replace    F     = F + f_`i'
	}
	
dis F
		
