#!/opt/local/bin/perl5.12

# *************************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2007, 2009. All Rights Reserved. 
#  
# Note to U.S. Government Users Restricted Rights:  Use, 
# duplication or disclosure restricted by GSA ADP Schedule 
# Contract with IBM Corp.
# *************************************************************************************

#--------------------------------------------------------------------------------------
# Hook Name: commit-msg
#
# Description: This hook will check a Git comment for a $WORK_ITEM_SEARCH_STRING and
#              either accept or abort the commit depending on certain conditions which 
#              are specified in the "CUSTOM PROCESS PREFERENCES" global variables. 
#              Example behavior could be to abort the commit if:
#              1. The $WORK_ITEM_SEARCH_STRING is not present in the commit message.
#              2. A valid connection to the RTC server cannot be established.
#              3. The commit message tries to reference a work item that does not
#                 exist. (ex: "WorkItem:999999999")
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
# --Command Line cURL for retrieving a work item--
# curl -v -k -L -b /tmp/cookies.txt -c /tmp/cookies.txt https://serverpath:9443/jazz/oslc/workitems/9.xml
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
#--------------------------------------------------------------------------------------


use strict;
use warnings;
use WWW::Curl::Easy;


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
my $WORK_ITEM_URL = $HOST.$ARGV[5]; # Specify the URL encoded RTC project name (ex: "My%20Project")
my $WORK_ITEM_SEARCH_STRING = $ARGV[6]; # String to use in a Git comment that references a work item (ex: "WorkItem:12 This is my comment.")


# CUSTOM PROCESS PREFERENCES
my $ENABLE_RTC_INTEGRATION = "true"; # Do we want to enable the RTC Integration script?
my $REQUIRE_WORK_ITEM_COMMENT = "true"; # Do we want to abort the commit if the comment does not have a work item reference?
my $ABORT_COMMIT_ON_INVALID_WORK_ITEM_NUM = "true"; # Do we want to abort the commit if the comment references an invalid work item?
my $APPEND_WORK_ITEM_URL_TO_COMMENT = "true"; # Do we want to append the work item URL to the end of the Git comment?

my $COMMENT_FILE = $ARGV[9];
#--------------#
# Start Script #
#--------------#

if ($ENABLE_RTC_INTEGRATION eq "true") { # Do we want to enable RTC Integration?

   print("\n------------------------------\n");
   print("| STARTING 'COMMIT-MSG' HOOK |\n");
   print("------------------------------\n");
	
	if ($REQUIRE_WORK_ITEM_COMMENT eq "true") { 
	
		if (workItem_Reference_Exists() eq "true") {
			REST_Authentication();
			REST_j_security_check();
			REST_retrieve_work_item();
			exit 1; # Force a failed exit if it did not successfully retrieve the work item
		} else {
			print("WARNING: The string \"WorkItem:###\" does not exist in the comment.\n");
			print("Aborting commit...\n\n");
			exit 1; # Abort the commit, there must be a work item reference
		}	
	} else { # The work item reference is not required, but it still may exist
		if (workItem_Reference_Exists() eq "true") {
			REST_Authentication();
			REST_j_security_check();
			REST_retrieve_work_item();
			exit 1; # Force a failed exit if it did not successfully retrieve the work item
		} else {
			print("WARNING: The string \"WorkItem:###\" does not exist in the comment.\n");
			print("Continuing to commit...\n\n");
			exit 0; # Continue to commit if the work item reference does not exist
		}
	}		
} else { 
	exit 0; # The script is turned off, proceed as normal
}



#--------------------------------------------------------------------------------------
# Subroutine: workItem_Reference_Exists()
#
# Description: Check if the $WORK_ITEM_SEARCH_STRING ("WorkItem:###") exists in 
#              the comment.
#
# Return: "true" or "false"
#--------------------------------------------------------------------------------------
sub workItem_Reference_Exists {
	open FILE, "<$COMMENT_FILE" or die $!;
	while (<FILE>) { 
		if (/^$WORK_ITEM_SEARCH_STRING(\d+)/) {
			return "true";
		}
	}
	return "false";
}



