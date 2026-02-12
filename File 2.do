///File 2: Under-5 Mortality Estimation///
clear all
mata                                                                         /*Opens MATA interface*/
void lIFeTaBLe(real scalar R, real scalar T, string scalar method) {         /*Reads the number of resamples, R, periods of analysis, T, and resampling method.*/
	rseed(1)                                                                 /*Specifies the seed to generate random numbers.*/
	
	if (method == "B") {/*Bootstrapping Estimator as a Frequency Correction*/
		correction    = 1                                                    /*Defines the correction factor to calculate standard errors from standard deviations.*/
		st_view(sET = ., ., "cluster iNDeX woman Women k K")                 /*Extracts the relevant data for the Bootstrapping.*/	
		sET           = sET[selectindex(sET[.,5] :== 1),.]                   /*Restricts the extracted data to be one record per woman.*/
		random        = ceil(uniform(rows(sET),R):*sET[.,4]) :+ sET[.,2]     /*Draws a random selection with replacement within each cluster. The output is an index for each woman.*/
		clUStEr       = sET[selectindex(sET[.,3] :== 1),1]                   /*Generates a list of clusters.*/
		f             = J(rows(sET),R,.)                                     /*Generates a null space for frequencies, one row per woman and one column per drawn.*/
		for (i = 1; i <= length(clUStEr); i++) {                             /*Transforms indices into frequencies by cluster, and then by each women to reduce the number of operations.*/
			sUBsET        = sET[selectindex(sET[.,1] :== clUStEr[i]),.]      /*Defines a subset of information to retain only the relevant information of each cluster.*/
			sUBrandom     = random[selectindex(sET[.,1] :== clUStEr[i]),.]	 /*Defines a subset of random indices that are the relevant for each cluster.*/
			for (j = 1; j <= sUBsET[1,4]; j++) {
				index         = sUBsET[j,2] + j
				f[index,.]    = colsum(sUBrandom :== index)                  /*Calculates the frequencies for each woman and sample.*/
				}		
			}
		
		F             = J(0,R,.)                                             /*Generates a null space for expanded frequencies, one per birth.*/
		for (i = 1; i <= rows(sET); i++) {                                   /*Expands each record to be one per reported birth.*/
			F = F \ J(sET[i,6],1,f[i,.])
			}
		method        = "SP Bootstrap, R = " + strofreal(R)
		method        = "Semiparametric Bootstrap"
		}
	else {/*Jackknife Estimator as a Frequency Correction*/
		st_view(sET = ., ., "cluster woman")                                 /*Extracts the relevant data for the Jackknife.*/	
		clUStEr       = sET[selectindex(sET[.,2] :== 1),1]                   /*Generates a list of clusters.*/
		R             = length(clUStEr)                                      /*Defines the number of resamples.*/
		correction    = sqrt(R - 1)                                          /*Defines the correction factor to calculate standard errors from standard deviations.*/
		F             = J(rows(sET),length(clUStEr),1)                       /*Generates a null space for Jackknife frequencies, one per birth.*/	
		for (i = 1; i <= length(clUStEr); i++) {
			sEL       = selectindex(sET[.,1] :== clUStEr[i])                 /*Creates a subset of births (i.e., mothers living in the same cluster).*/
			F[sEL,i]  = J(rows(sEL),1,0)                                     /*Selected observations are excluded of that particular drawn (i.e., one-leave-out approach).*/
			}
		method        = "Jackknife, Clusters = " + strofreal(R)
		}
	
	/*Under-5 Mortality Estimation, Period Life Table (i.e., Lexis Squares)*/
	st_view(B = ., ., ("B_min","B_max"))                                     /*Extracts dates of birth.*/
	st_view(D = ., ., ("D_min","D_max"))                                     /*Extracts ages at death.*/
	st_view(W = ., ., "W")                                                   /*Extracts sampling weights.*/
	st_view(interview = ., ., "interview")                                   /*Extracts dates of interview.*/

	sEL           = selectindex(B[.,1] :~= .)                                /*Creates a subset of mothers (i.e., births are not missing).*/
	random        = uniform(length(sEL),R)                                   /*Generates random numbers to allocate variability to the date of birth, if exact dates are not available.*/
	B             = B[sEL,1] :+ floor(random:*(B[sEL,2] - B[sEL,1]))         /*Generates the exact date of birth.*/
	random        = uniform(length(sEL),R)                                   /*Generates random numbers to allocate variability to the exact age and date of death.*/
	D             = D/365.25                                                 /*Transforms reference ages at death from days to years.*/
	D             = D[sEL,1] :+ random:*(D[sEL,2] - D[sEL,1])                /*Generates the age at death in exact years.*/
	DoD           = B + D                                                    /*Generates the exact date of death.*/
		
	date          = interview[sEL]                                           /*Identifies the last time a birth is observed, starting by the date of the interview.*/
	S             = editmissing(DoD,0)                                       /*Replaces missing values (i.e., birth is still alive) with zero (i.e., if alive no modification is needed).*/
	DoD           = ((date :<= S):*date + (date :> S):*S):*(DoD:/DoD)        /*Takes the minimum between the date of the interview and the date of death.*/
	
	D             = (DoD - B):*(DoD - B :>= 0)                               /*Adjusts the age at death, if necessary.*/
	DoD           = B + D                                                    /*Adjusts the exact date of death, if necessary.*/
	S             = editmissing(DoD,max(date) + 10)                          /*Replaces missing values (i.e., birth is still alive) with an arbitrarily large quantity.*/
	O             = (date :<= S):*date + (date :> S):*S                      /*Takes the minimum between the date of the interview and the date of death, as exit date.*/	

	f             = F[sEL,.]                                                 /*Constraints the frequencies to the subset of mothers.*/
	W             = W[sEL]                                                   /*Constraints the sampling weights to the subset of mothers.*/		
	interview     = round(min(interview)*100)/100                            /*Defines the END of the lexis diagram, with two-digit precision.*/

	timeFRaMe     = range(interview - 5*T, interview, 5)                     /*Defines the cut-off points of the analytical periods to be estimated.*/
	ages          = ("0","7d","14d","21d","28d","2m","3m","4m","5m","6m","7m","8m","9m","10m","11m","12m","15m","18m","21m","24m","36m","48m","60m")'
	subsetages    = ((5,16,16,23,23)',(1,5,1,16,1)')                         /*Dedines a subset of ages to identify summary measures of under-5 mortality.*/
	subsetnames   = ("1. neonatal mortality rate, q(28d)","2. post-neonatal mortality rate, q(28d,12m)","3. infant mortality rate, q(12m)","4. child mortality rate, q(12m,60m)","5. under-5 mortality rate, q(60m)")'
	x             = (range(0,28,7)'/365.25,(range(2,12,1)',range(15,24,3)',range(36,60,12)')/12)'/*Defines the exact ages (i.e., cut-off points) of an under-5 life table (in year time).*/
	n             = x[2..length(x)] - x[1..length(x) - 1]                    /*Calculates the lenght of each age interval.*/
	nMx           = J((R + 1)*T,length(n),.)                                 /*Defines a matrix to allocate age-specific mortality rates.*/
	nMx_m         = J(rows(F),1,.)
	nMx_LB        = J(rows(F),1,.)
	nMx_UB        = J(rows(F),1,.)
	
	qx            = (J((R + 1)*T,1,0),J((R + 1)*T,length(n),.))              /*Defines a matrix to allocate cumulative probabilities of dying.*/
	qx_m          = J(rows(F),1,.)
	qx_LB         = J(rows(F),1,.)
	qx_UB         = J(rows(F),1,.)

	qs            = J((R + 1)*T,length(subsetnames),.)                       /*Defines a matrix to allocate summaryb measures of under-5 mortality.*/
	qs_m          = J(rows(F),1,.)
	qs_LB         = J(rows(F),1,.)
	qs_UB         = J(rows(F),1,.)
		
	mEThOd        = J(rows(F),1,"")
	period        = J(rows(F),1,"")
	AGES          = J(rows(F),1,"")
	Sages         = J(rows(F),1,"")
	X             = J(rows(F),1,.)
	N             = J(rows(F),1,.)

	for (j = 1; j <= T; j++) {                                               /*Calculates one life table per analytical period.*/
		sEL   = (1..(cols(F))) :+ cols(F)*(j - 1)'                           /*Defines a range for each period of analysis.*/
		sq    = (1..length(x)) :+ length(x)*(j - 1)'
		sm    = (1..length(n)) :+ length(x)*(j - 1)'
		ss    = (1..length(subsetnames)) :+ length(x)*(j - 1)'
		
		Alpha = timeFRaMe[j]                                                 /*Defines the BEGINNING of the Lexis Diagram.*/
		Omega = timeFRaMe[j + 1]                                             /*Defines the END of the Lexis Diagram.*/		
		for (i = 1; i < length(x); i++) {
			xL            = x[i]                                             /*Defines the BEGINNING of the age interval.*/
			xU            = x[i + 1]                                         /*Defines the END of the age interval.*/
			 
			S             = (O :<= Omega):*O + (O :> Omega):*Omega           /*Takes the minimum between the END of the Lexis Diagram and the last date of observation.*/
			Sa            = (B :+ xL :<= S):*(B :+ xL) + (B :+ xL :> S):*S   /*Uses geometry to find first and last time a life line intersects the Lexis square.*/ 
			So            = (B :+ xU :<= S):*(B :+ xU) + (B :+ xU :> S):*S
			a             = (Sa :>= Alpha):*Sa       + (Sa :< Alpha):*Alpha  /*Calculates the date of the first intersection.*/
			o             = (So :>= Alpha):*So       + (So :< Alpha):*Alpha  /*Calculates the date of the last intersection.*/
			
			Exposure      = colsum((o - a):*f:*W)'                           /*Calculates exposure.*/
			Events        = colsum((Alpha :<= DoD):*(DoD :< Omega):*(xL :<= D):*(D :< xU):*f:*W)' /*Calculates the number of events according to age and date, sampling weights, and BS/JK.*/
			nMx[sEL,i]    = Events:/Exposure                                 /*Calculates age-specific mortality rates (i.e., deaht s per person-years).*/
			qx[sEL,i + 1] = 1 :- (1 :- qx[sEL,i]):*exp(-n[i]*nMx[sEL,i])     /*Calculates the cumulative probability of dying.*/			
			}
			
		K             = qx[sEL,.] :> 0                                       /*Identifies resamples with positive probabilities of dying.*/
		qx_m[sq]      = exp(colsum(editmissing(ln(qx[sEL,.]),0))':/colsum(K)')/*Calculates the mean of qx for resamples with observed qx.*/
		qx_sd         = sqrt(colsum(editmissing((ln(qx[sEL,.]) :- ln(qx_m[sq]')):^2,0))':/(colsum(K) :- 1)')/*Calculates the standard deviation of qx.*/
		qx_se         = correction*qx_sd                                     /*Calculates the standard error of qx.*/
		qx_LB[sq]     = exp(ln(qx_m[sq]) :- qx_se*1.96)                      /*Calculates the standardised CIs, at 5% significance.*/
		qx_UB[sq]     = exp(ln(qx_m[sq]) :+ qx_se*1.96)                      /*Calculates the standardised CIs, at 5% significance.*/		
		
		K             = nMx[sEL,.] :> 0                                      /*Identifies resamples with positive mortality rates.*/
		nMx_m[sm]     = exp(colsum(editmissing(ln(nMx[sEL,.]),0))':/colsum(K)')/*Calculates the mean of nMx for resamples with observed nMx.*/
		nMx_sd        = sqrt(colsum(editmissing((ln(nMx[sEL,.]) :- ln(nMx_m[sm]')):^2,0))':/(colsum(K) :- 1)')/*Calculates the standard deviation of nMx.*/
		nMx_se        = correction*nMx_sd                                    /*Calculates the standard error of nMx.*/
		nMx_LB[sm]    = exp(ln(nMx_m[sm]) :- nMx_se*1.96)                    /*Calculates the standardised CIs, at 5% significance.*/
		nMx_UB[sm]    = exp(ln(nMx_m[sm]) :+ nMx_se*1.96)                    /*Calculates the standardised CIs, at 5% significance.*/
		
		qs[sEL,.]     = 1 :- (1 :- qx[sEL,subsetages[.,1]]):/(1 :- qx[sEL,subsetages[.,2]])/*Calculates summary measures of under-5 mortality*/
		K             = qs[sEL,.] :> 0                                       /*Identifies resamples with positive probabilities of dying.*/
		qs_m[ss]      = exp(colsum(editmissing(ln(qs[sEL,.]),0))':/colsum(K)')/*Calculates the mean of qs for resamples with observed qs.*/
		qs_sd         = sqrt(colsum(editmissing((ln(qs[sEL,.]) :- ln(qs_m[ss]')):^2,0))':/(colsum(K) :- 1)')/*Calculates the standard deviation of qs.*/
		qs_se         = correction*qs_sd                                     /*Calculates the standard error of qs.*/
		qs_LB[ss]     = exp(ln(qs_m[ss]) :- qs_se*1.96)                      /*Calculates the standardised CIs, at 5% significance.*/
		qs_UB[ss]     = exp(ln(qs_m[ss]) :+ qs_se*1.96)                      /*Calculates the standardised CIs, at 5% significance.*/
				
		mEThOd[sq]    = J(length(x),1,method)
		period[sq]    = J(length(x),1,strofreal(round(Alpha*100)/100) + " - " + strofreal(round(Omega*100)/100))/*Allocates results to the different outputs.*/
		AGES[sq]      = ages
		X[sq]         = x
		N[sm]         = n
		Sages[ss]     = subsetnames
		}
	
	st_store(., "qx_m", qx_m)                                                /*Transformes mata vectors to stata variables.*/
	st_store(., "qx_LB", qx_LB)
	st_store(., "qx_UB", qx_UB)
	st_store(., "nMx_m", nMx_m)
	st_store(., "nMx_LB", nMx_LB)
	st_store(., "nMx_UB", nMx_UB)
	st_store(., "qs_m", qs_m)
	st_store(., "qs_LB", qs_LB)
	st_store(., "qs_UB", qs_UB)	
	
	xn            = X + N
	st_sstore(., "method", mEThOd)
	st_sstore(., "period", period)
	st_sstore(., "ages", AGES)
	st_sstore(., "Sages", Sages)
	st_store(., "x", X)
	st_store(., "n", N)
	st_store(., "xn", xn)
	}
end                                                                          /*Closes MATA interface*/


cls
local      pATh         = "/Users/lshjr3/Documents/SARMAAN"                  /*Adjust path*/
tempfile   mAStEr
tempfile   temp
use      "`pATh'/DHS.dta", clear                                             /*Loads DHS data 9 10.*/

generate   survey       = "DHSVIII"
save      `temp', replace
keep if    State       == 9 | State == 10
replace    survey       = survey + "-Yobe"
append     using `temp'
save      `mAStEr', replace                                                  /*Tempfile used to append information from each survey.*/

use      "`pATh'/MICS.dta", clear                                            /*Loads MICS data 35.*/
generate   survey       = "MICS6"
save      `temp', replace
keep if    State       == 35
replace    survey       = survey + "-Yobe"
append     using `temp'
append     using `mAStEr'
save      `mAStEr', replace

use      "`pATh'/bASe.dta", clear                                            /*Loads SARMAAN data.*/
generate   bidx         = k*mother
generate   survey       = "SARMAAN-Yobe"
drop if    birth       == "miscarriage"  | birth       == "stillbirth"
generate   caseid       = cluster + " " + substr("0000000" + string(moTHer),-7,.)
drop       moTHer K k cluster
generate   cluster      = 1
generate   W            = 1

sort       cluster caseid B_min
bysort     cluster caseid: generate   k = _n
bysort     cluster caseid: generate   K = _N
generate   interview    = dofc(sTArt)
format     %tdDD/NN/CCYY interview
append     using `mAStEr'
 
local      lISt         = "survey caseid cluster mother bidx DOB_* B_* D_* W interview"
keep      `lISt'
order     `lISt'
save     "`pATh'/U5Mdata.dta", replace                                       /*Saves prepared data.*/

bysort     survey: generate   temp = _n
keep if    temp        == 1
keep       survey temp

local      lISt         = ""
forvalues s = 1(1)`=_N' {
	local      lISt         = "`lISt' " + survey[`s']
	}

clear
generate   survey       = ""
save      `mAStEr', replace                                                  /*Tempfile used to append information from each survey.*/
	
foreach survey of local lISt {
	use      "`pATh'/U5Mdata.dta", clear                                     /*Loads DHS prepared data.*/
	capt gen   survey         = "survey"	
	keep if    survey        == "`survey'"
	sort       caseid bidx                                                   /*Assumes a natural sort. The code of the mother and the code of each birth.*/
	bysort     caseid: generate   k = _n                                     /*Creates an index. One number per record of a woman.*/
	bysort     caseid: generate   K = _N                                     /*Creates an index. Total number of records per woman.*/
	sort       survey cluster caseid k
	generate   woman          = 1                                               if k     == 1
	bysort     cluster: egen       Women          = sum(woman)
	bysort     cluster: replace    woman          = sum(woman)	
	generate   w              = Women                                           if k     == 1 & woman == 1
	generate   iNDeX          = sum(w)
	replace    iNDeX          = iNDeX - Women
	drop       w
	
	local      sET            = "interview B_min B_max"
	foreach var of local sET {                                               /*Transforms dates from the stata format to exact dates using real numbers.*/
		format     %9.0g `var'
		replace   `var'           = year(`var') + (`var' - mdy(12,31,year(`var') - 1))/(mdy(12,31,year(`var')) - mdy(12,31,year(`var') - 1))
		}
	
	generate   method = "                                "                   /*Cerates empty spaces for life table variables.*/
	generate   period = "                 "
	generate   ages   = "   "
	generate   x      = .
	generate   n      = .
	generate   xn     = .
	generate   qx_m   = .
	generate   qx_LB  = .
	generate   qx_UB  = .
	generate   nMx_m  = .
	generate   nMx_LB = .
	generate   nMx_UB = .

	generate   Sages  = "                                        "
	generate   qs_m   = .
	generate   qs_LB  = .
	generate   qs_UB  = .
	
	mata       lIFeTaBLe(50,1,"B")                                           /*Invokes the mata function that makes the analytical work.*/
	keep       survey method period ages x n xn qx_* nMx_* Sages qs_*        /*Retains relevant variables.*/
	drop if    x     == .                                                    /*Reduces the range to include only the relevant observations.*/
	append     using `mAStEr'
	save      `mAStEr', replace                                              /*Saves the progress as a temporary file.*/
	}
	
save     "`pATh'/LifeTables.dta", replace                                    /*Saves Life Tables.*/

keep       survey method period Sages qs_m qs_LB qs_UB
drop if    Sages       == ""
sort       Sages survey
rename     qs_* *
local      lISt         = "m LB UB"
foreach var of local lISt {
	replace   `var'   = `var'*1000
}
format     %5.2f `lISt'
save     "`pATh'/SummaryTable.dta", replace                                    /*Saves a summary table.*/


cls
local      pATh         = "/Users/lshjr3/Documents/SARMAAN"         /*Adjust path*/
tempfile   mAStEr
use      "`pATh'/LifeTables.dta", clear
recode     qx_m qx_LB qx_UB (.=0)
replace    xn           = (x + xn)/2

generate   s            = survey + ": " + period
sort       s x
bysort     s: generate   k = _n
replace    k            = 0 if k > 1
replace    k            = sum(k)
save      `mAStEr', replace

local      K            = k[_N]
forvalues k = 1(1)`K' {
	use       `mAStEr', clear
	keep if    k     == `k'
	local      nOTe   = "95% CI, " + method[1]
	local      tITle  = s[1]
	local      fILe   = "`k'" + "-" + survey[1]
	twoway (line qx_m x, sort lcolor(blue)) (rcap qx_LB qx_UB x, sort lcolor(red)), legend(off) ytitle("q(x): cumulative probability of dying") xtitle("x: age in years") title("`tITle'") note("`nOTe'")
	*graph export "`pATh'/qx_`fILe'.png", replace
	twoway (line qx_m x, lcolor(blue)) (line qx_LB x, lcolor(blue) lwidth(thin) lpattern(dot)) (line qx_UB x, lcolor(blue) lwidth(thin) lpattern(dot)), legend(off) ytitle("q(x): cumulative probability of dying") xtitle("x: age in years") title("`tITle'") note("`nOTe'")
	graph export "`pATh'/qxA_`fILe'.png", replace
	twoway (line nMx_m xn, sort lcolor(blue)) (line nMx_LB xn, sort lcolor(blue) lwidth(thin) lpattern(dot)) (line nMx_UB xn, sort lcolor(blue) lwidth(thin) lpattern(dot)), yscale(log) legend(off) ytitle("nMx: age-specific mortality rates (log scale)") xtitle("x: age in years") title("`tITle'") note("`nOTe'")
	graph export "`pATh'/nMx_`fILe'.png", replace
	}
