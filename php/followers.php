 <?php
/**
 * InCrowd
 * Crawling list of users and who they follow.
 */

set_time_limit( 0 ); 
 
/**
 * Includes for accessing the MySQL database.
 */
const INCLUDES = "/home/rockittech/services/inc/";
include_once(INCLUDES . "class.MySQL.php");
include_once(INCLUDES . "config.php");
include_once(INCLUDES . "common.php");
$database = new MySQL();

/**
 * Structure the sql user array with names as Index's for improved script speed
 */
function BuildUser($Array){
	if(is_array($Array)){
		foreach($Array as $row){
			$NewArray[$row['name']] = $row['_id'];
		}
		return $NewArray;
	} else {
		return $Array;
	}
}

function recent_followers($Curator){
	global $database;
	global $APIcalls;
	$offset = 0;
	do{
		$APIresponse = json_decode( @ file_get_contents("https://api.twitch.tv/kraken/channels/$Curator/follows?limit=100&offset=$offset&client_id=" . INCROWD ), true);
		$APIcalls++;
		if(isset($APIresponse)){
			$total = $APIresponse['_total'];
			foreach($APIresponse['follows'] as $Unit){
				if(is_array($Unit)){
					$UserArray[] = array(
						'_id' => $Unit['user']['_id'],
						'name' => $Unit['user']['name'],
						'created_at' => $Unit['user']['created_at'],
						'updated_at' => $Unit['user']['updated_at'],
						'display_name' => $Unit['user']['display_name'],
						'logo' => $Unit['user']['logo']	
						);
				}
			}
		}
		if($total > 1600)
			$total = 1600;
		$offset += 100;
	}while($total > $offset);
	return $database->filter($UserArray);	;
	
}



/**
 * Grab the API response for followers
 */
function BeingStalked($user){
	global $database;
	global $total;
	global $APIcalls;
//	https://api.twitch.tv/kraken/users/redw0od/follows/channels?oauth_token=4vr512upv97xdqfnpqa3sqe5o15vyl
	$offset=0;
	$total=0;
	do{
		$APIresponse = json_decode( @ file_get_contents("https://api.twitch.tv/kraken/users/$user/follows/channels?limit=100&offset=$offset&client_id=" . INCROWD ), true);
		$APIcalls++;
		if(isset($APIresponse)){
			$total = $APIresponse['_total'];
			foreach($APIresponse['follows'] as $Unit){
				if(is_array($Unit)){
					$UserArray[] = array(
						'_id' => $Unit['channel']['_id'],
						'name' => $Unit['channel']['name'],
						'created_at' => $Unit['channel']['created_at'],
						'updated_at' => $Unit['channel']['updated_at'],
						'display_name' => $Unit['channel']['display_name'],
						'logo' => $Unit['channel']['logo']	
						);
				}
			}
		}
		$offset += 100;
	}while($total > $offset);
	return $database->filter($UserArray);	;
}

/**
 * Submit an Array to update the Patrons table with new data or users.
 */
function AddPatron($Users){
	global $database;
	if(is_array($Users)){
		foreach($Users as $User){
			$WhereClause = array (
				'name' => $User['name']
			);
			$Exists = $database->exists('Patrons', 'name', $WhereClause);
			$patron = array(
				'user' => $User['_id'],
				'name' => $User['name'],
				'created_at' => $User['created_at'],
				'updated_at' => $User['updated_at'],
				'display_name' => $User['display_name'],
//				'bio' => $User['bio'],
//				'type' => $User['type'],
				'logo' => $User['logo']);
			if($Exists){
				$database->update('Patrons', $patron, array('name' => $User['name']));	
			} else {
				$patron['ID'] = 'DEFAULT';
				$patron['timestamp'] = date("Y-m-d H:i:s");
				$database->insert('Patrons', $patron);	
				$NewList[] = $patron['name'];	
			}
		}
		if(!empty($NewList))
			return $NewList;	
		else
			return false;
	}
			return false;
}

/**
 * Submit an Array to update the Following table with new data or users.
 */
