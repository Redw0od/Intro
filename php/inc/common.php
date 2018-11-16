<?php
/*
* This function takes security precautions for creating a web session.
*/
function sec_session_start() {
    $session_name = 'opera';   // Set a custom session name
    $secure = SECURE;
    // This stops JavaScript being able to access the session id.
    $httponly = true;
    // Forces sessions to only use cookies.
    if (ini_set('session.use_only_cookies', 1) === FALSE) {
        $error = "Could not initiate a safe session (ini_set)";
    }
    // Gets current cookies params.
    $cookieParams = session_get_cookie_params();
    session_set_cookie_params($cookieParams["lifetime"],
        $cookieParams["path"], 
        $cookieParams["domain"], 
        $secure,
        $httponly);
    // Sets the session name to the one set above.
    session_name($session_name);
    session_start();            // Start the PHP session 
    session_regenerate_id(true);    // regenerated the session, delete the old one. 
}

function login($email, $password, $mysqli) {
    // Using prepared statements means that SQL injection is not possible. 
    if ($mysqli->prepare("SELECT guid, username, password, salt, active 
        FROM members
       WHERE email = ?
        LIMIT 1")) {
        $mysqli->bind('s', $email);  // Bind "$email" to parameter.
        $results = $mysqli->execute();    // Execute the prepared query.
 
        // get variables from result.
       // $stmt->bind_result($user_id, $username, $db_password, $salt, $active);
       // $stmt->fetch();
 print_r($results);
        // hash the password with the unique salt.
        $password = hash('sha512', $password . $salt);
        if ($stmt->num_rows == 1) {
            // If the user exists we check if the account is locked
            // from too many login attempts 
 
            if (checkbrute($user_id, $mysqli) == true) {
                // Account is locked 
                // Send an email to user saying their account is locked
                return false;
            } else {
                // Check if the password in the database matches
                // the password the user submitted.
                if ($db_password == $password) {
                    // Password is correct!
                    // Get the user-agent string of the user.
                    $user_browser = $_SERVER['HTTP_USER_AGENT'];
                    // XSS protection as we might print this value
                    $user_id = preg_replace("/[^0-9]+/", "", $user_id);
                    $_SESSION['user_id'] = $user_id;
                    // XSS protection as we might print this value
                    $username = preg_replace("/[^a-zA-Z0-9_\-]+/", 
                                                                "", 
                                                                $username);
                    $_SESSION['username'] = $username;
                    $_SESSION['login_string'] = hash('sha512', 
                              $password . $user_browser);
                    // Login successful.
                    return true;
                } else {
                    // Password is not correct
                    // We record this attempt in the database
                    $now = time();
                    $mysqli->query("INSERT INTO login_attempts(user_id, time)
                                    VALUES ('$user_id', '$now')");
                    return false;
                }
            }
        } else {
            // No user exists.
            return false;
        }
    }
}

function checkbrute($user_id, $mysqli) {
    // Get timestamp of current time 
    $now = time();
 
    // All login attempts are counted from the past 2 hours. 
    $valid_attempts = $now - (2 * 60 * 60);
 
    if ($stmt = $mysqli->prepare("SELECT time 
                             FROM login_attempts 
                             WHERE user_id = ? 
                            AND time > '$valid_attempts'")) {
        $stmt->bind_param('i', $user_id);
 
        // Execute the prepared query. 
        $stmt->execute();
        $stmt->store_result();
 
        // If there have been more than 5 failed logins 
        if ($stmt->num_rows > 5) {
            return true;
        } else {
            return false;
        }
    }
}

function login_check($mysqli) {
    // Check if all session variables are set 
    if (isset($_SESSION['user_id'], 
                        $_SESSION['username'], 
                        $_SESSION['login_string'])) {
 
        $user_id = $_SESSION['user_id'];
        $login_string = $_SESSION['login_string'];
        $username = $_SESSION['username'];
 
        // Get the user-agent string of the user.
        $user_browser = $_SERVER['HTTP_USER_AGENT'];
 
        if ($stmt = $mysqli->prepare("SELECT password 
                                      FROM members 
                                      WHERE id = ? LIMIT 1")) {
            // Bind "$user_id" to parameter. 
            $stmt->bind_param('i', $user_id);
            $stmt->execute();   // Execute the prepared query.
            $stmt->store_result();
 
            if ($stmt->num_rows == 1) {
                // If the user exists get variables from result.
                $stmt->bind_result($password);
                $stmt->fetch();
                $login_check = hash('sha512', $password . $user_browser);
 
                if ($login_check == $login_string) {
                    // Logged In!!!! 
                    return true;
                } else {
                    // Not logged in 
                    return false;
                }
            } else {
                // Not logged in 
                return false;
            }
        } else {
            // Not logged in 
            return false;
        }
    } else {
        // Not logged in 
        return false;
    }
}

function esc_url($url) {
 
    if ('' == $url) {
        return $url;
    }
 
    $url = preg_replace('|[^a-z0-9-~+_.?#=!&;,/:%@$\|*\'()\\x80-\\xff]|i', '', $url);
 
    $strip = array('%0d', '%0a', '%0D', '%0A');
    $url = (string) $url;
 
    $count = 1;
    while ($count) {
        $url = str_replace($strip, '', $url, $count);
    }
 
    $url = str_replace(';//', '://', $url);
 
    $url = htmlentities($url);
 
    $url = str_replace('&amp;', '&#038;', $url);
    $url = str_replace("'", '&#039;', $url);
 
    if ($url[0] !== '/') {
        // We're only interested in relative links from $_SERVER['PHP_SELF']
        return '';
    } else {
        return $url;
    }
}
/*
* Color CLI output. 
* @param string  Text to be colored
* @param string color of text ( black, red, green, yellow, blue, purple, cyan, white )
* @param string style of text ( plain, bold, underline )
* @param string background color of text.  same options as color
* @param string color to revert text too, if not resetting to default.
* use sprintf( $text, 27) to print color
*/
function c($text, $color, $style = '' ){
	switch(strtolower($style)){
		case('bold'):
			$code = '[1;';
			break;
		case('underline'):
			$code = '[4;';
			break;
		default:
			$code = '[0;';
	}
	switch(strtolower($color)){
		case('black'):
			$code .= '30m';
			break;
		case('red'):
			$code .= '31m';
			break;
		case('green'):
			$code .= '32m';
			break;
		case('yellow'):
			$code .= '33m';
			break;
		case('blue'):
			$code .= '34m';
			break;
		case('purple'):
			$code .= '35m';
			break;
		case('cyan'):
			$code .= '36m';
			break;
		default:
			$code .= '37m';
	}
	$text =  $code . $text ;
	return $text;
}

function draw_page_head($title){
echo @('<!DOCTYPE html>
<html lang="en" xml:lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>' . $title . '</title>
    <link rel="stylesheet" href="//theoperahall.com/opera/css/core.css" name="core">
    <link rel="canonical" href="https://www.theoperahall.com/">
    <link href="/favicon.ico" rel="shortcut icon" type="image/x-icon">
    <meta name="description" content="Connect with your audience like never before.">
    <meta name="keywords" content="streaming, twitch, youtube, influencer, patron, donate, fan">  
    <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" />    
    <script src="opera/js/sha512.js" type="text/javascript"></script>
    <script src="opera/js/forms.js" type="text/javascript"></script>

</head>
<body>
    <style id="antiClickjack">body { display: none !important; }</style>
    <script>
        if (self === top) {
           var antiClickjack = document.getElementById("antiClickjack");
           antiClickjack.parentNode.removeChild(antiClickjack);
        } else {
           top.location = self.location;
        }
    </script>
    <div id="box">');
}
?>