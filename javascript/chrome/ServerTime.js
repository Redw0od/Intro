// ==UserScript==
// @name        Recreation.gov Server Time
// @namespace   http://www.rockittech.com
// @description Display current server time
// @include     http://www.recreation.gov/
// @include     https://www.recreation.gov/
// @include     http://www.recreation.gov/camping/*
// @include     https://www.recreation.gov/camping/*
// @author      Mike Stanton
// @version     1
// @require     http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js
// @grant       GM_addStyle
// @grant       GM_xmlhttpRequest 
// @grant       GM_getValue
// @grant       GM_setValue
// @grant       GM_deleteValue
// ==/UserScript==

GM_xmlhttpRequest ( {
    url:    location.href,
    method: "HEAD",
    onload: function (rsp) {
			var serverTime  = "Server date not reported!";
			var RespDate    = rsp.responseHeaders.match (/\bDate:\s+(.+?)(?:\n|\r)/i);

			if (RespDate  &&  RespDate.length > 1) {
				serverTime  = RespDate[1];
			}
			var ServerDate = new Date(serverTime);
			var MainDiv = document.getElementById('gmPopupContainer');
			var MainContent = document.getElementById('gmPopupContainer').innerHTML;
			MainDiv.innerHTML = '<div><h1><span id="time" class="summary"></span></h1></div>' + MainContent;
			startTime(ServerDate);
    }
} );


function startTime(NewTime) {
    var h=NewTime.getHours();
    var m=NewTime.getMinutes();
    var s=NewTime.getSeconds();
    m = checkTime(m);
    s = checkTime(s);
    document.getElementById('time').innerHTML = h+":"+m+":"+s;
		NewTime.setSeconds(NewTime.getSeconds() + 1);
    var t = setTimeout(function(){startTime(NewTime)},1000);
}

function checkTime(i) {
    if (i<10) {i = "0" + i};  // add zero in front of numbers < 10
    return i;
}

$("body").append ( '                                                          \
    <div id="gmPopupContainer">                                               \
    </div>                                                                    \
' );


//--- Use jQuery to activate the dialog buttons.
$("#gmAddNumsBtn").click ( function () {
    var A   = $("#myNumber1").val ();
    var B   = $("#myNumber2").val ();
    var C   = parseInt(A, 10) + parseInt(B, 10);

    $("#myNumberSum").text ("The sum is: " + C);
} );

$("#gmCloseDlgBtn").click ( function () {
    $("#gmPopupContainer").hide ();
} );


//--- CSS styles make it work...
GM_addStyle ( "                                                 \
    #gmPopupContainer {                                         \
        position:               fixed;                          \
        top:                    100px;                            \
        left:                   2%;                            \
        padding:                2em;                            \
        background:             lightgray;                     \
        border:                 3px double black;               \
        border-radius:          1ex;                            \
        z-index:                777;                            \
    }                                                           \
    #gmPopupContainer button{                                   \
        cursor:                 pointer;                        \
        margin:                 1em 1em 0;                      \
        border:                 1px outset buttonface;          \
    }                                                           \
" );