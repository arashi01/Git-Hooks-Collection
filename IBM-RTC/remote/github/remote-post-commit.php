<?php
$l = explode( '\\"', $_POST["payload"]);

$COMMIT_URL = $l[array_search('timestamp',$l)+6];
$COMMIT_MESSAGE = $l[array_search('message',$l)+2];

$last_line = system("perl /home/schadr/scripts/git-jazz/remote-post-commit.perl ".$COMMIT_URL.' "'.$COMMIT_MESSAGE.'"', $retval);
?>
