use strict;
use warnings;
use Test::More "no_plan";
use Custom::WebApp::WepaDriver;
use Custom::WebApp;
use Custom::WepaSubs;
use Custom::DbInterface;

my $timestamp = Custom::WepaSubs::get_timestamp();   # Test run's unique id
my $keyword_file = "C:\\Work\\keywords.csv";
my $app_id = 'YouTube';
my $test_plan_name = "Reports";

# CONFIGURE TEST REPORT AND LOGGING OPTIONS
my $res_file = "C:\\Automation\\Results\\Test_Logs\\keywords_test_output.txt";
my $err_file = "C:\\Automation\\Results\\Test_Logs\\keywords_test_error_output.txt";

open (FH, ">$res_file") or die "couldn't open file: $!";
FH->autoflush(1);		# Make FileHandle HOT. Set to 0 to turn autoflush off

Test::More->builder->output (*FH{IO});		        # Redirect test output to result log file
Test::More->builder->failure_output ($err_file);	# and test failures to error log file

my $db = Custom::DbInterface->new();

my $driver = Custom::WebApp::WepaDriver->new(   keyword_file => $keyword_file,
                                                app_name    => $app_id,
                                                mode        => 'csv',
                                                logfile     => *FH{IO},
                                                db          => $db );

my $common_actions = Custom::WebApp->new( driver => $driver );

my $result = $common_actions->{driver}->drive();

# BEGIN POST RUN PROCESSING
pass("test passed") if ($result == 1); # use Test::More pass function, this causes a write to $res_file in the form of OK for  pass or NOT OK for a fail
$common_actions->norun("NO_RUN") if ($result == 999); # use AppUnderTestActionsClass norun function to increase Test::More test counter and print OK or NOT OK to $res_file
fail("test failed") if ($result == 0); # Same as for pass

undef $common_actions;

exit(0);