function UpdateFollowing($Users, &$Fan){
	global $database;
	if(is_array($Users)){
		$Fan = $database->filter($Fan);
		$query = "SELECT channel FROM Following WHERE name='$Fan' ";
		$Rows = $database->get_results($query);
		foreach($Rows as $row){
			$known[$row['channel']] = $Fan;
		}
		foreach($Users as $User){
			if(!isset($known[$User['name']])){
				$patrons[] = array(
				'DEFAULT',
				date("Y-m-d H:i:s"),
				$Fan,
				$User['name']);	
			}
		}
		if(isset($patrons)){
		$fields = array('ID','timestamp','name','channel' );
		$database->insert_multi('Following', $fields, $patrons);
		}
	}
}

/**
 * Submit an Array to remove users from Following table with new data or users.
 */
function UpdateUnfollowed($Users, $Fan){
	global $database;
	$SQLArray = $database->get_results("SELECT * FROM Following WHERE name='". $Fan ."'");
	if(isset($SQLArray)){
		$APIUsers = BuildUser($Users);
		foreach($SQLArray as $User){
			if(!isset($APIUsers[$User['channel']])){
				$database->delete("Following",  array('name'=> $User['name'], 'channel' => $User['channel']));
			}
		}
	}
}

function Crawl(&$Patrons){
	global $Clock;
	global $SubClock;
	global $APIcalls;
	global $total;
	$newPatrons = array();
	foreach($Patrons as $index => $Patron){
		$counter++;
		$TheList = BeingStalked($Patron);
	$APItime = microtime(true) - $SubClock;
	$SubClock = microtime(true);
		if($TheList){
			$newPatron = AddPatron($TheList);
	$SQLtime = microtime(true) - $SubClock;
	$SubClock = microtime(true);
			if($newPatron){
				$newPatrons = array_merge($newPatron, $newPatrons);
				$newPatron = false;
			}
	$followers = count($TheList);
	$Mergetime = microtime(true) - $SubClock;
	$SubClock = microtime(true);
			UpdateFollowing($TheList, $Patron);
	$Followingtime = microtime(true) - $SubClock;
	$SubClock = microtime(true);
			UpdateUnfollowed($TheList, $Patron);
	$UnFollowingtime = microtime(true) - $SubClock;
		}
		$currenttime = microtime(true);
	$sleep = ($APIcalls * 1000000) - (($currenttime - $Clock) * 1000000);
		$c1 = grade($APItime);
		$c2 = grade($SQLtime);
		$c3 = grade($Mergetime);
		$c4 = grade($Followingtime);
		$c5 = grade($UnFollowingtime);
		$c6 = grade($sleep);	
		echo "$counter. offset($offset) API(" . chr(27). c(round($APItime, 2), $c1). chr(27). '[0m' .")#(". chr(27). c($total, 'purple'). chr(27). 
		'[0m' . ") SQL(" . chr(27). c(round($SQLtime, 2), $c2). chr(27). 
		'[0m'  .") Merge(" . chr(27). c(round($Mergetime, 2), $c3). chr(27). 
		'[0m'  .") Follow(" . chr(27). c(round($Followingtime, 2), $c4). chr(27). '[0m'  .")#(" . chr(27). c($followers, 'purple'). chr(27). 
		'[0m'  .") UnFollow(" . chr(27). c(round($UnFollowingtime, 2), $c5). chr(27). 
		'[0m'  .") Sleep(" . chr(27). c(round($sleep/1000000, 2), 'white'). chr(27). 
		'[0m'  .") name(" . chr(27). c($Patron['Name'], 'purple'). chr(27). '[0m'  . ")\r\n" ;		
	if($sleep > 0)
			usleep( $sleep );
	$SubClock = microtime(true);
	}
		if(!empty($newPatrons))
			return $newPatrons;	
		else
			return false;
}

