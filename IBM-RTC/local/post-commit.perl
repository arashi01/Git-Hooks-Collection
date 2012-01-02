#!/opt/local/bin/perl5.12

#*************************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2007, 2009. All Rights Reserved. 
#  
# Note to U.S. Government Users Restricted Rights:  Use, 
# duplication or disclosure restricted by GSA ADP Schedule 
# Contract with IBM Corp.
# 
# Author: David Lafreniere
# *************************************************************************************

#--------------------------------------------------------------------------------------
# Hook Name: post-commit
#
# Description: This hook will add a new "Related Artifacts" link to the work item 
#              that is indicated in the comment. The visible text of the link will 
#              be the comment itself, while the URL that the link points to will be 
#              the Gitweb page for that particular commit. No RTC server authentication 
#              is done in this hook as it is assumed that it was correctly established 
#              in the commit-msg hook.
#
# Author: David Lafreniere (daviddl@ca.ibm.com)
#
# Modified: June 25th, 2009
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
# --Command Line cURL for creating an authenticated session
# curl -v -k -L -b /tmp/cookies.txt -c /tmp/cookies.txt https://serverpath:9443/jazz/authenticated/identity
# curl -v -k -L -b /tmp/cookies.txt -c /tmp/cookies.txt  -d j_username=myName -d j_password=myPassword https://serverpath:9443/jazz/j_security_check
#
# --Command Line cURL for adding a "Related Artifacts" link--
# curl -v -k -L -b /tmp/cookies.txt -c /tmp/cookies.txt -H "Accept: application/json" -H "Content-Type: application/json" -d '{"rdf:resource":"http://www.google.ca","oslc_cm:label":"http://www.google.ca"}' https://serverpath:9443/jazz/oslc/workitems/9/rtc_cm:com.ibm.team.workitem.linktype.relatedartifact.relatedArtifact
#
# --Command Line cURL for adding a comment to a work item--
# curl -v -k -L -b /tmp/cookies.txt -c /tmp/cookies.txt -H "Accept: text/json" -H "Content-Type: application/x-oslc-cm-change-request+json"  -d '{"dc:description":"My new comment"}' https://serverpath:9443/jazz/oslc/workitems/9/rtc_cm:comments
# See this URL for additional information: https://jazz.net/wiki/bin/view/Main/ResourceOrientedWorkItemAPIv2#Add_a_comment_to_a_work_item
#
# Parameter Notes:
# -v (verbose)    <--> $CURL->setopt(CURLOPT_VERBOSE, 1)
# -k (insecure)   <--> $CURL->setopt(CURLOPT_SSL_VERIFYPEER, 0) AND 
#                      $CURL->setopt(CURLOPT_SSL_VERIFYHOST, 0)
# -L (location)   <--> $CURL->setopt(CURLOPT_FOLLOWLOCATION, 1);
# -b (cookie)     <--> $CURL->setopt(CURLOPT_COOKIEFILE, $COOKIE_FILE)
# -c (cookie-jar) <--> $CURL->setopt(CURLOPT_COOKIEJAR, $COOKIE_FILE)
# -d (post data)  <--> $CURL->setopt(CURLOPT_POST, 1) AND 
#                      $CURL->setopt(CURLOPT_POSTFIELDS, $postData) AND 
#                      $CURL->setopt(CURLOPT_POSTFIELDSIZE, length($postData));
# -H (header)     <--> $CURL->setopt(CURLOPT_HTTPHEADER, \@HEADER );
#--------------------------------------------------------------------------------------


use strict;
use warnings;
use WWW::Curl::Easy;


my $GIT = $ARGV[2]; #location for git executable 

#################################################################################################
## SuperAmerica : Fill in your Jazz username and password                                      ##
## NOTE: Please be careful with these files as they contain username and password information  ##
#################################################################################################

my $USERNAME = $ARGV[0]; # The Jazz username 
my $PASSWORD = $ARGV[1]; # The Jazz password

###############################################################################################
##  You should not have to edit anything below this line  (at least when using linux or mac) ##
###############################################################################################



# WARNING - CHANGE THESE VARIABLES TO REFLECT CUSTOM SERVER SETUP
my $COOKIE_FILE = $ARGV[3]; # The path/filename in which to store the HTTP cookie data from the RTC server
my $HOST = $ARGV[4]; # The URL of the RTC server
my $PRE_GIT_LINK_URL = $ARGV[5]; # The Gitweb path of the private repository
my $WORK_ITEM_SEARCH_STRING = $ARGV[6]; # String to use in a Git comment that references a work item (ex: "WorkItem:12 This is my comment.")


# CUSTOM PROCESS PREFERENCES
my $ENABLE_RTC_INTEGRATION = "true";


