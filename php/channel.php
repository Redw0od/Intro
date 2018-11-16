<?php
/**
 * Grabbing channel info and logging it.
 */

set_time_limit( 0 ); 

/**
 * Includes for accessing the MySQL database.
 */
const INCLUDES = "/home/rockittech/services/inc/";
include(INCLUDES . "class.MySQL.php");
include(INCLUDES . "config.php");
$database = new MySQL();

/**
 * Initializing Variables
 */
$API_Timer['count'] = 0;						// Counter tor tracking API calls per second
$API_Timer['time'] = microtime(true);			// Timestamp for tracking API calls per second
const DELAY = "1000000";						// Time between API calls. 1sec = 1000000
$Curators = $database->get_results( "SELECT Name FROM Curators" );



/**
 * Script Delay function
 * Requires Array with 'count' and 'time' = microtime() elements
 */
function SlowDown($Timer){
	if(empty($Timer['count'])){
		usleep(DELAY);
		return $Timer;
	} else if (empty($Timer['time'])){
		usleep(DELAY);
		return $Timer;
	}
	$tpc = round((microtime(true) - $Timer['time']) * 1000000);
	$wait = $Timer['count'] * DELAY;
	if($tpc < $wait){     							//if TimePerCycle is less then API calls
		while($tpc < $wait){
			usleep(100000);
			$tpc = round((microtime(true) - $Timer['time']) * 1000000) ;
		//	echo $wait - $tpc . "\r";
		}
		$Timer['count'] = 0;
		$Timer['time'] = microtime(true);
	}
	return $Timer;
}

foreach($Curators as $Curator){
	$Curator = $Curator['Name'];
	$API_Timer = SlowDown($API_Timer);
	$dataArray = json_decode(@file_get_contents('https://api.twitch.tv/kraken/channels/' . $Curator . "?client_id=" . STRONGCHAT), true);
	$API_Timer['count']++;
	if($dataArray['mature']){
		$mature = "1";
	} else {
		$mature = "0";
	}
	if($dataArray['partner']){
		$partner = "1";
	} else {
		$partner = "0";
	}
	$stats = array( 
		'ID' => "DEFAULT", 
		'timestamp' => "DEFAULT", 
		'mature' => $mature, 
		'status' => $dataArray['status'], 
		'broadcaster_language' => $dataArray['broadcaster_language'], 
		'display_name' => $dataArray['display_name'], 
		'game' => $dataArray['game'], 
		'delay' => $dataArray['delay'], 
		'language' => $dataArray['language'], 
		'_id' => $dataArray['_id'], 
		'name' => $dataArray['name'], 
		'created_at' => $dataArray['created_at'], 
		'updated_at' => $dataArray['updated_at'], 
		'logo' => $dataArray['logo'], 
		'banner' => $dataArray['banner'], 
		'video_banner' => $dataArray['video_banner'], 
		'background' => $dataArray['background'], 
		'profile_banner' => $dataArray['profile_banner'], 
		'profile_banner_background_color' => $dataArray['profile_banner_background_color'], 
		'partner' => $partner, 
		'views' => $dataArray['views'], 
		'followers' => $dataArray['followers'] );

	$dataArray = json_decode(@file_get_contents('https://api.twitch.tv/kraken/streams/' . $Curator . "?client_id=c5oi45ovp9ylcio0733rh49jnrye1cu"), true);
	$API_Timer['count']++;
	if ($dataArray['stream'] != ""){
		$stats['viewers'] = $dataArray['stream']['viewers'];
		$stats['video_height'] = $dataArray['stream']['video_height'];
		$stats['average_fps'] = $dataArray['stream']['average_fps'];
	}
	echo date('Y-m-d H:i:s') . " : Updating " . $Curator . "'s channel status.\r\n";
	$stats = $database->filter( $stats );
	$database->insert( 'Channels', $stats );
	$stats = array();
}
?>