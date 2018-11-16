// ==UserScript==
// @name        Reacreation.gov Autorefresh
// @namespace   http://www.rockittech.com
// @description Try to auto grab campsite
// @include     http://www.recreation.gov/camping/*
// @include     https://www.recreation.gov/camping/*
// @include     http://www.recreation.gov/campsiteSearch.do*
// @include     https://www.recreation.gov/campsiteSearch.do*
// @include     http://www.recreation.gov/campsiteCalendar.do*
// @include     https://www.recreation.gov/campsiteCalendar.do*
// @include     http://www.recreation.gov/switchBookingAction.do*
// @include     https://www.recreation.gov/switchBookingAction.do*
// @include     http://www.recreation.gov/campsitePaging.do*
// @include     https://www.recreation.gov/campsitePaging.do*
// @include     http://www.recreation.gov/memberSignInSignUp.do*
// @include     https://www.recreation.gov/memberSignInSignUp.do*
// @include     http://www.recreation.gov/reservationDetails.do*
// @include     https://www.recreation.gov/reservationDetails.do*
// @include     http://www.recreation.gov/updateShoppingCartItem.do*
// @include     https://www.recreation.gov/updateShoppingCartItem.do*
// @include     http://www.recreation.gov/recreationalAreaDetails.do*
// @include     https://www.recreation.gov/recreationalAreaDetails.do*
// @author          Mike Stanton
// @version         1.2
// @require     http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js
// @grant       GM_xmlhttpRequest
// @grant       GM_getValue
// @grant       GM_setValue
// @grant       GM_deleteValue
// ==/UserScript==