function RecentCrawl(&$Patrons){
	global $Clock;
	global $SubClock;
	global $APIcalls;
	global $total;
	$newPatrons = array();
	AddPatron($Patrons);
	foreach($Patrons as $Patron){
		$counter++;
		$TheList = BeingStalked($Patron['name']); $APItime = microtime(true) - $SubClock; $SubClock = microtime(true);
		if($TheList){
			$newPatron = AddPatron($TheList); $SQLtime = microtime(true) - $SubClock; $SubClock = microtime(true);
			if($newPatron){
				$newPatrons = array_merge($newPatron, $newPatrons);
				$newPatron = false;
			}
			$followers = count($TheList); $Mergetime = microtime(true) - $SubClock; $SubClock = microtime(true);
			UpdateFollowing($TheList, $Patron['name']); $Followingtime = microtime(true) - $SubClock; $SubClock = microtime(true);
			UpdateUnfollowed($TheList, $Patron['name']); $UnFollowingtime = microtime(true) - $SubClock;
		}
		$currenttime = microtime(true);
		$sleep = ($APIcalls * 1000000) - (($currenttime - $Clock) * 1000000);
		$c1 = grade($APItime);
		$c2 = grade($SQLtime);
		$c3 = grade($Mergetime);
		$c4 = grade($Followingtime);
		$c5 = grade($UnFollowingtime);
		$c6 = grade($sleep);	
		echo "$counter. offset($offset) API(" . chr(27). c(round($APItime, 2), $c1). chr(27). '[0m' .")#(". chr(27). c($total, 'purple'). chr(27). 
		'[0m' . ") SQL(" . chr(27). c(round($SQLtime, 2), $c2). chr(27). 
		'[0m'  .") Merge(" . chr(27). c(round($Mergetime, 2), $c3). chr(27). 
		'[0m'  .") Follow(" . chr(27). c(round($Followingtime, 2), $c4). chr(27). '[0m'  .")#(" . chr(27). c($followers, 'purple'). chr(27). 
		'[0m'  .") UnFollow(" . chr(27). c(round($UnFollowingtime, 2), $c5). chr(27). 
		'[0m'  .") Sleep(" . chr(27). c(round($sleep/1000000, 2), 'white'). chr(27). 
		'[0m'  .") name(" . chr(27). c($Patron['name'], 'purple'). chr(27). '[0m'  . ")\r\n" ;		
		if($sleep > 0)
				usleep( $sleep );
			$SubClock = microtime(true);
		}
		if(!empty($newPatrons))
			return $newPatrons;	
		else
			return false;
}
function grade($text){
	switch($text){
		case($text < .1):
			$color = 'cyan';
			break;
		case($text < .5):
			$color = 'green';
			break;
		case($text < 1):
			$color = 'yellow';
			break;
		default:
			$color = 'red';
			break;
	}
	return $color;
}

$counter = 0;
$APIcalls = 0;
$delay = 1000000;
$Clock = microtime(true); 
$SubClock = $Clock;
$newPatron = false;   
$newPatrons = array();
$TheList = array();
$total = 0;
$times = "";
echo "\r\n";
/**
 * Populate intial user arrays with SQL and API calls
 */
$Curators = $database->get_results( "SELECT Name FROM Curators" );
//$Curators[] = array('Name' => 'redw0od');
foreach($Curators as $Curator){
	$counter++;
	$TheList = BeingStalked($Curator['Name']);
	$APItime = microtime(true) - $SubClock;	$SubClock = microtime(true);
	if(count($TheList) > 0 ){
		$newPatron = AddPatron($TheList);
		$SQLtime = microtime(true) - $SubClock;	$SubClock = microtime(true);
		// if($newPatron){									Causing memory crash
			// $newPatrons = array_merge($newPatron, $newPatrons);
			// $newPatron = false;
		// }
		$followers = count($TheList);
		$Mergetime = microtime(true) - $SubClock;	$SubClock = microtime(true);
		UpdateFollowing($TheList, $Curator['Name']);
		$Followingtime = microtime(true) - $SubClock;	$SubClock = microtime(true);
		UpdateUnfollowed($TheList, $Curator['Name']);
		$UnFollowingtime = microtime(true) - $SubClock;
	}
	$currenttime = microtime(true);
	$sleep = ($APIcalls * 1000000) - (($currenttime - $Clock) * 1000000);
	$c1 = grade($APItime);
	$c2 = grade($SQLtime);
	$c3 = grade($Mergetime);
	$c4 = grade($Followingtime);
	$c5 = grade($UnFollowingtime);
	$c6 = grade($sleep);	
	echo "$counter. offset($offset) API(" . chr(27). c(round($APItime, 2), $c1). chr(27). '[0m' .")#(". chr(27). c($total, 'purple'). chr(27). 
	'[0m' . ") SQL(" . chr(27). c(round($SQLtime, 2), $c2). chr(27). 
	'[0m'  .") Merge(" . chr(27). c(round($Mergetime, 2), $c3). chr(27). 
	'[0m'  .") Follow(" . chr(27). c(round($Followingtime, 2), $c4). chr(27). '[0m'  .")#(" . chr(27). c($followers, 'purple'). chr(27). 
	'[0m'  .") UnFollow(" . chr(27). c(round($UnFollowingtime, 2), $c5). chr(27). 
	'[0m'  .") Sleep(" . chr(27). c(round($sleep/1000000, 2), 'white'). chr(27). 
	'[0m'  .") name(" . chr(27). c($Curator['Name'], 'purple'). chr(27). '[0m'  . ")\r\n" ;		

	if($sleep > 0)
		usleep( $sleep );
	$SubClock = microtime(true);
	$TheList = null;
	RecentCrawl(recent_followers($Curator['Name']));
}
unset($Curators);



