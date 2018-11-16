 <?php
/**
 * Grabbing channel follower list and logging it.
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
 * Read in the channel being requested to monitor.
 */
$Curator = "";
if (PHP_SAPI === 'cli') {
    $Curator = $argv[1];
}
else {
    $Curator = $_GET['Curator'];
}
if(empty($Curator))
	exit;

/**
 * Submit an Array to update the length of time a users been active
 */
function UpdateCurator($values){
	global $database;

	$chatters = $database->filter($values);												//Sanitize data before submitting to database
	if(strlen($chatters['Name']) < 4){													//Filtering out submissions which don't meet length requirements (corrupted by filter or response)		
		echo "01 - User name is corrupt: " . $chatters['Name'] . "\r\n";
	} else {																			//Submit sanitized data to database.
		echo "Updating : ". $chatters['Name'] . "\r\n";
		$database->update('Lobby', $chatters, array('Name' => $chatters['Name'] , 'Active' => 1));
	}
}

/**
 * Submit an Array to insert a new viewer into the database
 */
function InsertCurator($values){
	global $database;

	$chatters = $database->filter($values);												//Sanitize data before submitting to database
	if(strlen($chatters['Name']) < 4){													//Filtering out submissions which don't meet length requirements (corrupted by filter or response)
		echo "06 - User name is corrupt: " . $chatters['Name'] . "\r\n";
	} else {
		echo "Inserting : ". $chatters['Name'] . "\r\n";
		$database->insert('Lobby', $chatters);											//Submit sanitized data to database.
	}
}


/**
 * Submit an Array to update the viewers activity to 0
 */
function CloseCurator($values){
	global $database;
	$chatters = $database->filter($values);											//Sanitize data before submitting to database
	if(strlen($chatters['Name']) < 4){												//Filtering out submissions which don't meet length requirements (corrupted by filter or response)
		echo "04 - User name is corrupt: " . $chatters['Name'] . "\r\n";
	} else {																		//Submit sanitized data to database.
		echo "Closing : ". $chatters['Name'] . "\r\n";
		$database->update('Lobby', $chatters, array('Name' => $chatters['Name'] , 'Active' => 1));
	}
}

/**
 * Structure the api user array with names as Index's for improved script speed
 */
function MergeTMI($Array){
	foreach($Array as $type => $users){
		foreach($users as  $user) {
			$NewTMI[$user] = $type;
		}
	}		
	return $NewTMI;
	}

/**
 * Structure the sql user array with names as Index's for improved script speed
 */
function BuildSQL($Array){
	foreach($Array as $row){
		$NewArray[$row['Name']] = $row['timestamp'];
	}
	return $NewArray;
}


/**
 * Submit an Array to update the viewers activity to 0
 */
function FixDupes($user){
	global $database;
	global $Curator;
	$user = $database->filter($user);		
	$rows = $database->num_rows( "SELECT ID FROM Lobby WHERE Name = '" . $user . "' AND Channel = '".$Curator."' AND Active = 1" );
	if($rows > 1 ){
		$Records = $database->get_results("SELECT ID FROM Lobby WHERE Name = '" . $user . "' AND Channel = '".$Curator."' AND Active = 1");
		echo "Removing ". $rows . " dupes of " . $user . "\r\n";
		for($i = 1; $i < $rows; $i++){
		$chatters = array(
			'ID' => $Records[$i]['ID'],
			'Channel' => $Curator,
			'Action' => "ERR",
			'Active' => 0 );
			$database->update('Lobby', $chatters, array('ID' => $Records[$i]['ID'] ));
		}
	}
}
/**
 * Populate intial user arrays with SQL and API calls
 */
echo "\r\nCurator : ".$Curator."\r\n";	
$SQLArray = $database->get_results("SELECT * FROM Lobby WHERE Active = 1 AND Channel = '".$Curator."'");
$TMIArray = json_decode( @ file_get_contents('https://tmi.twitch.tv/group/user/'.$Curator."/chatters?client_id=" . STRONGCHAT ), true);
	
if (is_array($TMIArray)) {	
	$TMImerged = MergeTMI($TMIArray['chatters']);								//Prepare API called array for comparison
	$TMINewUsers = $TMImerged;													//Array to define users not yet in SQL
		
	if (is_array($SQLArray)) {	
		$SQLusers = BuildSQL($SQLArray);										//Prepare SQL array for comparison
		echo "SQL Array has " . count($SQLusers) . " elements.  API array has " . count($TMImerged) . " elements. \r\n";
		foreach($SQLusers as $SQLname => $SQLtime){
			FixDupes($SQLname);
			if(isset($TMImerged[$SQLname])){									//Is there a matching pair?
				$OnlineUsers[$SQLname] = $TMImerged[$SQLname];					//Update user activity time
				$timevar1 = time();
				$timevar2 = strtotime($SQLtime);
				$Length = $timevar1 - $timevar2 ;
				//echo " SQL Name: " . $SQLname . " matches ". $TMImerged[$SQLname] . " updating lobby time to :" . $Length . "\r\n";
				$chatters = array(
						'Name' => $SQLname,
						'Channel' => $Curator,
						'Action' => "JOIN",
						'Type' => $TMImerged[$SQLname],
						'Active' => 1,
						'Length' => $Length);
				UpdateCurator($chatters);
				unset($TMINewUsers[$SQLname]);									//Remove user from array of users to be inserted
			} else {
				$OldUsers[$SQLname] = $TMImerged[$SQLname];						//Build array of users to set activity to 0
				$chatters = array(
					'Name' => $SQLname,
					'Channel' => $Curator,
					'Action' => "PART",
			//		'Type' => $TMImerged[$SQLname],
					'Active' => 0);		
				CloseCurator($chatters);	
			}
		}
	}
	if (is_array($TMINewUsers)) {	
		foreach($TMINewUsers as $TMIName => $TMItype){
					$chatters = array(
							'ID' => 'DEFAULT',
							'timestamp' => date("Y-m-d H:i:s"),
							'Name' => $TMIName,
							'Channel' => $Curator,
							'Action' => "JOIN",
							'Type' => $TMItype,
							'Active' => 1,
							'Length' => 0);		
					InsertCurator($chatters);
		}
	}
}

?>