(function () {
	var main = function () { //storing function in variable to allow variable content passes

		//*******************************************************//
		//    IMPORTANT SETTINGS
		//*******************************************************//
		var ArrivalDate = 'Thu Jul 13 2017'; 			//Date of Campground Check in
		var DepartureDate = 'Sat Jul 15 2017'; 			//Date of Campground Check out
	//	var ArrivalDate = 'Wed Mar 29 2017'; 			//Date of Campground Check in
	//	var DepartureDate = 'Thu Mar 30 2017'; 			//Date of Campground Check out
		var ParkIDs = ["70928", "70927", "70925"]; 		//ParkID's of campgrounds to search. 70925 = Upper Pines, 70927 = North Pines, 70928 = Lower Pines
		var CustomizeOrder = false; 				// If true, you can make changes before the campsite is added to check out.
		var RefreshRate = 1000; 				// 1000 = 1 second
		var DesiredCount = 2;					// Number of campsites to reserve
		var SiteIDs = [			// List of preferred campsites, The script will try each in order before searching for first available.
			"207569",    //Lower Pines DBL3
			"203515",    //Lower Pines DBL2
			"203318",    //Lower Pines DBL1
			"203396",  		//Lower Pines #39 
			"203394",  		//Lower Pines #38 
			"203383", 		//Lower Pines #37 
			"203398", 		//Lower Pines #40 
			"203399", 		//Lower Pines #41 
			"203400", 		//Lower Pines #42 
			"203402", 		//Lower Pines #43 
			"203404",  		//Lower Pines #44 
			"203407",  		//Lower Pines #45 
			"203408", 		//Lower Pines #46 
			"203412", 		//Lower Pines #47 
			"203491", 		//Lower Pines #58 
			"203493",		//Lower Pines #59 
			"203494",		//Lower Pines #60 
			"203495",		//Lower Pines #62
			"205054",		//Lower Pines #63
			"203497",		//Lower Pines #64
			"205053",		//Lower Pines #65
			"205052"		//Lower Pines #66
				];				

		var CurrentPage = window.location.href; 		//Current URL
		var $_GET = URLvars(document.location.search); 		//Parse URL Get Variables
		var Pause = GM_getValue("Pause"); 			// Prevent infinite loop
		if (Pause == "1") {
			Pause = prompt("The script is paused. Type any letter to restart script.");
			GM_setValue("Pause", Pause);
		}
		if (Pause == "1") {
			exit;
		}
		
		var Favorites = GM_getValue("Favorites");
		if (typeof Favorites === "undefined"){
			if (typeof SiteIDs == "undefined"){
				GM_setValue("Favorites", "0");
				Favorites = "0";
			} else {			
				GM_setValue("Favorites", JSON.stringify(SiteIDs));
				Favorites = JSON.stringify(SiteIDs);
			}
		}
		
		//
		// These if statements execute different function based on the current URL
		//

		// If we've found a site thats listed as available
		// 
		if ((CurrentPage.includes('camping') && CurrentPage.includes('siteId')) || CurrentPage.includes('switchBookingAction.do')) {
			var reserved = false;
			var TableID = '';
			var Nights = $_GET['lengthOfStay'];
			var SiteID = $_GET['siteId'];
			var Favorite = false;
			if (Favorites != 0 ){
				SiteIDs = JSON.parse(GM_getValue("Favorites"));
				for (x = 0; x < SiteIDs.length; ++x){
					if(SiteID == SiteIDs[x]){
						Favorite = true;
						SiteIDs.splice(x, 1);
						if (SiteIDs.length > 0){
							GM_setValue("Favorites", JSON.stringify(SiteIDs));							
						}
						else{
							GM_setValue("Favorites", 0);	
						}
					}
				}
			/*	if (Favorite == false){
					window.location = "/camping/Upper_Pines/r/campsiteDetails.do?siteId=" + SiteIDs[0];
				} */
			}
			
			
			for (i = 1; i <= Nights; ++i) {
				TableID = "#avail" + i;
				if ($(TableID).attr("title") == "Reserved") {
					reserved = true;
				}
			}
			if (reserved == true) {
				if(Favorites != 0) {
					window.location = "/camping/Lower_Pines/r/campsiteDetails.do?contractCode=NRSO&siteId=" + SiteIDs[0];					
				} else {
					window.location = "/unifSearchInterface.do?interface=camping&contractCode=NRSO&parkId=" + $_GET['parkId'];
				}
			} else {
				setTimeout(function () {
					$("#btnbookdates").click();
				}, RefreshRate);
			}
			
			// 
			// If we've done a search for specific days
			// 
		} else if (CurrentPage.includes('campsiteSearch.do') || CurrentPage.includes('campsitePaging.do')) {
			var Site;
			var campsite;
			var Links;
			var Link;
			if (Favorites != 0 ){
				SiteIDs = JSON.parse(GM_getValue("Favorites"));
				Links = $("a.book.now");
				for (x = 0; x < SiteIDs.length; ++x){
					Site = SiteIDs[x];
					for (y = 0; y < Links.length; ++y){
						Link = String(Links[y]);
						if( Link.indexOf(Site) > -1 ){
							window.location = Link;
							return;						
						}			
					}
				}
			}
				
			campsite = $("a.book.now:first").attr("href");
			if (typeof campsite === "undefined") {
				campsite = $("#resultNext").attr("href");
			}
			if (typeof campsite === "undefined") {
				campsite = rotate($_GET['parkId'], ParkIDs);
			}
			window.location = campsite;

			// 
			// If we're on the main campground search page.  Begin search.
			// 
		} else if (CurrentPage.includes('campgroundDetails.do')) {
			$("#arrivalDate").val(ArrivalDate);
			$("#departureDate").val(DepartureDate);
			$("#filter").click();

			// 
			// We've grabbed the sight, setting options and adding to check out
			// 
		} else if (CurrentPage.includes('memberSignInSignUp.do') || CurrentPage.includes('reservationDetails.do') ) {
			$("#equip").val("108060");
			$("#equip").change();
			$("#numoccupants").val("6");
			$("#numvehicles").val("2");
			$("#agreement")[0].checked = true;
			
			if (CustomizeOrder == false) {
				$("#continueshop").click();
			}
						
			// 
			// Before we checkout, did we want another campsite?
			// 
		} else if (CurrentPage.includes('updateShoppingCartItem.do')) {
			var test = $("cartLink");
		//	if (!($.contains("cartLink", DesiredCount ))){
		//		$("#reservemore").click();
		//	}
			
			
			//
			//Reset all GM variables by visiting this page
			//
		} else if (CurrentPage.includes('recreationalAreaDetails.do')) {
			GM_deleteValue("Favorites");
			GM_deleteValue("Pause");
			GM_deleteValue("rotation");
			
		}
		
	}

	// 
	//Function to try a different campground
	// 
	rotate = function (parkId, List) {
		var rotation = GM_getValue("rotation"); // Recall the number of campgrounds we checked
		var index,
		length,
		NewPark,
		NextIndex;
		if (typeof rotation === "undefined") { // If this is the first campground, set initial value
			rotation = 1;
			GM_setValue("rotation", rotation);
		} else if (rotation >= List.length) { // If we checked more campgrounds than listed, quit.
			GM_deleteValue("rotation");
			alert('All parks checked.  Try a different date.');
			GM_setValue("Pause", "1");
			exit;
		}
		rotation++;
		GM_setValue("rotation", rotation); // Increment count of campgrounds checked.
		for (index = 0, length = List.length; index < length; ++index) { // Check current campground against list, select the next campground
			if (List[index] == parkId) {
				NextIndex = index + 1;
				if (typeof List[NextIndex] == "undefined") {
					NextIndex = "0";
				}
				NewPark = List[NextIndex];
			}
		}
		NewPark = "/unifSearchInterface.do?interface=camping&contractCode=NRSO&parkId=" + NewPark;
		return NewPark;
	}

	// 
	//Function to parse URL variables
	// 
	var URLvars = function getQueryParams(qs) {
		qs = qs.split("+").join(" ");
		var params = {},
		tokens,
		re = /[?&]?([^=]+)=([^&]*)/g;
		while (tokens = re.exec(qs)) {
			params[decodeURIComponent(tokens[1])]
				 = decodeURIComponent(tokens[2]);
		}
		return params;
	}
	
	// 
	// Execute main function
	// 
	main();

})();