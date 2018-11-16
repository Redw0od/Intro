 <?php
/**
 * Script to multi thread IRC scraping
 */
const INCLUDES = "/home/rockittech/services/inc/";
include(INCLUDES . "class.MySQL.php");
include(INCLUDES . "config.php");

$database = new MySQL();
$Curators = $database->get_results("SELECT Name FROM Curators");

foreach($Curators as $Curator) {
	$pid = pcntl_fork();
	if($pid == -1){
		exit("Error forking process...\n");
	} else if(!$pid){
		$command = "(php " . SERVICES . "chatters.php " . $Curator['Name'] . " & disown )> " . LOGS . "lobbies/" . $Curator['Name'] . ".log 2>&1 ";
		echo $command . "\r\n";
		exec($command);
		break;
	}
}
while(pcntl_waitpid(0, $status) != -1);

?>