#--------------------------------------------------------------------------------------
# Subroutine: REST_Authentication()
#
# Description: Will create a session on the RTC server and store the session 
#              information in the specified $COOKIE_FILE.
#
# Return: none
#--------------------------------------------------------------------------------------
sub REST_Authentication {

	my $CURL = new WWW::Curl::Easy;

	#$CURL->setopt(CURLOPT_VERBOSE, 1); # Prints extra information
	$CURL->setopt(CURLOPT_SSL_VERIFYPEER, 0);
	$CURL->setopt(CURLOPT_SSL_VERIFYHOST, 0);
	$CURL->setopt(CURLOPT_COOKIEFILE, $COOKIE_FILE);
	$CURL->setopt(CURLOPT_COOKIEJAR, $COOKIE_FILE);
	$CURL->setopt(CURLOPT_HEADER,1);
	$CURL->setopt(CURLOPT_URL, $HOST."/authenticated/identidty");
	$CURL->setopt(CURLOPT_FOLLOWLOCATION, 1);

	my $response_body;

	open (my $tempFile, ">", \$response_body);
	$CURL->setopt(CURLOPT_WRITEDATA, $tempFile);

	# Starts the actual request
	my $retcode = $CURL->perform;

	# Looking at the results...
	if ($retcode == 0) {
		print("Creating HTTP session...\n");
		my $response_code = $CURL->getinfo(CURLINFO_HTTP_CODE);
		#print("Received response: $response_body\n"); # Un-comment to print response body
		#print("Reponse Code: $response_code\n"); # Un-comment to print reponse code
	 } else {
		print("An error happened: ".$CURL->strerror($retcode)." ($retcode)\n");
		print("Aborting commit...\n\n");
		exit 1;
	 }
}



#--------------------------------------------------------------------------------------
# Subroutine: REST_j_security_check()
#
# Description: Responsible for creating an authenticated session. This is done by
#              POSTing the RTC $USERNAME and $PASSWORD to the server.
#
# Return: none
#--------------------------------------------------------------------------------------
sub REST_j_security_check {

	my $CURL = new WWW::Curl::Easy;
	my $postData = "j_username=$USERNAME&j_password=$PASSWORD";

	#$CURL->setopt(CURLOPT_VERBOSE, 1); # Prints extra information
	$CURL->setopt(CURLOPT_SSL_VERIFYPEER, 0);
	$CURL->setopt(CURLOPT_SSL_VERIFYHOST, 0);
	$CURL->setopt(CURLOPT_COOKIEFILE, $COOKIE_FILE);
	$CURL->setopt(CURLOPT_COOKIEJAR, $COOKIE_FILE);
	$CURL->setopt(CURLOPT_HEADER,1);
	$CURL->setopt(CURLOPT_POST, 1);
	$CURL->setopt(CURLOPT_POSTFIELDS, $postData);	
	$CURL->setopt(CURLOPT_POSTFIELDSIZE, length($postData));
	$CURL->setopt(CURLOPT_URL, $HOST."/j_security_check");
	$CURL->setopt(CURLOPT_FOLLOWLOCATION, 1);

	my $response_body;

	open (my $tempFile, ">", \$response_body);
	$CURL->setopt(CURLOPT_WRITEDATA, $tempFile);

	# Starts the actual request
	my $retcode = $CURL->perform;

	# Looking at the results...
	if ($retcode == 0) {
		print("Sending login credentials...\n");
		my $response_code = $CURL->getinfo(CURLINFO_HTTP_CODE);
		#print("Received response: $response_body\n"); # Un-comment to print response body
		#print("Reponse Code: $response_code\n"); # Un-comment to print reponse code

	} else {
		print("An error happened: ".$CURL->strerror($retcode)." ($retcode)\n");
		print("Aborting commit...\n\n");
		exit 1;
	}
}



