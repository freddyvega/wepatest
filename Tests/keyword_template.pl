#!C:/Perl64/bin/perl.exe -w
#################################################################################
#
# Requirements Covered or Test Objective: 
# Test Name: 
# Test Description: 
#
##################################################################################
# Test script logic revolves around three loops.
# 1. a Browser loop
# 2. a Platforms loop
# 3. a Test Data loop
#
# Depending on your specific needs you may want to switch the order of the script logic loops.
# For example below we are:
#
# for each row of data retrieved from the mysql DB>
#				iterate through each platform
#					platform1
#					    iterate through each browser
#						browser1
#						browser2
#					platform2
#					    iterate through each browser
#						browser1
#						browser2
#				finalize run and cleanup
#
use strict;                 # You can remove strict before test script goes live
use warnings;               # You can remove warnings before test script goes live

use Custom::WebApp::WepaDriver;
use Custom::WepaSubs;  	    # Include our utilities module
use Custom::WebApp;	        # Include the AUT test module
use Test::More "no_plan";   # You can change "no_plan" to number of tests to be run

my $timestamp 		= Custom::WepaSubs::get_timestamp();   	# Test run's unique id

# The test is configured by a config file that resides in C:/Automation/Configuration/.templacerc by default
#
my $test_configuration	= Custom::WepaSubs::get_test_config();

# TEST REPORT AND LOGGING
#
open ( my $FH, '>', $test_configuration->{logging}->{results} ) or die "couldn't open file: $!";
$FH->autoflush( 1 );		# Make FileHandle HOT. Set to 0 to turn autoflush off

Test::More->builder->output ( *$FH{IO} );		        # Redirect test output to result log file
Test::More->builder->failure_output ( $test_configuration->{logging}->{errors} );	# and test failures to error log file

# CONFIGURE SCREENSHOT COLLECTION
#
my ( @cap_files, @error_caps );                   		# Screenshot collection init

my $cap_list_ref 	= \@cap_files;		            	# Normal verification screen shots are stored in this reference
my $error_cap_ref 	= \@error_caps;	            		# Error screenshots are stored in this reference

# BROWSERS AND PLATFORMS TESTS WILL BE RUN ON
#
push my @test_browsers, split /,/ , $test_configuration->{browser}->{browsers};    # From configuration file (FFX, SFR, CHR, IE11, ...)
push my @test_platforms, split /,/ , $test_configuration->{platform}->{platforms}; # From configuration file (VISTAx64, VISTAx86, XPx86, WIN7x64, MACx64, ...)

# ITERATE THROUGH EACH BROWSER AND PLATFORM CONBINATION
#
foreach my $browser ( @test_browsers ) {

    foreach my $platform ( @test_platforms ) {

            my $result; # Holds Test::More assertion results e.g. is($result, $expected, $test_title)
            
            my %desired_capabilities = Custom::WebApp::set_capabilities( undef, $browser, $platform );

            # There is no Internet Explorer for MAC
            unless ( ( $browser =~ /IE/ ) && ( $platform =~ /MAC/ ) ) {

		        # Browser Driver (Selenium)
                my $sel_driver = Custom::WebApp::setup_selenium( undef, undef, \%desired_capabilities );

                my $checked_driver = Custom::WebApp::check_driver( undef, $sel_driver );
                
                if ( $checked_driver ) {

                    my $web_app = Custom::WebApp->new(    
								driver          => $sel_driver,
								browser         => $browser,
								platform        => $platform,
								test_site       => $test_configuration->{test}->{app_home},
								app_id          => $test_configuration->{info}->{app_id},
								test_plan_name  => $test_configuration->{info}->{test_plan_name},
								test_timestamp  => $timestamp,
								log_file        => *$FH{IO},
								cap_list_ref    => $cap_list_ref,
								error_cap_ref   => $error_cap_ref,
							     );
		    
					my $kdriver = Custom::WebApp::WepaDriver->new( keyword_file => "C:\\Work\\keywords.csv",
									 app_name    => $test_configuration->{info}->{app_id},
									 mode        => 'csv',
									 logfile     => *$FH{IO},
									 web_app	     => $web_app );

                    Custom::WepaSubs::write_log( 4, "Browser: $browser\n", *$FH{IO} );
                    Custom::WepaSubs::write_log( 4, "Platform: $platform\n", *$FH{IO} );
		    
					$kdriver->drive();
		    
		    
                    $sel_driver->quit();
		    
                    undef $web_app;
		    undef $kdriver;
                }
                else {
                    print 'Capability not matched, skipping test for ' . $browser . ' on ' . $platform . "\n";
                }
            }
    }
}
finalize_run();
# Email results to subscribers
#Custom::WepaSubs::imap_email_results($timestamp, $app_id, $test_plan_name, $test_name, $email_type, $stdout_file, $stderr_file, $conn_type);


sub finalize_run {

    # Strip forward slashes from url and replace with a '.'
    my $test_site = $test_configuration->{test}->{app_home};
    $test_site =~ s/\//./g;
    
    # Save the test run files, after stamping them with the unique id for the test run
    my @return_vals = Custom::WepaSubs::cleanup( $test_configuration->{logging}->{results}, $test_configuration->{logging}->{error}, $test_site, $test_configuration->{info}->{test_plan_name}, $timestamp );
    
    # Cleanup() returns the newly formatted and stamped test run file
    my $test_result_file = $return_vals[0];
    
    # Add test results (from test logs) to the automation_db.test_results_tbl
    Custom::WepaSubs::parse_results( $test_configuration->{info}->{test_plan_name}, $test_result_file, $timestamp );
    
    # Tag test result images and store them in automation_db
    Custom::WepaSubs::commit_image( $timestamp, @cap_files, @error_caps );
    
    # Update the test_run_tbl with this runs unique_id
    my @test_script_name = Custom::WepaSubs::db_get_rows( "SELECT file_name FROM test_script_tbl WHERE id = 130;" );
    Custom::WepaSubs::db_insert_rows( "INSERT INTO test_run_tbl (test_timestamp, test_plan_name, test_script_name, test_name, test_description, app_id, is_active) VALUES ('$timestamp', '$test_configuration->{info}->{test_plan_name}', '$test_script_name[0]', '$test_configuration->{test}->{name}', '$test_configuration->{info}->{description}', '$test_configuration->{info}->{app_id}', 1);" );

    
}
exit(0);
close $FH;