# THESE SHOULD NOT CHANGE UNLESS THE RTC REST API CHANGES
my $PRE_HOST_URL = $HOST."/oslc/workitems/";
my $POST_HOST_URL = "/rtc_cm:com.ibm.team.workitem.linktype.relatedartifact.relatedArtifact";



#--------------#
# Start Script #
#--------------#

if ($ENABLE_RTC_INTEGRATION eq "true") {
	print("\n-------------------------------\n");
	print("| STARTING 'POST-COMMIT' HOOK |\n");
	print("-------------------------------\n");
	REST_Add_WorkItem_Link();
	exit 1; # Force a failed exit if it did not successfully add a link
} else { 
	exit 0; # The script is turned off, proceed as normal
}



#--------------------------------------------------------------------------------------
# Subroutine: REST_Add_WorkItem_Link()
#
# Description: Will add a new "Related Artifacts" link to the work item that is 
#              indicated in the comment. The visible text of the link will be the 
#              comment, and the URL that the link points to will be the Gitweb URL
#              for that particular commit.
#
# Return: none
#--------------------------------------------------------------------------------------
sub REST_Add_WorkItem_Link {

	my $CURL = new WWW::Curl::Easy;
	my $COMMENT_DELIMITER = "<Git Comment>";	
	my @HEADER = ("Accept: application/json",
	              "Content-Type: application/json");

	my $FQ_HOST_URL;
	my $FQ_GIT_LINK_URL;
	my $JSON_POST_DATA;
	my $commitID;
	my $gitLogInfo;
	my $gitShowInfo;
	my $gitComment;
	my $gitCommentFiltered;
	my $workItemNum;
	
	
	$gitLogInfo = `$GIT log --pretty=oneline -n1`;
	$gitLogInfo =~ m/^(\w*) /;
	$commitID = $1;
	$gitShowInfo = `$GIT show --pretty=format:"$COMMENT_DELIMITER%s$COMMENT_DELIMITER" $commitID`;
	$gitShowInfo =~ m/$COMMENT_DELIMITER(.*)$COMMENT_DELIMITER/;
	$gitComment = $1;
	
	if ($gitComment =~ m/^$WORK_ITEM_SEARCH_STRING(\d+)/) {
		$workItemNum = $3; 
	} else { # Only continue if we can find a valid work item
		print("WARNING: The string \"WorkItem:###\" does not exist in the comment.\n");
		print("A \"Related Artifacts\" link will not be created...\n\n");
		exit 0;
	}
	
	$gitComment =~ m/^$WORK_ITEM_SEARCH_STRING(\d+) (.*)/;
	$gitCommentFiltered = $4;


	$FQ_HOST_URL = $PRE_HOST_URL . $workItemNum . $POST_HOST_URL;
	$FQ_GIT_LINK_URL = $PRE_GIT_LINK_URL . $commitID;

	$JSON_POST_DATA = "{\"rdf:resource\":\"$FQ_GIT_LINK_URL\",\"oslc_cm:label\":\"$gitCommentFiltered\"}";

	#$CURL->setopt(CURLOPT_VERBOSE, 1); # Prints extra information
	$CURL->setopt(CURLOPT_SSL_VERIFYPEER, 0);
	$CURL->setopt(CURLOPT_SSL_VERIFYHOST, 0);
	$CURL->setopt(CURLOPT_COOKIEFILE, $COOKIE_FILE);
	$CURL->setopt(CURLOPT_COOKIEJAR, $COOKIE_FILE);
	$CURL->setopt(CURLOPT_HEADER, 1);
	$CURL->setopt(CURLOPT_HTTPHEADER, \@HEADER );
	$CURL->setopt(CURLOPT_POST, 1);
	$CURL->setopt(CURLOPT_POSTFIELDS, $JSON_POST_DATA);
	$CURL->setopt(CURLOPT_FOLLOWLOCATION, 1);
	$CURL->setopt(CURLOPT_URL, $FQ_HOST_URL);

	my $response_body;

	open (my $tempFile, ">", \$response_body);
	$CURL->setopt(CURLOPT_WRITEDATA, $tempFile);

	# Starts the actual request
	my $retcode = $CURL->perform;

	# Looking at the results...
	if ($retcode == 0) {
		print("Connection to Work Items server established...\n");
		my $response_code = $CURL->getinfo(CURLINFO_HTTP_CODE);
   
		# judge result and next action based on $response_code
		#print("Received response: $response_body\n"); #Un-comment to print response
		if ($response_code == 201) {
			print("Successfully added a link to work item " . $workItemNum . ".\n\n");
			exit 0;
   		} else {
			print("WARNING: A link was not added to work item $workItemNum.\n");
			print("It is possible that Work Item $workItemNum does not exist on the server.\n\n");
			exit 1;
		}
	} else {
		print("An error happened: ".$CURL->strerror($retcode)." ($retcode)\n\n");
		exit 1;
	}
}