#--------------------------------------------------------------------------------------
# Subroutine: REST_retrieve_work_item()
#
# Description: Creates a request on the RTC server resulting in the return of the 
#              work item specified by the $WORKITEM number. We can determine if the 
#              commit should continue normally or be aborted depending on the
#              response from the RTC server.
#
# Return: none
#--------------------------------------------------------------------------------------
sub REST_retrieve_work_item {

	my $CURL = new WWW::Curl::Easy;
	my $FORMAT = ".xml"; # The format that the work item is to be returned in (could also be .json)
	my $WORKITEM;
	my $FQHOST;

	open FILE, "<$COMMENT_FILE" or die $!;
	while (<FILE>) { # Read the comment file
		if (/^$WORK_ITEM_SEARCH_STRING(\d+)/) {

      		$WORKITEM = $3; # Save the digits (\d+)
	      	#$FQHOST = $HOST."/oslc/workitems/".$WORKITEM.$FORMAT;
	      	$FQHOST = $WORK_ITEM_URL.$WORKITEM;
      
			    #$CURL->setopt(CURLOPT_VERBOSE, 1); # Prints extra information
			    $CURL->setopt(CURLOPT_SSL_VERIFYPEER, 0);
			    $CURL->setopt(CURLOPT_SSL_VERIFYHOST, 0);
			    $CURL->setopt(CURLOPT_COOKIEFILE, $COOKIE_FILE);
			    $CURL->setopt(CURLOPT_COOKIEJAR, $COOKIE_FILE);
			    $CURL->setopt(CURLOPT_HEADER,1);
			    $CURL->setopt(CURLOPT_URL, $FQHOST);
			    #$CURL->setopt(CURLOPT_FOLLOWLOCATION, 1);

	      	my $response_body;

       		open (my $tempFile, ">", \$response_body);
        	$CURL->setopt(CURLOPT_WRITEDATA, $tempFile);

      		# Starts the actual request
        	my $retcode = $CURL->perform;

        	# Looking at the results...
      		if ($retcode == 0) {
				    print("Connection to Work Items server established...\n");
				    my $response_code = $CURL->getinfo(CURLINFO_HTTP_CODE);
				    
           	# Judge result and next action based on $response_code
  			    #print("Received response: $response_body\n"); #Un-comment to print response
           	if ($response_code == 200) {
     	     		print("Successfully verified that work item " . $WORKITEM . " exists.\n");
     	     		
					    if ($APPEND_WORK_ITEM_URL_TO_COMMENT eq "true") {
						    open(COMMENT,">>$COMMENT_FILE") || die("Cannot Open Comments File");	     
						    print(COMMENT "\nWork Item URL: $WORK_ITEM_URL$WORKITEM"); # Append the work item URL to the Git comment
					    }
					    
					    exit 0;
           	} elsif ($response_code == 302) {
					    print("WARNING: Not Authenticated.\n");
					    print("Aborting commit...\n\n");
					    exit 1;
          	} else {
	         		print("WARNING: Work item $WORKITEM does not exist. URL: $FQHOST\n");
	         		
					    if ($ABORT_COMMIT_ON_INVALID_WORK_ITEM_NUM eq "true") {
						    print("Aborting commit...\n\n");
						    exit 1;
					    } else {
						    print("Continuing to commit...\n\n");
						    exit 0;
					    }
				    }
			    } else {
             		print("An error happened: ".$CURL->strerror($retcode)." ($retcode)\n");
	             	print("Aborting commit...\n\n");
	             	exit 1;
			    }
		}
	}
	if ($REQUIRE_WORK_ITEM_COMMENT eq "true") {
		print("WARNING: The string \"WorkItem:###\" does not exist in the comment.\n");
		print("Aborting commit...\n\n");
		exit 1;
	} else {
		exit 0; 
	}
}
