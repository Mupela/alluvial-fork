*! alluvial v1.5 (27 Apr 2025):
*! Asjad Naqvi (asjadnaqvi@gmail.com)
*! Modified fork (IPA): adds valdec1, valnudge(#), sortsize(), mergeflows(), flowsort(). See README.

* IPA fork (2026): + sortsize - order nodes within each layer by size (largest at top) instead of
*                              alphabetically by label. Opt-in; omit it and ordering is unchanged.
*                  + flowsort - wire up the ribbon-stacking hook (stype2/srev2) that upstream
*                              declared but never set. flowsort(order|value [reverse]).
*                  + mergeflows - ribbons arriving at the named column(s) leave the source column
*                              as one merged river before splitting per destination node.
* IPA fork (2026): + valdec1  - whole number if |value|>=1, one decimal if <1 (flow values and category %).
*                  + valnudge(#) - push apart value labels that overlay each other where thin flows
*                                  converge on a narrow node; # is the min gap in plot y-units, 0=off.
*                  Both default off, so unmodified calls are unchanged. Search "IPA" in this file.
* IPA fork (2026): + stagen   - each column drawn as 100% of those who reached it; nodes labelled
*                              "Name (..%)" (% of column), flows as counts. Implies percent2.
*                              Default off.
* v1.5	(27 Apr 2025): reworked the baseline routines. better handling of missings.
* v1.42	(06 Mar 2025): fixed the program dropping missing values. fixed label wrapping for missing.
* v1.41	(11 Nov 2024): value(numvar) for a flow var. fixed string checks. if condition fixed.
* v1.4	(26 Sep 2024): valformat is now format(). wrap options added, labprop options added, novall, novalr options added.
* v1.3	(10 Feb 2024): Better control over category variables.
* v1.21 (19 Oct 2023): Fixed the showmiss bug (reported by Matthias Schonlau)
* v1.2  (04 Apr 2023): Minor fixes. If/in added back in.
* v1.1  (15 Jan 2023): fix label pass through. Weights added. offset added. valcond is just numeric. missing now has a color.
* v1.0  (10 Dec 2022): Beta release.        

cap program drop alluvial


program alluvial, sortpreserve

version 15
 
	syntax varlist [if] [in] [aw fw pw iw/],  ///
		[ value(varlist max=1 numeric) palette(string) colorby(string) smooth(numlist >=1 <=8 max=1) gap(real 2) RECENter(string) SHAREs showmiss alpha(real 75) ]  ///
		[ LABAngle(string) LABSize(string) LABPOSition(string) LABGap(string) SHOWTOTal  ] ///
		[ VALSize(string) format(string) VALGap(string) NOVALues  ]  ///
		[ LWidth(string) LColor(string)  ]  ///
		[ VALCONDition(real 0) offset(real 0) ]  ///  // v1.1
		[ BOXWidth(string) ] /// // v1.2 
		[ CATGap(real 4) CATSize(string) CATAngle(string) CATColor(string) CATPOSition(string) LABColor(string)  *  ]  ///   // v1.3 options
		[ WRAPLABel(numlist >0 max=1) wrapcat(numlist >0 max=1) valprop labprop valscale(real 0.33333) labscale(real 0.33333) n(real 30) NOVALLeft NOVALRight percent percent2 valdec1 valnudge(real 0) SORTSize(string) FLOWSort(string) MERGEFlows(string) PCTBase VALDEC(integer -1) stagen ]    // v1.4 updates + IPA: valdec1, valnudge, sortsize, flowsort, mergeflows, pctbase, valdec, stagen
		

	// check dependencies
	cap findfile colorpalette.ado
	if _rc != 0 {
		display as error "The {bf:palettes} package is missing. Install the {stata ssc install palettes, replace:palettes} and {stata ssc install colrspace, replace:colrspace} packages."
		exit
	}
	
	cap findfile labsplit.ado
		if _rc != 0 quietly ssc install graphfunctions, replace		
	
	marksample touse, strok novarlist
	
quietly {
preserve 	

	keep if `touse'   // do not enable. drops missing values.
	keep `varlist' `exp' `value'

	
	foreach x of local varlist {
	
		cap confirm numeric var `x' // check if numeric
	
		if _rc!=0 {  // if string, convert to numeric.
			encode `x', gen(`x'2)
			drop `x'
			ren `x'2 `x'
		}

		levelsof `x'

		if `r(r)' > 20 {
			di as error "Variable {it:`x'} has more than 20 categories. Either reduce the categories or drop the variable."
			exit
		}		
	}

	
	if "`novalleft'" != "" & "`novalright'" != "" {
		display as error "Both {it:novalleft} and {it:novalright} are not allowed. If you want to hide all values use the {it:novalues} option instead."
		exit 198
	}	
	
	if "`showmiss'" != "" & "`percent2'" != "" {
		display as error "Both {it:showmiss} & {it:percent2} are not allowed."
		exit 198
	}

	***** IPA addition: stagen *****
	***** Each column is drawn as 100% of the respondents who reached it, nodes are
	***** labelled "Name (..%)" (% of their column) and flows with their count, so
	***** the flows at each stage sum to the people at that stage. Builds on the
	***** percent2 machinery, so percent2 is switched on internally.
	if "`stagen'" != "" {
		if "`showmiss'" != "" {
			display as error "Both {it:showmiss} & {it:stagen} are not allowed."
			exit 198
		}
		local percent2 percent2
		local percent
		local shares
	}
	***** end IPA addition *****


	// store labels for later passthru
	foreach x of local varlist {
		if "`: var label `x''" != "" {
			local mylab`x' : var label `x'
		}
		else {
			local mylab`x' `x'
		}
	}
	
	
	gen temp = 1
	local varcount : word count `varlist'
	local items2 = `varcount' - 1

	
	tokenize `varlist'

	local obs = _N
	
	
	forval i = 1/`items2' {	
		
		local j = `i' + 1
		gen f`i' = ``i''	
		gen t`i' = ``j''	
			
		gen catf`i' = "``i''"
		gen catt`i' = "``j''"
		
	
		if "`: value label ``i'''" != "" {
			decode ``i'', gen(labf`i')
		}
		else {
			gen labf`i' = string(``i'')
		}
		
		if "`: value label ``j'''" != "" {
			decode ``j'', gen(labt`i')
		}
		else {
			gen labt`i' = string(``j'')
		}
			
	}
	
	drop `varlist'
	
	
	drop temp
	gen id = _n
	order id

	reshape long f t labf labt catf catt, i(id) j(layer)
	
	
	drop id
	
	sort layer f
	
	if "`value'" == "" {
		gen _value = 1
		local value _value
	}
	
	
	replace f = 99999 if missing(f)
	replace t = 99999 if missing(t)	
	

	if "`weight'" != "" local myweight  [`weight' = `exp']
	


	collapse (sum) `value' `myweight', by(f t layer labt labf catf catt)
	sort layer f t

	
	gen double _raw = `value'

	replace labf = "_missing" if f == 99999
	replace labt = "_missing" if t == 99999

	gen _mtag = 1 if f == 99999 | t == 99999

	***** IPA addition: stagen - report respondents who answer a later column but
	***** are missing in the earlier one. Their flow starts at a missing node, so it
	***** is never drawn, and the later column looks bigger than what fed it.
	if "`stagen'" != "" {
		forval _l = 1/`items2' {
			summ _raw if layer==`_l' & f==99999 & t!=99999, meanonly
			if r(N) > 0 {
				local _vf : word `_l' of `varlist'
				local _vt : word `=`_l'+1' of `varlist'
				noi di as txt "stagen note: column `_l'->`=`_l'+1': " %9.0gc r(sum) " obs have {it:`_vt'} but missing {it:`_vf'}; not drawn."
			}
		}
	}
	***** end IPA addition *****


	if "`shares'" != ""  {
		bysort layer: egen double _mysum = sum(`value')
		summ _mysum, meanonly
		replace `value' =  (`value' / `r(max)') 
	}
	
	if "`percent'" != "" {
		bysort layer: egen double _mysum = sum(`value')
		summ _mysum, meanonly
		replace `value' =  (`value' / `r(max)') * 100
	}
	
	
	if "`percent2'" != "" {
		bysort layer: egen double _mysum  = sum(`value') 
		bysort layer: egen double _mysum2 = sum(`value') if missing(_mtag) // for labels only
		
		gen double _pct2 = (`value' / _mysum2) * 100
		replace    `value' = (`value' / _mysum) * 100

	}
	


	if "`format'" == "" {
		if "`shares'"!="" | "`percent'"!="" | "`percent2'"!="" {
			local format "%4.2f"	
		}
		else {
			local format "%12.0fc"	
		}
	}		
	


	**** SANKEY ROUTINE BELOW

	ren layer x1
	summ x1, meanonly
	replace x1 = x1 - r(min) // rebase to 0

	gen x2 = x1 + 1
	
	ren `value' val1
	gen val2 = val1
	
	
	if "`percent2'" != "" {
		gen double _pct1 = _pct2
		
		local pctlist _pct
	
	}

	
	ren catf cat1
	ren catt cat2
	
	ren labf lab1
	ren labt lab2


	sort x1 f t  // this affects the draw order

	gen id = _n
	order id

	egen grp1 = group(x1 f)  // draw order
	egen grp2 = group(x1 t)

	sort x1 grp1 grp2
	by x1:	gen  double y1	= sum(val1) 
	
	sort x2 grp2 grp1
	by x2: 	gen  double y2	= sum(val2) 

	sort x1 f t

	gen layer = x1 + 1
	
	ren f flo1
	ren t flo2
		
	reshape long x flo val `pctlist' grp y cat lab, i(id layer) j(marker)
	*drop tt


	ren lab var
	
	// variable type check
	
	if substr("`: type var'",1,3) != "str" {
		if "`: value label var '" != "" { 	// has value label
			decode var, gen(name)
		}
		else {								// has no value label
			gen name = string(var)
		}
	}
	else {
		cap ren var name
		encode name, gen(var) // alphabetical organization
	}	
	


	
	**** from sankey	
	
	gen layer2 = layer
	replace layer2 = layer2 + 1 if marker==2

	***** IPA addition: stagen - per-column scaling *****
	***** layer2 is the column number here. _nraw = node n = max(in, out) over flows
	***** with no missing end; _colN = column N = sum of node n. Boxes are sized as
	***** % of their column (so every column totals 100) and ribbons as % of column 1,
	***** both on the same non-missing base so they no longer disagree.
	if "`stagen'" != "" {
		tempvar _ro _ri _ntg
		bysort layer2 var: egen double `_ro' = sum(cond(marker==1 & missing(_mtag), _raw, 0))
		bysort layer2 var: egen double `_ri' = sum(cond(marker==2 & missing(_mtag), _raw, 0))
		gen double _nraw = max(`_ri', `_ro')
		egen `_ntg' = tag(layer2 var)
		bysort layer2: egen double _colN = sum(_nraw * `_ntg')   // missing node has _nraw = 0

		* report item non-response: a node that passes some people on to the next
		* column but fewer than came in (those with a missing next answer are not
		* drawn). Nodes that pass nobody on (e.g. skip patterns) are not reported.
		tempvar _drop
		gen byte `_drop' = `_ntg'==1 & `_ri' > 0 & `_ro' > 0 & `_ro' < `_ri'
		count if `_drop'
		if r(N) > 0 {
			local _nd = r(N)
			gsort -`_drop' layer2 var
			forval _k = 1/`_nd' {
				noi di as txt "stagen note: column " layer2[`_k'] " {it:" name[`_k'] "}: " %9.0gc `_ri'[`_k'] - `_ro'[`_k'] " of " %9.0gc `_ri'[`_k'] " missing in the next column; not drawn."
			}
		}
		drop `_drop'

		forval _c = 1/`varcount' {
			summ _colN if layer2==`_c', meanonly
			local _cN`_c' = r(max)
		}
		gen double _basepct = _raw / `_cN1' * 100

		* boxes (height2, from _pct) = % of their own column, as under percent2;
		* ribbons (stacked from val)  = % of all respondents, as under percent2.
		replace _pct = _raw / _colN * 100
		replace val  = _basepct
		drop `_ro' `_ri' `_ntg'
	}
	***** end IPA addition *****


	sort layer2 var marker


	if "`percent2'" != "" {
		bysort layer2 var: egen double val_out_temp2 = sum(_pct) if marker==1 & missing(_mtag) // how much value is sent out
		bysort layer2 var: egen double val_in_temp2  = sum(_pct) if marker==2 & missing(_mtag) // how many value comes in
		
		bysort layer2 var: egen double val_out2 = max(val_out_temp2)  if missing(_mtag)
		bysort layer2 var: egen double val_in2  = max(val_in_temp2)   if missing(_mtag)
	
		drop *temp2
		recode val_in2 val_out2 (.=0)
	

		egen double height2 = rowmax(val_in2 val_out2) if missing(_mtag)
	}


	
	
	bysort layer2 var: egen double val_out_temp = sum(val) if marker==1 // how much value is sent out
	bysort layer2 var: egen double val_in_temp  = sum(val) if marker==2 // how many value comes in
	
	bysort layer2 var: egen double val_out = max(val_out_temp)
	bysort layer2 var: egen double val_in  = max(val_in_temp)
	
	drop *temp
	recode val_in val_out (.=0)
	
	egen double height = rowmax(val_in val_out) // this is the maximum height for each category for each group.

	drop val_in* val_out*
	


	// layer order
	*labmask flo, val(name)
	drop var
	ren flo var

	***** IPA addition: sortsize *****
	***** Node order within a layer is otherwise the alphabetical order of the
	***** label ("encode name" further up feeds flo, which becomes var here, and
	***** "order" below is just a running count over sorted var). sortsize
	***** re-codes var as a within-layer rank of node size, so the biggest node
	***** draws at the top and the smallest at the bottom. It must sit AFTER
	***** "ren flo var" (which discards the earlier var) and AFTER height is
	***** built, but BEFORE order/bar_order are derived. var is only ever used as
	***** a within-layer node key from here on, so re-coding it is safe.
	*****
	***** sortsize(all)  - size-order every column
	***** sortsize(3)    - size-order only the 3rd column
	***** sortsize(2 3)  - size-order the 2nd and 3rd columns
	***** Column numbers are positions in the varlist, counting from 1.
	***** Off by default: without the option nothing changes.
	if "`sortsize'" != "" {
		tempvar ntag nrank nrank2 newvar
		sort layer2 var
		egen byte `ntag' = tag(layer2 var)

		* ascending height -> largest node gets the largest code, and high codes
		* draw at the top, so the largest node lands at the top.
		sort layer2 height var
		by layer2: gen long `nrank' = sum(`ntag')
		bysort layer2 var: egen long `nrank2' = max(`nrank')

		gen long `newvar' = var
		if lower(trim("`sortsize'")) == "all" {
			replace `newvar' = `nrank2'
		}
		else {
			cap numlist "`sortsize'", integer range(>0)
			if _rc {
				di as error "sortsize() takes {it:all} or a list of column numbers, e.g. sortsize(3) or sortsize(2 3)."
				exit 198
			}
			foreach _sl of numlist `sortsize' {
				replace `newvar' = `nrank2' if layer2 == `_sl'
			}
		}

		drop var
		gen long var = `newvar'
		drop `ntag' `nrank' `nrank2' `newvar'
	}
	***** end IPA addition *****

	gsort layer2  var id
		
	egen tag2 = tag(layer2 var)
	by layer2 : gen order = sum(tag2) // take it as it is
	cap drop tag2
			
	
	// bar order
	egen temp = tag(layer2 var)
	gen bar_order = sum(temp)
	drop temp

	
	if "`percent2'" != "" {
		egen _pct2tag = tag(x name)
		bysort x: egen _pct2total = sum(height) if _pct2tag==1 & missing(_mtag)

		***** IPA addition: pctbase *****
		***** By default percent2 shows each node as a share of ITS OWN column.
		***** The flow values, meanwhile, are shares of the overall base. Mixing
		***** the two denominators on one plot means the printed node percentages
		***** and the printed flow values cannot be added together, and a column
		***** whose inflow is only part of the previous column silently renormalises
		***** to 100%. pctbase puts the node percentages on the SAME denominator as
		***** the flow values (the first column's total, i.e. the base), so flows
		***** into a node sum to that node's percentage and node percentages sum to
		***** the share of the base that reached the column.
		***** This is label-only: height3 is used nowhere except the box labels, so
		***** bar geometry is untouched. Off by default.
		if "`pctbase'" != "" {
			summ x, meanonly
			local _firstx = r(min)
			summ _pct2total if x==`_firstx', meanonly
			local _basetot = r(max)
			if `_basetot' > 0 {
				gen double height3 = (height / `_basetot') * 100
			}
			else {
				gen double height3 = (height / _pct2total) * 100
			}
		}
		else {
			gen double height3 = (height / _pct2total) * 100
		}
		***** end IPA addition *****
	}
	
	
	
	
	
	*****************************
	**** generate the boxes   ***
	*****************************

	egen tag = tag(layer2 height order)
	sort layer2 tag order

	
	
	if "`percent2'" == "" {
		by layer2: gen double heightsum = sum(height) if tag==1 
	}
	else {
		by layer2: gen double heightsum = sum(height2) if tag==1 & missing(_mtag) 
	}

	

	
	// gen spike coordinates
	bysort layer2: gen double y1 = heightsum[_n-1] if tag==1  // 
	recode y1 (.=0)  if tag==1
	gen double y2 = heightsum

	
	if "`percent2'" != "" {
		bysort layer2: egen double _max = max(y2) if tag==1 
		replace y1 = (y1 / _max) * 100
		replace y2 = (y2 / _max) * 100
		
		drop _max
	}
	
	*** control missing

	if "`showmiss'" == "" | "`percent2'" != ""  {
		replace y1 = . if _mtag==1
		replace y2 = . if _mtag==1
	}
	
	
	*** add gap

	tempvar mygap
	summ heightsum if tag==1, meanonly
	local maxval = r(max) * `gap' / 100  
	gen `mygap' = (order - 1) * `maxval' if tag==1 

	replace y1 = y1 + `mygap'
	replace y2 = y2 + `mygap'

	cap drop heightsum

	

			
	*************************
	** generate the links  **
	*************************

	gen markme = .
	
	sort layer2 var markme marker  

	// marker = 1 = outgoing
	// marker = 2 = incoming

	//////////////////////
	///  second sort   ///
	//////////////////////

	
	***** IPA addition: flowsort *****
	***** stype2 / srev2 drive the ribbon stacking order in the block just below,
	***** but upstream nothing ever set them, so the branch was frozen on the
	***** "order" default. flowsort() wires them up:
	*****   flowsort(order)           - default, stack ribbons by node order
	*****   flowsort(value)           - stack ribbons by size, so thick ribbons
	*****                               group together and thin ones stop
	*****                               criss-crossing the middle of the plot
	*****   flowsort(order reverse)   - either of the above, flipped
	*****   flowsort(value reverse)
	if "`flowsort'" != "" {
		local stype2 : word 1 of `flowsort'
		local srev2  : word 2 of `flowsort'
		if !inlist("`stype2'", "order", "value") {
			di as error "flowsort() takes {it:order} or {it:value}, optionally followed by {it:reverse}."
			exit 198
		}
		if "`srev2'" != "" & "`srev2'" != "reverse" {
			di as error "The second word of flowsort() may only be {it:reverse}."
			exit 198
		}
	}
	***** end IPA addition *****

	if "`stype2'"=="" | "`stype2'"=="order" {
		if "`srev2'" == "reverse" {
			local ssort2 -id // by order	
		}
		else {
			local ssort2 id // by order	
		}
		 
	}
	if "`stype2'"=="value" {
		if "`srev2'" == "reverse" {
			local ssort2 -val // by value	
		}
		else {
			local ssort2 val // by value	
		}
	}
	

	if "`showmiss'" == "" drop if _mtag == 1
	
	
	gsort layer2 marker var markme `ssort2'   // this determines the second sort

	by layer2 marker var: gen double stack_end   = sum(val) 		  if markme!=1
	by layer2 marker var: gen double stack_start = stack_end[_n - 1]  if markme!=1
	recode stack_start (.=0) if markme!=1	

	
	
	levelsof layer2, local(lvls)

	foreach x of local lvls {

		// outgoing levels
		levelsof var if layer2==`x' & marker==1, local(vars)
		
		foreach y of local vars {
			summ y1 if layer2==`x' & var==`y', meanonly
			local ymin = r(min)
			summ y2 if layer2==`x' & var==`y', meanonly
			local ymax = r(max)
			
			summ stack_end if layer2==`x' & var==`y' & marker==1, meanonly
			local smax = r(max)
			
			local displace = ((`ymax' - `ymin') - `smax' ) / 2
		
			replace stack_start = stack_start + `ymin' + `displace' if layer2==`x' & marker==1 & var==`y'
			replace stack_end   = stack_end   + `ymin' + `displace' if layer2==`x' & marker==1 & var==`y'
			
		}
		
		// incoming levels
		levelsof var if layer2==`x' & marker==2, local(vars)
		
		foreach y of local vars {
			summ y1 if layer2==`x' & var==`y', meanonly
			local ymin = r(min)
			summ y2 if layer2==`x' & var==`y', meanonly
			local ymax = r(max)
			
			summ stack_end if layer2==`x' & var==`y' & marker==2 , meanonly
			local smax = r(max)
			
			local displace = ((`ymax' - `ymin') - `smax' ) / 2
			
			replace stack_start = stack_start + `ymin' + `displace' if layer2==`x' & marker==2 & var==`y'
			replace stack_end   = stack_end   + `ymin' + `displace' if layer2==`x' & marker==2 & var==`y'
			
		}
	}


	***** IPA addition: mergeflows *****
	***** Normally every ribbon leaves from its own source box, so a column of
	***** many small nodes feeding a column of few nodes produces a spray of thin
	***** criss-crossing ribbons. mergeflows(#) rebuilds the ribbons arriving at
	***** column # so that, on the outgoing side, the WHOLE source column is
	***** stacked as one contiguous block ordered by destination. The result
	***** leaves the source column as a single river which then breaks into one
	***** stream per destination node, with no crossing.
	*****
	***** mergeflows(4)    - flows arriving at column 4 form one river
	***** mergeflows(3 4)  - do it for more than one transition
	*****
	***** Values, node heights and percentages are untouched - this only moves
	***** the ribbon endpoints. Note the river is centred on the source column's
	***** full extent, so individual ribbons no longer line up with the box they
	***** came from: that is the point of the option, but it does mean the
	***** source-to-destination linkage is no longer readable off the picture.
	***** Must run AFTER the per-node anchoring loop above and BEFORE stack_x.
	if "`mergeflows'" != "" {
		cap numlist "`mergeflows'", integer range(>1)
		if _rc {
			di as error "mergeflows() takes a list of column numbers greater than 1, e.g. mergeflows(4)."
			exit 198
		}

		foreach _mf of numlist `mergeflows' {
			local _src = `_mf' - 1

			tempvar tvar mcum
			* destination node of each flow (the marker==2 end of the same flow)
			bysort id layer: egen double `tvar' = max(cond(marker==2, var, .))

			* full vertical extent of the source column
			summ y1 if layer2==`_src', meanonly
			local _ymin = r(min)
			summ y2 if layer2==`_src', meanonly
			local _ymax = r(max)

			* One contiguous stack for the whole source column, ordered by
			* destination so same-destination ribbons sit together, centred on the
			* column. Ribbon thickness stays on the ado's normal flow scale, so
			* the river is directly comparable to every other ribbon on the plot.
			sort layer2 marker `tvar' id
			by layer2 marker: gen double `mcum' = sum(val) if layer2==`_src' & marker==1

			summ `mcum' if layer2==`_src' & marker==1, meanonly
			local _smax = r(max)

			if `_smax' < . & `_ymin' < . & `_ymax' < . {
				local _disp = ((`_ymax' - `_ymin') - `_smax') / 2
				replace stack_end   = `mcum'       + `_ymin' + `_disp' if layer2==`_src' & marker==1
				replace stack_start = `mcum' - val + `_ymin' + `_disp' if layer2==`_src' & marker==1
			}

			drop `tvar' `mcum'
		}
	}
	***** end IPA addition *****


	gen stack_x = layer2
	sort layer2 markme id
	
	
	// mark the highest value and the layer

	summ y2, meanonly
	local hival = r(max)
	
	// recenter
	
	*** recenter to middle

	levelsof layer2, local(lvls)		
			
	foreach x of local lvls {
		
		qui summ y1 if layer2==`x', meanonly
		local ymin = r(min)
		qui summ y2 if layer2==`x', meanonly
		local ymax = r(max)
		
		if "`recenter'" == "bottom" | "`recenter'" == "bot"  | "`recenter'" == "b" { 		
			local displace = cond(`ymin' < 0, `ymin' * -1, 0)
		}
			
		if "`recenter'" == "" | "`recenter'" == "middle" | "`recenter'" == "mid"  | "`recenter'" == "m" { 
			local displace = (`hival' - `ymax') / 2
		}
			
		if "`recenter'" == "top" | "`recenter'" == "t"  {
			local displace = `hival' - `ymax'
		}		
		
		replace y1 = y1 + `displace' if layer2==`x'
		replace y2 = y2 + `displace' if layer2==`x'
		
		replace stack_end   = stack_end   + `displace' if layer2==`x'
		replace stack_start = stack_start + `displace' if layer2==`x'		
	}
	
	
	*** generate the curves	
	

	local newobs = `n'	
	expand `newobs'
	sort id layer2
	
	tempvar xtemp ytemp

	bysort id: gen double `xtemp' =  (_n / (`newobs' * 2))

	
	if "`smooth'" == "" local smooth = 4
	
	gen double `ytemp' =  (1 / (1 + (`xtemp' / (1 - `xtemp'))^-`smooth'))

	gen archi = .
	gen arclo = .

	
	levelsof layer	, local(cuts)
	levelsof id		, local(lvls)

	foreach x of local lvls {   // each id is looped over

		foreach y of local cuts {

			summ `ytemp' if id==`x' & layer==`y'
		
			
			// x-coordinates
			local ymin = cond(r(N) > 0, r(min), 0)
			local ymax = cond(r(N) > 0, r(max), 0)
			
			summ layer2 if layer==`y', meanonly
				local x0 = r(min)
				local x1 = r(max)

			
			// left y values
			summ stack_start if id==`x' & layer2==`x0' & layer==`y', meanonly
			local y1min = cond(r(N) > 0, r(min), 0)
							
			summ stack_start if id==`x' & layer2==`x1' & layer==`y', meanonly
			local y1max = cond(r(N) > 0, r(max), 0)			
			
			
			replace archi = (`y1max' - `y1min') * (`ytemp' - `ymin') / (`ymax' - `ymin') + `y1min' if id==`x' & layer==`y'
			
			
			// right y values
			summ stack_end if id==`x' & layer2==`x0' & layer==`y', meanonly
			local y2min = cond(r(N) > 0, r(min), 0)
			
			summ stack_end if id==`x' & layer2==`x1' & layer==`y', meanonly
			local y2max = cond(r(N) > 0, r(max), 0)	
			
			replace arclo = (`y2max' - `y2min') * (`ytemp' - `ymin') / (`ymax' - `ymin') + `y2min' if id==`x' & layer==`y'
			
		}
	}

	gen arcx = `xtemp' + layer


		
	***** mid points for wedges
	egen tag_spike = tag(layer2 var tag)
	gen double ymid = (y1 + y2) / 2 if tag_spike==1
	
	
	***** mid points for sankey labels
	egen tag_id = tag(id marker)
	gen double arcmid = (stack_end + stack_start) / 2 if tag_id==1
	
	egen layer_id = group(layer2) // layer id for coloring

	***** IPA: vertical de-collision for value labels.
	***** When several thin flows meet at one node their arc-midpoints nearly
	***** coincide and the value labels overlay each other. _laby greedily pushes
	***** them apart to a minimum gap of `valnudge' (in plot y-units) within each
	***** layer x marker, using the spare height of the (tall) node bar. The flows
	***** themselves are unchanged; only the label anchor moves. valnudge(0)=off.
	gen double _laby = arcmid
	if `valnudge' > 0 {
		tempvar _lord _origord
		gen long `_origord' = _n   // preserve draw order: arcs/rarea rely on row order
		bysort layer2 marker (arcmid): gen `_lord' = _n if tag_id==1
		sort layer2 marker `_lord'
		by layer2 marker: replace _laby = max(arcmid, _laby[_n-1] + `valnudge') if tag_id==1 & _n > 1
		sort `_origord'            // restore draw order so ribbons render correctly
	}


	// wrappers

	
	
	// define all the locals before drawing
	
	if "`lcolor'"       == "" local lcolor black
	if "`labcolor'"     == "" local labcolor black
	if "`lwidth'"       == "" local lwidth 0.02	
	if "`colorvarmiss'" == "" local colorvarmiss gs12
	if "`labangle'" 	== "" local labangle 90
	if "`labsize'"  	== "" local labsize 2	
	if "`labposition'"  == "" local labposition 0	
	if "`labgap'" 		== "" local labgap 0
	if "`valsize'"  	== "" local valsize 1.5
	if "`valgap'" 	 	== "" local valgap 2
	if "`boxwidth'"    	== "" local boxwidth 3.2
	if "`colorboxmiss'" == "" local colorboxmiss gs10
	
	if "`format'" 		== "" {
		if "`percent'" != "" | "`percent2'" != "" {
			local format "%5.2f"
		}
		else {
			local format "%12.0f"
		}
	}
	
	format val `format'	
	
	
	if "`colorby'" == "layer" | "`colorby'" == "level" {
		local switch 1
	}
	if "`colorby'"  == "" local switch 0		
	if "`colorvar'" != "" local switch 2	
	
	if "`palette'" == "" {
		local palette tableau
	}
	else {
		tokenize "`palette'", p(",")
		local palette  `1'
		local poptions `3'
	}	
	
	
	
	// draw bars
	
	
	encode name, gen(name2)
	
	local bars
	
	if `switch'==0 {
		levelsof name2, local(lvls)
		local items = r(r)
		
		colorpalette `palette' , n(`items') nograph `poptions'
		foreach x of local lvls {			
			local bars `bars' (rspike y2 y1 layer2 if name2==`x' & tag==1 & tag_spike==1, lw(`boxwidth')  lc("`r(p`x')'")) 
		}	
	}
	
	if `switch'==1 {
		levelsof layer_id, local(lvls)
		local items = r(r)
		
		colorpalette `palette' , n(`items') nograph `poptions'
		foreach x of local lvls {	
			local bars `bars' (rspike y2 y1 layer2 if layer_id==`x' & tag==1 & tag_spike==1, lw(`boxwidth')  lc("`r(p`x')'")) 
		}
	}
	
	if `switch'==2 {

		levelsof clrlvl
		local items = r(r)
		
		levelsof bar_order, local(lvls)
		foreach x of local lvls {			
			
			summ clrlvl if bar_order==`x' , meanonly
			
			if r(max) > 0 {
				local clr = r(max)
				colorpalette `palette' , n(`items') nograph `poptions'
				local myclr  `r(p`clr')'
			}
			else {
				local myclr  `colorboxmiss'
			}
			
			local bars `bars' (rspike y2 y1 layer2 if bar_order==`x' & tag==1 & tag_spike==1, lw(`boxwidth')  lc("`myclr'")) 
		}			
			
	}

	
	// draw arcs
	
	local shapes
	
	levelsof id if markme!=1, local(lvls)

	foreach x of local lvls {
		
		if `switch'==0 {
			summ name2 if id==`x' & marker==1, meanonly
		}
		if `switch'==1 {
			summ layer_id if id==`x' & marker==1, meanonly
		}
		if `switch'==2 {		 	// by layer
			sum clrlvl if id==`x' & tag_id==1, meanonly
		}		
		
		
		if r(N) > 0 {
			local clr = r(mean)
			
			if `clr' > 0 {
				colorpalette `palette' , n(`items') nograph `poptions'
				local myclr  `r(p`clr')'
			}
			else {
				local myclr  `colorvarmiss'
			}
		
		
			local shapes `shapes' (rarea archi arclo arcx if id==`x', lc(`lcolor') lw(`lwidth') fi(100) fcolor("`myclr'%`alpha'") ) 
		}
	}
	
		
	
	**** box labels
	
	if "`nolabels'" == "" {
		if "`stagen'" != "" {   // IPA: "Name (17%)" as under percent2, % of the node's own column
			gen double _npct = _nraw / _colN * 100
			_alluvial_pctstr _npctS _npct `valdec' `valdec1'
			gen lab2 = name + cond("`showtotal'" != "", " (" + _npctS + "%)", "") if tag_spike==1
		}
		else if "`showtotal'" != "" {
			if "`percent'" != "" { 
				gen lab2 = name + " (" + string(height, "`format'") + "%)" if tag_spike==1
			}
			else if "`percent2'" != "" {
				if `valdec' >= 0 {   // IPA: fixed number of decimals everywhere
					gen lab2 = name + " (" + strtrim(string(height3, "%20.`valdec'f")) + "%)" if tag_spike==1
				}
				else if "`valdec1'" != "" {   // IPA: whole number if >=1, one decimal if <1
					gen lab2 = name + " (" + strtrim(cond(abs(height3) < 1, string(height3, "%3.1f"), string(height3, "%9.0f"))) + "%)" if tag_spike==1
				}
				else {
					gen lab2 = name + " (" + string(height3, "`format'") + "%)" if tag_spike==1
				}
			}
			else {
				gen lab2 = name + " (" + string(height, "`format'") + ")" if tag_spike==1
			}
		}
		else {
			gen lab2 = name if tag_spike==1
		}
		

		if "`wraplabel'" != "" {
			ren lab2 lab2_temp
			labsplit lab2_temp, wrap(`wraplabel') gen(lab2)
			drop lab2_temp	
		}			
		
		replace lab2 = subinstr(lab2, "_missing", "{it:missing}", .)
		
		if "`labprop'" != "" {
			summ height if tag_spike==1, meanonly
			gen labwgt = `labsize' * (height / r(max))^`labscale' if tag_spike==1
			
			tempvar _lablyr
			egen `_lablyr' = group(id layer2) if tag_spike==1  // to prevent duplicates names
			
			levelsof `_lablyr', local(lvls)
			
			foreach x of local lvls {
				summ labwgt if `_lablyr'==`x' & tag_spike==1 & ymid!=., meanonly
				local labw = r(max)
				
				local boxlabel `boxlabel' (scatter ymid layer2 if tag_spike==1 & `_lablyr'==`x' & height > `valcondition',  msymbol(none) mlabel(lab2) mlabsize(`labw') mlabpos(`labposition') mlabgap(`labgap') mlabangle(`labangle') mlabcolor(`labcolor')) 
			}
		}
		else {
			local boxlabel (scatter ymid layer2 if tag_spike==1  & height > `valcondition',  msymbol(none) mlabel(lab2) mlabsize(`labsize') mlabpos(`labposition') mlabgap(`labgap') mlabangle(`labangle') mlabcolor(`labcolor')) 
		}	
	}	

	
	local flowval val

	if "`percent'" != "" {
		gen valper = string(val, "`format'") + "%" if (marker==1 | marker==2)
		local flowval valper
	}

	if "`stagen'" != "" {   // IPA: flow n (count), so flows sum to the column N
		gen _vlab = cond(missing(_raw), "", strtrim(string(_raw, "%12.0fc"))) if (marker==1 | marker==2)
		local flowval _vlab
	}
	else if `valdec' >= 0 {   // IPA: fixed number of decimals everywhere, so printed
		                 // flow values add up instead of drifting with mixed rounding
		gen _vlab = cond(missing(val), "", strtrim(string(val, "%20.`valdec'f"))) if (marker==1 | marker==2)
		* IPA: upstream only ever appends "%" under percent, so percent2 printed
		* percentages as bare numbers that read as counts. Appended here too.
		* Confined to the valdec() branch so charts using valdec1 are unchanged.
		if "`percent'" != "" | "`percent2'" != "" replace _vlab = _vlab + "%" if !missing(_vlab)
		local flowval _vlab
	}
	else if "`valdec1'" != "" {   // IPA: whole number if >=1, one decimal if <1
		gen _vlab = cond(missing(val), "", strtrim(cond(abs(val) < 1, string(val, "%3.1f"), string(val, "%9.0f")))) if (marker==1 | marker==2)
		if "`percent'" != "" replace _vlab = _vlab + "%" if !missing(_vlab)
		local flowval _vlab
	}


	**** arc labels
	
	if "`valprop'" != "" {
		summ val if tag==1, meanonly
		gen valwgt = `valsize' * (val / r(max))^`valscale' if tag_id==1
	}
	else {
		gen valwgt = 1 if tag_id==1
	}	
	
	if "`novalues'" == "" {
		if "`valprop'" == "" {
			
			if  "`novalleft'" == "" {
				local values `values' (scatter _laby layer2  if val >= `valcondition' & marker==1, msymbol(none) mlabel(`flowval') mlabsize(`valsize') mlabpos(3) mlabgap(`valgap') mlabcolor(`labcolor'))
			}

			if  "`novalright'" == "" {
				local values `values' (scatter _laby layer2  if val >= `valcondition' & marker==2, msymbol(none) mlabel(`flowval') mlabsize(`valsize') mlabpos(9) mlabgap(`valgap') mlabcolor(`labcolor'))
			}
		}
		else {
			
			levelsof id, local(lvls)
			
			foreach x of local lvls {
				summ valwgt if id==`x', meanonly
				local valw = r(mean)
			
				if  "`novalleft'" == "" {
					local values `values' (scatter _laby layer2 if val >= `valcondition' & id==`x' & marker==1, msymbol(none) mlabel(`flowval') mlabsize(`valw') mlabpos(3) mlabgap(`valgap') mlabcolor(`labcolor'))
				}

				if  "`novalright'" == "" {
					local values `values' (scatter _laby layer2 if val >= `valcondition' & id==`x' & marker==2, msymbol(none) mlabel(`flowval') mlabsize(`valw') mlabpos(9) mlabgap(`valgap') mlabcolor(`labcolor'))
				}
			}
		}		
	}
	
	
	**** level titles
	
	if "`catsize'"		== "" local catsize 2.3	
	if "`catposition'"	== "" local catposition 0
	if "`catcolor'"		== "" local catcolor black
	if "`catangle'"		== "" local catangle 0		
	
	summ stack_end, meanonly
	local _ctgap = `r(max)' * `catgap' / 100
	
		
	gen _ctlab = ""
	gen _cty   = 0 - `_ctgap' in 1/`varcount'
	gen _ctx   = .
	
	local i = 1
	
	foreach x of local varlist {
		replace _ctlab =  "`mylab`x''" in `i'
		replace _ctx = `i'  in `i'
		
		local ++i
	}
	
	
	if "`wrapcat'" != "" {
		ren _ctlab _ctlab2
		labsplit _ctlab2, wrap(`wrapcat') gen(_ctlab)
	}		
	
	
	// offset	
	summ layer2, meanonly
	local xrmin = r(min)
	local xrmax = r(max) + ((r(max) - r(min)) * `offset' / 100)

	// IPA: stagen - headroom so a label nudged above the top bar is not clipped
	local yscl yscale(off)
	if "`stagen'" != "" {
		summ y2, meanonly
		local _yhi = r(max)
		summ _laby, meanonly
		local _yhi = max(`_yhi', r(max))
		summ _cty, meanonly
		local _yhi = max(`_yhi', r(max)) * 1.04
		summ y1, meanonly
		local yscl yscale(off range(`r(min)' `_yhi'))
	}

	**** PLOT EVERYTHING ***
	
	twoway 			///
		`shapes' 	///
		`bars' 		///
		`boxlabel' 	///
		`values'  	///
		(scatter _cty _ctx , msymbol(none) mlabel(_ctlab) mlabsize(`catsize') mlabpos(`catposition') mlabcolor(`catcolor') mlabangle(`catangle')) ///
			, 		///
				legend(off) 										 ///
					xlabel(, nogrid) ylabel(0 `yrange' , nogrid)     ///
					xscale(off range(`xrmin' `xrmax')) `yscl'	 ///
					`options'
		
*/

restore
}	


end


* IPA: percentage -> string, following valdec(#) / valdec1, else whole numbers
cap program drop _alluvial_pctstr
program _alluvial_pctstr
	args newvar src valdec valdec1
	if `valdec' >= 0 {
		gen `newvar' = strtrim(string(`src', "%20.`valdec'f"))
	}
	else if "`valdec1'" != "" {
		gen `newvar' = strtrim(cond(abs(`src') < 1, string(`src', "%3.1f"), string(`src', "%9.0f")))
	}
	else {
		gen `newvar' = strtrim(string(`src', "%9.0f"))
	}
	replace `newvar' = "" if missing(`src')
end


*********************************
******** END OF PROGRAM *********
*********************************