$rows = $database->num_rows( "SELECT ID FROM Patrons" );
	echo  "Curators Complete. Itterating through $rows known patrons. \r\n";
$block = 1000;
//$block = 5;
$offset = 0;
$offsetfile = "/home/rockittech/services/logs/follow_offset.log";
$myfile = fopen($offsetfile, "r");
$offset = trim(fread($myfile, filesize($offsetfile)));
fclose($myfile);
if($offset > $rows){
	$offset = 0;
}

do{
	$SQLArray = $database->get_results("SELECT name FROM Patrons ORDER BY ID ASC LIMIT ". $offset . ", ". $block);
	// $SQLArray = $database->get_results("SELECT name FROM Patrons LIMIT ". $offset . ", ". $block);
	if (is_array($SQLArray)) {
		foreach($SQLArray as $Patron){
			$counter++;
			$TheList = BeingStalked($Patron['name']);
			$APItime = microtime(true) - $SubClock;$SubClock = microtime(true);
			if($TheList){
				$newPatron = AddPatron($TheList);
				$SQLtime = microtime(true) - $SubClock;	$SubClock = microtime(true);
				// if($newPatron){
					// $newPatrons = array_merge($newPatron, $newPatrons);
					// $newPatron = false;
				// }
				$followers = count($TheList);
				$Mergetime = microtime(true) - $SubClock; $SubClock = microtime(true);
				UpdateFollowing($TheList, $Patron['name']);
				$Followingtime = microtime(true) - $SubClock; $SubClock = microtime(true);
				UpdateUnfollowed($TheList, $Patron['name']);
				$UnFollowingtime = microtime(true) - $SubClock;
			}
			$currenttime = microtime(true);
			$sleep = ($APIcalls * 1000000) - (($currenttime - $Clock) * 1000000);
			$c1 = grade($APItime);
			$c2 = grade($SQLtime);
			$c3 = grade($Mergetime);
			$c4 = grade($Followingtime);
			$c5 = grade($UnFollowingtime);
			$c6 = grade($sleep);	
	echo "$counter. offset($offset) API(" . chr(27). c(round($APItime, 2), $c1). chr(27). '[0m' .")#(". chr(27). c($total, 'purple'). chr(27). 
	'[0m' . ") SQL(" . chr(27). c(round($SQLtime, 2), $c2). chr(27). 
	'[0m'  .") Merge(" . chr(27). c(round($Mergetime, 2), $c3). chr(27). 
	'[0m'  .") Follow(" . chr(27). c(round($Followingtime, 2), $c4). chr(27). '[0m'  .")#(" . chr(27). c($followers, 'purple'). chr(27). 
	'[0m'  .") UnFollow(" . chr(27). c(round($UnFollowingtime, 2), $c5). chr(27). 
	'[0m'  .") Sleep(" . chr(27). c(round($sleep/1000000, 2), 'white'). chr(27). 
	'[0m'  .") name(" . chr(27). c($Patron['name'], 'purple'). chr(27). '[0m'  . ")\r\n" ;				
			if($sleep > 0)
				usleep( $sleep );	
			$SubClock = microtime(true);
			$TheList = null;	
		}
	}
	$offset = $offset + $block;
	$myfile = fopen($offsetfile, "w");
	fwrite($myfile, $offset);
	fclose($myfile);
}while($rows > $offset);	
//}while(false);	
unset($SQLArray);
$rows = count($newPatrons);
	echo  "\r\nPatron Table iteration complete. Itterating through $rows unknown patrons. \r\n";
	
while($newPatrons){
	$PatronList = Crawl($newPatrons);
	$newPatrons = null;
	$newPatrons = $PatronList;
}

?>
