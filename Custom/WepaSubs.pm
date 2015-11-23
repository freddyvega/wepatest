package Custom::WepaSubs;

use strict;
use warnings;
use MIME::Base64;
use Exporter qw( import );
use DBI qw(:sql_types);
use File::Copy;
use IO::Handle;
use LWP::UserAgent;
use Time::HiRes qw( sleep );
use Switch 'Perl6';
use feature qw( say );
use Net::SMTP::SSL; # auth requires Authen-SASL module
use Email::Simple;
use File::Find::Rule;

use constant { MSSQL_DBSERVER       => 'localhost',       # MSSQL app db server
               MSSQL_DBNAME_SMSI    => 'localhost',       # MSSQL app db schema
               MSSQL_DBNAME_EDCN    => 'localhost',       # MSSQL app db schema
               MYSQL_DBSERVER       => 'localhost',         # Test results db server
               MYSQL_PORT           => '3306',              # MySQL db server default port
               MYSQL_DBNAME         => 'automation_db',     # Default test results db schema
               TRUSTED_CONNECTION   => 'yes',               # MSSQL - Trusted_Connection= parameter
               RESULTS_HTTP_SERVER  => 'localhost' };   # Test results web server

our @EXPORT = qw( $dbtype $dbname $dbun $dbpw );

our $dbtype = "mysql";
our $dbname = "automation_db";
our $dbun   = "username";
our $dbpw   = "password";

sub run_test_suite {

    my $timestamp = get_timestamp();
    my $start_dir = shift;
    my @subdirs;
    #my $level = shift || 2;
    
    if ($start_dir eq 'ALL') {
        @subdirs = File::Find::Rule->directory->in('C:\\Automation\\Tests\\');
    }
    else {
        @subdirs = File::Find::Rule->directory->in($start_dir);
    }
    
    
    my @files = File::Find::Rule->file()
                                ->name( '*.pl' )
                                #->maxdepth( $level )
                                ->in( $subdirs[0] );
    
    foreach (@files) {
      system ($_);
    }
}
sub write_log {
# Possible codes are:
#	    Msg Type | Msg Code
#	    INFO     |    1
#	    WARN     |    2
#	    DEGUG    |    3
#	    WRITE    |    4    
    my $code        = $_[0];  						# get message code and text
    my $msg         = $_[1];						# message string
    my $logfile     = $_[2];					# log file handle
    my @code_map    = ('', 'INFO', 'WARN', 'DEBUG', 'WRITE' );  	# map of numeric codes to message types
    my $msg_type    = $code_map[$code];  				# map code to human-readable message type
    my $timestamp   = get_timestamp();				# get time

    if ($msg_type eq "WRITE"){
        say $logfile "$msg";	# create the log string and write it to file
    }
    else {
        say $logfile "$timestamp $msg_type $msg";	# create the log string and write it to file
    }

}
sub wait_for {

    my $time = shift;

    Time::HiRes::sleep($time);

}
sub get_timestamp {
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

    $year += 1900;
    $mon++;

    return $year . sprintf('%02u%02u_%02u%02u%02u', $mon, $mday, $hour, $min, $sec);
    
}
sub convert_to_mysql_datetime {
    
    my $test_timestamp = shift;
    my $mode = shift;

    my $year    = substr $test_timestamp, 0, 4;
    my $month   = substr $test_timestamp, 4, 2;
    my $day     = substr $test_timestamp, 6, 2;
    my $hour    = substr $test_timestamp, 9, 2;
    my $min     = substr $test_timestamp, 11, 2;
    my $sec     = substr $test_timestamp, 13, 2;

    my $mysql_datetime;
    
    if (defined $mode) {
        if ($mode eq 'time') {
            return $mysql_datetime = "$hour:$min";
        }
        elsif ($mode eq 'squish_time') {
            return $mysql_datetime = "$year-$month-$day" . "T" . "$hour-$min-$sec";
        }
        else {
            if ($month =~ /^0/) { # Remove the leading zero in months 1-9
                ($month) = substr $month, 1, 1;
            }
            return $mysql_datetime = "$day-$month-$year";
        }
    }
    else {
        return $mysql_datetime = "$year-$month-$day $hour:$min:$sec";
    }
    

}
sub get_epoch_time {
    
    my $test_timestamp = shift;

    my $query = "SELECT UNIX_TIMESTAMP('$test_timestamp');";
    my $dbh = db_get_handle();

    my $epoch_time = $dbh->selectrow_array($query);
    print "Run folders estimated Epoch Time: " . $epoch_time . "\n";
    return $epoch_time;
}
sub db_get_handle {
    
    my $db_type = shift || undef; # Default type is MySQL
    my $app_id = shift || undef; # Default is none
    my ($dbh, $db_dsn);
    
    if ($db_type){

        if ($db_type eq 'mssql') {

            if ($app_id) {

                given ($app_id) {
                    when 'APPID1'  { $db_dsn = "Driver={SQL Server};Server={".MSSQL_DBSERVER."};Database=".MSSQL_DBNAME_EDCN.";Trusted_Connection=".TRUSTED_CONNECTION.""; }
                    when 'APPID2'  { $db_dsn = "Driver={SQL Server};Server={".MSSQL_DBSERVER."};Database=".MSSQL_DBNAME_SMSI.";Trusted_Connection=".TRUSTED_CONNECTION.""; }
                    when '' { }
                }
            }
            $dbh = DBI->connect("DBI:ODBC:$db_dsn",
                                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });
        }

    }
    else {  # If $db_type is not passed in then we use the default - MySQL

        
        my $dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
        $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                    { RaiseError => 1, PrintError => 1, AutoCommit => 1 });
    }
    return $dbh;
    
}
sub db_get_st_handle {
    
    my $dbh = shift;
    my $query = shift;
    
    my $sth = $dbh->prepare($query);
    
    return $sth;
    
}
sub db_execute {
    
    my $sth = shift;
    
    $sth->execute()           # Execute the query
                            or die "Cannot execute the query: $sth->errstr\n";
                            
}
sub db_cleanup {
    
    my $dbh = shift;
    my $sth = shift;
    
    $sth->finish(); 	# Release the statement handler
    
    $dbh->disconnect  	# Release the database handler
          or warn "Disconnection failed: $DBI::errstr\n";

}
sub db_get_rows {
    
    my $query 	= "$_[0]";
    my $db_name = $_[1] || undef;
    my ($dsn, $dbh, @return_rows);

    # This is the default case - Automation_DB
    unless (defined $db_name) {
	$dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
	$dbh = DBI->connect( $dsn, $dbun, $dbpw,
		    { RaiseError => 1, PrintError => 1, AutoCommit => 1 });
    }
    # Use the Amazon Web Services system
#    else {
#	if ($db_name eq 'campaigns') {
#	    $dsn = "DBI:$dbtype:$db_name:" . MYSQL_DBSERVER_SS1 . ":" . MYSQL_PORT;
#	}
#	elsif ($db_name eq 'store') {
#	    $dsn = "DBI:$dbtype:$db_name:" . MYSQL_DBSERVER_SS2 . ":" . MYSQL_PORT;
#	}
#	    my $dbun = 'username';
#	    my $dbpw = 'password';
#	    $dbh = DBI->connect( $dsn, $dbun, $dbpw,
#			{ RaiseError => 1, PrintError => 1, AutoCommit => 1 });
#    }


    #my $dbh = DBI->connect( "DBI:$dbtype:$dbname", $dbun, $dbpw,
    #      { RaiseError => 1, PrintError => 1, AutoCommit => 1 }); 
    
    my $sth = $dbh->prepare($query);    # Prepare the query
          
    $sth->execute()           # Execute the query
          or die "Cannot execute the query: $sth->errstr\n";

    my $count = 0;
    while ( my @row = $sth->fetchrow_array(  ) ) {
                    $count++;
                    #print "Row $count: @row\n";
                    push (@return_rows, @row);
    }	
    $sth->finish(); 	# Release the statement handler
    
    $dbh->disconnect  	# Release the database handler
          or warn "Disconnection failed: $DBI::errstr\n";
          
    return @return_rows;  	# Return rows
    
}
# returns only one row
sub db_get_rows_hashref {
    
    my $query = "@_";
    my $return_rows;

    my $dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
    my $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });

    #my $dbh = DBI->connect( "DBI:$dbtype:$dbname", $dbun, $dbpw,
    #      { RaiseError => 1, PrintError => 1, AutoCommit => 1 }); 
    
    my $sth = $dbh->prepare($query);    # Prepare the query
          
    $sth->execute()           # Execute the query
          or die "Cannot execute the query: $sth->errstr\n";

    my $count = 0;
    #while ( my @row = $sth->fetchall_hashref( 'test_timestamp' ) ) {
    #                $count++;
    #                #print "Row $count: @row\n";
    #                push (%return_rows, @row);
    #}
    $return_rows = $sth->fetchrow_hashref();
    #$return_rows = $sth->fetchall_arrayref({});
    $sth->finish(); 	# Release the statement handler
    
    $dbh->disconnect  	# Release the database handler
          or warn "Disconnection failed: $DBI::errstr\n";
          
    return  $return_rows;  	# Return rows
    
}
# Returns a reference to a hash containing a key for each distinct value of
# the $key_field column that was fetched
sub db_get_all_rows_hashref {
    
    #my $query = "@_";
    my $query       = shift;
    my $key_field   = shift;
    my $return_rows;

    my $dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
    my $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });
    
    my $sth = $dbh->prepare($query);    # Prepare the query
          
    $sth->execute()           # Execute the query
          or die "Cannot execute the query: $sth->errstr\n";

    my $count = 0;
#    while ( my @row = $sth->fetchall_hashref( 'id' ) ) {
#                    $count++;
#                    #print "Row $count: @row\n";
#                    push ($return_rows, @row);
#    }
	$return_rows = $sth->fetchall_hashref( $key_field );

    $sth->finish(); 	# Release the statement handler
    
    $dbh->disconnect  	# Release the database handler
          or warn "Disconnection failed: $DBI::errstr\n";
          
    return  $return_rows;  	# Return rows
    
}
sub db_get_rows_arrayref {
    
    my $query = "@_";
    my $return_rows;

    my $dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
    my $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });

    my $sth = $dbh->prepare($query);    # Prepare the query
          
    $sth->execute()           # Execute the query
          or die "Cannot execute the query: $sth->errstr\n";

    my $count = 0;

    $return_rows = $sth->fetchall_arrayref({});
    $sth->finish(); 	# Release the statement handler
    
    $dbh->disconnect  	# Release the database handler
          or warn "Disconnection failed: $DBI::errstr\n";
          
    return  $return_rows;  	# Return rows
    
}
sub db_insert_rows {
    
    my $query = "@_";
    my $last_col_id;
    my $ret_last_col_id_flag = 0;

    my $dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
    my $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });

    $dbh->quote($query);
    
    my $sth = $dbh->prepare($query);

    my $exec_stat = $sth->execute() or die "Cannot execute the query: $sth->errstr\n";
    # If query is an UPDATE we do not need last column inserted id
    unless ( $query =~ /UPDATE/i ) {
            $last_col_id = $dbh->last_insert_id(undef, undef, undef, undef);
            $ret_last_col_id_flag = 1;
    }
    $dbh->disconnect  		            # Release the database handler
                    or warn "Disconnection failed: $DBI::errstr\n";	
    
    if ( $ret_last_col_id_flag == 1 ){
            return $last_col_id;
    }
    else {
            return $exec_stat;
    }
}
sub db_reset_table {

	my $table_name = shift;
	my $dbname = shift;
	my $dbun = shift;
	my $dbpw = shift;
	my $query = "TRUNCATE TABLE '$table_name';";

    my $dsn = "DBI:$dbtype:$dbname:" . "localhost" . ":" . MYSQL_PORT;
    my $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });

    my $sth = $dbh->prepare($query);    # Prepare the query

    $sth->execute()           # Execute the query
          or die "Cannot execute the query: $sth->errstr\n";

    $sth->finish(); 	# Release the statement handler
    
    $dbh->disconnect  	# Release the database handler
          or warn "Disconnection failed: $DBI::errstr\n";
}
sub cleanup {

    my $res_file = $_[0];
    my $err_file = $_[1];	
    my $test_site = substr $_[2], 7 || undef;  			# Strip http:// from URL
    $test_site =~ s/\?/./g;					# Strip any question marks (?) from URL
    my @return_vals;

    my $timestamp = $_[4];
    my $test_plan_name = join ('-', $_[3], $timestamp);
    
    if (defined $res_file){
            my $stamped_res_file = join ('.', $res_file,$test_site,$timestamp);
            copy ($res_file, $stamped_res_file) or die "File copy failed: $!";
            push @return_vals, $stamped_res_file;
    }
    if (defined $err_file){
            my $stamped_err_file = join ('.', $err_file,$test_site,$timestamp);
            copy ($err_file, $stamped_err_file) or die "File copy failed: $!";
            #push @return_vals, $timestamp;
    }
    return @return_vals;
    
}
sub commit_image {

    my ( $timestamp,
         @p_image_files ) = @_;
    
    my @image_files = grep{/png/} @p_image_files;	# Only get PNG's for now

    my $query = "INSERT INTO test_results_image_tbl (image_name, test_timestamp) VALUES (?, ?);";

    my $dsn = "DBI:$dbtype:$dbname:" . MYSQL_DBSERVER . ":" . MYSQL_PORT;
    my $dbh = DBI->connect( $dsn, $dbun, $dbpw,
                { RaiseError => 1, PrintError => 1, AutoCommit => 1 });
    
    foreach my $image_file (@image_files) {

            my $sth = $dbh->prepare($query);
            
            $sth->bind_param(1, $image_file);
            $sth->bind_param(2, $timestamp);
            
            $sth->execute()           # Execute the query
                  or die "Cannot execute the query: $sth->errstr\n";
            
            $sth->finish(); 		# Release the statement handler
    }
    $dbh->disconnect  			# Release the database handler
            or warn "Disconnection failed: $DBI::errstr\n";    
}
sub commit_results {
    
    my %query_vars = @_;
    my $last_col_id = $query_vars{last_col_id};

    my $dbh = db_get_handle();


    #if ($query_vars{commit_type} eq 'update') {
    if (defined $query_vars{commit_type}) {

        my $image_link = $query_vars{image_link};
        my $query2 = "UPDATE test_results_tbl SET image_link = ? WHERE id = $last_col_id;";

        $dbh->do($query2, undef, $image_link);

    } else {
        my $query = "INSERT INTO test_results_tbl (test_result, test_id, test_case_name, test_case_details, test_timestamp, browser, platform, image_link) VALUES ('$query_vars{test_result}','$query_vars{test_id}','$query_vars{test_case_name}','$query_vars{test_case_details}','$query_vars{test_timestamp}', '$query_vars{browser}', '$query_vars{platform}', '$query_vars{image_link}');";

        $dbh->quote($query);

        my $sth = $dbh->prepare($query);
        
        $sth->execute()           # Execute the query
            or die "Cannot execute the query: $sth->errstr\n";
        
        $last_col_id = $dbh->last_insert_id(undef,undef,undef,undef);      # Used to keep track of the last inserted row.
    }


    $dbh->disconnect
            or warn "Disconnection failed: $DBI::errstr\n";    
    
    return $last_col_id;
    
}
sub parse_results {
    
    my $file = $_[1];
    my %query_vars;
    my $holdingv;
    
    $query_vars{test_plan_name} = $_[0];
    $query_vars{test_timestamp} = $_[2];
    
    open FILE, $file or die "couldn't open file: $!";
    
    my $count = 0; # Used to keep track of line  numbers
    
    while (<FILE>) {
        my ($test_result, $test_id, $test_case_name, $test_case_details, $test_timestamp, $browser);
        
        chomp;
        my @lines = split ( /,/ , $_ );
        
        if ( $lines[0] eq 'Capability not matched') {
            $query_vars{test_id} = $count;
            $query_vars{test_case_name} = $lines[0] . ', ' . $lines[1];
            $query_vars{test_result} = 'EXCEPTION';
            $query_vars{browser} = substr $lines[1], 19, 3;
            $query_vars{platform} = substr $lines[1], 26;
            $query_vars{last_col_id} = commit_results(%query_vars);
            last;
        }
        
        foreach my $line (@lines) {
            unless ($_ eq "\n") {
                
                $query_vars{test_case_details} = ""; # clear out test case details
                if ((substr $line, 0, 2) =~ /ok/) {     # Its a PASS test result
                    $test_result = substr $line, 0, 2;
                    if ($count <= 8) {
                    	#if ($count == 0) { # pick up Username: from result log
                    	#	#$test_case_details = $holdingv;
                    		$query_vars{test_case_details} = $holdingv;
                    	#}
                        $test_id = substr $line, 3, 1;
                        $test_case_name = substr $line, 7;
                        
                    }
		    elsif ($count <= 98) {
                        $test_id = substr $line, 3, 2;
                        $test_case_name = substr $line, 8;
                        
                    }
		    elsif ($count <= 998) {
                        $test_id = substr $line, 3, 3;
                        $test_case_name = substr $line, 9;
                    }
                    $query_vars{test_result} = $test_result;
                    $query_vars{test_case_name} = $test_case_name;
                    $query_vars{test_id} = $test_id;
                    
                } elsif ((substr $line, 0, 3) =~ /not/) {   # Its a FAIL test result
                    $test_result = substr $line, 0, 6;
                    if ($count <= 8) {
                    	#if ($count == 0) { # pick up Username: from result log
                    	#	#$test_case_details = $holdingv;
                    		$query_vars{test_case_details} = $holdingv;
                    	#}
                        $test_id = substr $line, 7, 1;
                        $test_case_name = substr $line, 11;
                        
                    }
		    elsif ($count <= 98) {
                        $test_id = substr $line, 7, 2;
                        $test_case_name = substr $line, 12;
                        
                    }
		    elsif ($count <= 998) {
                        $test_id = substr $line, 7, 3;
                        $test_case_name = substr $line, 13;
                    }
                    $query_vars{test_result} = $test_result;
                    $query_vars{test_case_name} = $test_case_name;
                    $query_vars{test_id} = $test_id;

                }
		elsif ((substr $line, 0, 8) =~ /Browser:/) {
                    $query_vars{browser} = substr $line, 9;

                }
		elsif ((substr $line, 0, 9) =~ /Platform:/) {
                    $query_vars{platform} = substr $line, 10;

                }
		elsif ((substr $line, 0, 9) =~ /Username:/) {
                	#$query_vars{test_case_details} = substr $line, 10;
                	$holdingv = substr $line, 10;
                	
                }
                elsif ((substr $line, 0) =~ /Automation/) { # This is a screen capture so save it
                    $query_vars{image_link} = qq{$line};
                    $query_vars{commit_type} = 'update';
                    $query_vars{last_col_id} = commit_results(%query_vars) unless ($count == 0); # unless hack
                    $query_vars{commit_type} = undef; # hack
                    $query_vars{image_link} = undef;  # hack
                    #$count++;
                }
                # If none of the above is matched then we assume whats coming are Test Case Details so use them
                else {
                    unless (($line =~ /^\n/) or ($line =~ /^1../)) {
                        $line =~ s/'//g;
                        if ($line =~ /^$/){
                            unless (defined $query_vars{test_case_details}) {
                                $test_case_details = $test_case_name;
                            }
                        }
			else {
                            $test_case_details = $line;
                        }
                        $query_vars{test_case_details} = $test_case_details;
                    }
                }
            }
        }
        if ((defined $test_case_name) or (defined $test_case_details) or (defined $test_id) or (defined $test_result)){
                $query_vars{last_col_id} = commit_results(%query_vars);
                $count++;
        }
    }
    # Update the database to reflect this run's parsed status (i.e. set parsed flag to true)
    Custom::WepaSubs::db_insert_rows("UPDATE test_run_tbl SET parsed = true WHERE test_timestamp = '$query_vars{test_timestamp}'");

    close FILE;
}
sub parse_substep_results {

    my $file = $_[0];
    my %query_vars;
    
    $query_vars{filename}       = $_[0];
    $query_vars{test_timestamp} = $_[1];
    $query_vars{app_id}         = $_[2];
    $query_vars{test_case_step} = $_[3];
    
    open FILE, $file or die "couldn't open file: $!";
    
    my $count = 0; # Used to keep track of line  numbers
    
    while (<FILE>) {
        my ($test_result, $test_id, $test_case_name, $test_case_details);
        
        chomp;
        my @lines = split ( /\n/ , $_ );
        
        foreach my $line (@lines) {
            unless ($_ eq "\n" or $_ =~ /^1../) {
                
                $query_vars{test_case_details} = "";
                if ((substr $line, 0, 2) =~ /ok/) {     # Its a PASS test result
                    $test_result = substr $line, 0, 2;
                    if ($count <= 8) {
                        $test_id = substr $line, 3, 1;
                        $test_case_name = substr $line, 7;
                        
                    }
		    elsif ($count <= 98) {
                        $test_id = substr $line, 3, 2;
                        $test_case_name = substr $line, 8;
                        
                    }
		    elsif ($count <= 998) {
                        $test_id = substr $line, 3, 3;
                        $test_case_name = substr $line, 9;
                    }
                    $query_vars{test_result} = $test_result;
                    $query_vars{test_case_name} = $test_case_name;
                    $query_vars{test_id} = $test_id;
                    
                }
                elsif ((substr $line, 0, 3) =~ /not/) {   # Its a FAIL test result
                    $test_result = substr $line, 0, 6;
                    if ($count <= 8) {
                        $test_id = substr $line, 7, 1;
                        $test_case_name = substr $line, 11;
                        
                    }
		    elsif ($count <= 98) {
                        $test_id = substr $line, 7, 2;
                        $test_case_name = substr $line, 12;
                        
                    }
		    elsif ($count <= 998) {
                        $test_id = substr $line, 7, 3;
                        $test_case_name = substr $line, 13;
                    }
                    $query_vars{test_result} = $test_result;
                    $query_vars{test_case_name} = $test_case_name;
                    $query_vars{test_id} = $test_id;

                }
                $query_vars{last_col_id} = commit_substep_results(%query_vars);
            }
        }
    }
    close FILE;
}
sub commit_substep_results {
    
    my %query_vars = @_;
    my $last_col_id = $query_vars{last_col_id};

    my $dbh = db_get_handle();


    #if ($query_vars{commit_type} eq 'update') {
    if (defined $query_vars{commit_type}) {

        my $image_link = $query_vars{image_link};
        my $query2 = "UPDATE test_results_tbl SET image_link = ? WHERE id = $last_col_id;";

        $dbh->do($query2, undef, $image_link);

    }
    else {
        my $query = qq/INSERT INTO test_substep_results_tbl (test_timestamp, step, substep, result, description, app_id, filename) VALUES ('$query_vars{test_timestamp}','$query_vars{test_case_step}','$query_vars{test_id}','$query_vars{test_result}','$query_vars{test_case_name}','$query_vars{app_id}','$query_vars{filename}')/;

        #$dbh->quote($query);

        my $sth = $dbh->prepare($query);
        
        $sth->execute()           # Execute the query
            or die "Cannot execute the query: $sth->errstr\n";
        
        $last_col_id = $dbh->last_insert_id(undef,undef,undef,undef);      # Used to keep track of the last inserted row.
    }


    $dbh->disconnect
            or warn "Disconnection failed: $DBI::errstr\n";    
    
    return $last_col_id;
    
}
# Takes the following parameters:
# ($timestamp, $app_id, $test_plan_name, $test_name, $email_type, $stdout_file, $stderr_file, $conn_type)
sub imap_email_results {

    my @arg_count = @_;

    my $timestamp = $_[0];
    my $app_id = $_[1];
    my $test_plan_name = $_[2];
    my $test_name = $_[3];
    my $email_type = $_[4];
    my $stdout_file = $_[5];
    my $stderr_file = $_[6];
    my $conn_type = $_[7];

    my ($smtp, $smtp_user, $smtp_pword, $msg_text, $msg_text_error, @cap_files);

    if ($#arg_count > 7) {					# Passed in args greater than seven are assumed to be screen capture files
            push @cap_files, @arg_count[8..$#arg_count];	# so we stuff them in a list to email as attachments
    }
    if (defined $stdout_file){				# If we passed in a test result file open it
    
            open STDOUT_FILE, $stdout_file or die "couldn't open file: $!";
            $msg_text = join("", <STDOUT_FILE>);		# and join it to msg_text to be used as the email body
            close STDOUT_FILE;
    }
    if (defined $stderr_file){				# If we passed in an error file (because there were errors) open it

            open STDERR_FILE, $stderr_file or die "couldn't open file $!";
            $msg_text_error = join("", <STDERR_FILE>);	# and join it to msg_text_error to be used in the email body
            close STDERR_FILE;
    }
    if ($conn_type eq 'SSL') {

        # connect to SMTP server (SSL)
        $smtp_user = 'qa.automation@gmail';
        $smtp_pword = 'ebqa';
        $smtp = Net::SMTP::SSL->new('smtp.gmail.com', Port => 465, Debug => 0);
        my $result = $smtp->auth($smtp_user, $smtp_pword);
    }
    else {

        # connect to SMTP server (NO SSL)
        $smtp_user = 'qa.automation@teamvgp.com'; # Moot
        $smtp = Net::SMTP->new('localhost', Port => 25, Debug => 0);
        my $result = $smtp->auth();
    }
    # Create email depending on the type being being sent
    given ($email_type) {
            when "ERROR" {

                my $recip_file = "C:\\Automation\\EmailRecipients\\error_email_recipient_list.txt"; # subscribe to emails by adding email address here


                $msg_text .= "If connected to the corporate network, click the link to view the results:\n\nhttp://". RESULTS_HTTP_SERVER . "/cgi-bin/results_dash.pl?rm=mode_4&timestamp=$timestamp\n\nThis is an automatically generated message.";

                open RECIPIENTS, $recip_file or die "couldn't open file: $!";

                while (<RECIPIENTS>)					# Iterate through each line in the recpient file containing a comma separated list of email addresses
                {
                        chomp;
                        my @recipient_list = split ( /,/ , $_ );	# Split each line at a comma and stuff it into recipient list
                        foreach my $recipient (@recipient_list) {		# And for each of those repicients

                                # create message method call
                                my $imap_email = Email::Simple->create (
                                                                header => [
                                                                           From => 'qa.automation@teamvgp.com',
                                                                           To	=> $recipient,
                                                                           Subject => "[Automation][$app_id][$test_plan_name][ERROR] $test_name Test Run Results"],
                                                                body => $msg_text
                                                                );
                                my $email_body = $imap_email->as_string;
                                my $rfc822_msg = \$email_body;

                                # send the message via SMTP
                                $smtp->mail($smtp_user);
                                $smtp->recipient($recipient);
                                $smtp->data($email_body);
                        }
                }
            }
            when "SPECIAL" {
                # Send an email after deletion of user with dump of data that was deleted.
                my $recip_file = "C:\\Automation\\EmailRecipients\\special_email_recipient_list.txt"; # subscribe to emails by adding email address here

                $msg_text .= "Associated event record information, if any existed for deleted user, is available here\n";

                open RECIPIENTS, $recip_file or die "couldn't open file: $!";

                while (<RECIPIENTS>) {					# Iterate through each line in the recpient file containing a comma separated list of email addresses

                        chomp;
                        my @recipient_list = split ( /,/ , $_ );	# Split each line at a comma and stuff it into recipient list
                        foreach my $recipient (@recipient_list) {		# And for each of those repicients

                                # create message method call
                                my $imap_email = Email::Simple->create (
                                                                header => [
                                                                           From => 'qa.automation@teamvgp.com',
                                                                           To	=> $recipient,
                                                                           Subject => "[WEPA-QA][SPECIAL][$app_id] has been deleted"], # change special to whatever is "special"
                                                                body => $msg_text
                                                                );
                                my $email_body = $imap_email->as_string;
                                my $rfc822_msg = \$email_body;

                                # send the message via SMTP
                                $smtp->mail($smtp_user);
                                $smtp->recipient($recipient);
                                $smtp->data($email_body);
                        }
                }
            }
            default {

                my $recip_file = "C:\\Automation\\EmailRecipients\\email_recipient_list.txt"; # subscribe to emails by adding email address here


                $msg_text .= "If connected to the corporate network, click the link to view the results:\n\nhttp://". RESULTS_HTTP_SERVER . "/cgi-bin/results_dash.pl?rm=mode_4&timestamp=$timestamp\n\nThis is an automatically generated message.";

                open RECIPIENTS, $recip_file or die "couldn't open file: $!";

                while (<RECIPIENTS>)					# Iterate through each line in the recpient file containing a comma separated list of email addresses
                {
                        chomp;
                        my @recipient_list = split ( /,/ , $_ );	# Split each line at a comma and stuff it into recipient list
                        foreach my $recipient (@recipient_list) {		# And for each of those repicients

                                # create message method call
                                my $imap_email = Email::Simple->create (
                                                                header => [
                                                                           From => 'qa.automation@teamvgp.com',
                                                                           To	=> $recipient,
                                                                           Subject => "[Automation][$app_id][$test_plan_name] $test_name Test Run Results"],
                                                                body => $msg_text
                                                                );
                                my $email_body = $imap_email->as_string;
                                my $rfc822_msg = \$email_body;

                                # send the message via SMTP
                                $smtp->mail($smtp_user);
                                $smtp->recipient($recipient);
                                $smtp->data($email_body);
                        }
                }
            }
    }
    $smtp->quit;
}
#
# Mine automation_db.test_results_tbl and look for work to do:
# (i.e. records whose 'completed' flags are set to false)
# Updates automation_db.test_run_tbl with PASS / FAIL (NOT OK / OK respectively)
#
sub run_status_update {

    my $test_timestamp = shift;

    my $sql = "SELECT count(*)
	      FROM test_results_tbl
	      WHERE test_timestamp = '$test_timestamp'
	      AND test_result = 'not ok';";

    my $sql2 = "SELECT count(*)
               FROM test_results_tbl
               WHERE test_timestamp = '$test_timestamp'
               AND test_result = 'EXCEPTION';";

    my $dbh = Custom::WepaSubs::db_get_handle();

    my $sth = Custom::WepaSubs::db_get_st_handle($dbh, $sql);
    my $sth2 = Custom::WepaSubs::db_get_st_handle( $dbh, $sql2 );

    Custom::WepaSubs::db_execute($sth);
    Custom::WepaSubs::db_execute($sth2);

    # Failed tests are those with NOT OK in the test_result field
    my $fail_tests = $sth->fetchrow_array();
    my $exception_tests = $sth2->fetchrow_array();
    
    if ($exception_tests > 0) {
        Custom::WepaSubs::db_insert_rows("UPDATE test_run_tbl SET status = 'EXCEPTION' WHERE test_timestamp = '$test_timestamp';")
    }
    
    unless ( $exception_tests > 0 ) {
        
        if ($fail_tests == 0) { # There were no failures (i.e. all OK)
            Custom::WepaSubs::db_insert_rows("UPDATE test_run_tbl SET status = 'PASS' WHERE test_timestamp = '$test_timestamp';");
        }    
        else {                  # There were failures (i.e. NOT OK)
            Custom::WepaSubs::db_insert_rows("UPDATE test_run_tbl SET status = 'FAIL' WHERE test_timestamp = '$test_timestamp';");
        }
    }

    
    Custom::WepaSubs::db_insert_rows("UPDATE test_run_tbl SET completed = true WHERE test_timestamp = '$test_timestamp';");
    Custom::WepaSubs::db_insert_rows("UPDATE test_results_tbl SET completed = true WHERE test_timestamp = '$test_timestamp';");
    
    my @handles;
    push @handles, $sth, $sth2;
    foreach my $handle ( @handles ) {
        $handle->finish();
    }
    $dbh->disconnect();
    #Custom::WepaSubs::db_cleanup($dbh, $sth2);
    #Custom::WepaSubs::db_cleanup($dbh, $sth);
    
    return ($fail_tests, $exception_tests);

}
# Not my sub. but cool enough to include here
sub array_diff1(\@\@) {
	my %e = map { $_ => undef } @{$_[1]};
	return @{[ ( grep { (exists $e{$_}) ? ( delete $e{$_} ) : ( 1 ) } @{ $_[0] } ), keys %e ] };
}
# Compare two arrays and determine if they differ
# 1 = Arrays have a different number of keys: Don't match
# 0 = Arrays have the same keys: They do match
sub array_diff_map {
    my ($array1, $array2) = @_;
    my @array1 = @$array1;
    my @array2 = @$array2;

    my %array1_hash;
    my %array2_hash;

    map { $array1_hash{$_} += 1 } @array1;
    map { $array2_hash{$_} += 2 } @array2;

    for my $key ( keys %array1_hash ) {
	if ( not exists $array2_hash{$key} 
	   or $array1_hash{$key} != $array2_hash{$key} ) {
	   return 1;   #Array element text differs
	}
    }
    if ( keys %array2_hash != keys %array1_hash ) {
     return 1;  #Arrays have a different number of keys: Don't match
    }
    else {
	 return;    #Arrays have the same keys: They do match
    }
}
# Compare two arrays and determine if they differ
# 1 = Arrays differ
# 0 = Arrays contain the same elements
sub array_diff {
    my ($array1, $array2) = @_;
    my @array1 = @$array1;
    my @array2 = @$array2;

    my %array1_hash;
    my %array2_hash;

    # Create a hash entry for each element in @array1
    for my $element ( @array1 ) {
       $array1_hash{$element} = @array1;
    }

#    for my $element2 ( @array2 ) {
#	$array2_hash{$element2} = @array2;
#    }
    # Same for @array2: This time, use map instead of a loop
    map { $array2_hash{$_} => 1 } @array2;

    for my $entry ( @array2 ) {
        if ( not $array1_hash{$entry} ) {
            return 1;  #Entry in @array2 but not @array1: Differ
        }
    }
    if ( keys %array1_hash != keys %array2_hash ) {
       return 1;   #Arrays differ
    }
    else {
       return 0;   #Arrays contain the same elements
    }
}
# Pass in an array and get a comma separated list back of all its members
sub array_to_string {
    my $val = shift;
    my $string;
    my $count = 0;

    foreach (@$val) {
        unless ($count == 0) {
            $string .= ',' . $_;
            $count++;
        }
        else {
            $string .= $_;
            $count++;
        }
    }

    return $string;
}
# Get a Config::Tiny configuration object to be used by a test case
# Default is 'C:/Automation/Configuration/.templaterc'
sub get_test_config {
    
    my $config_file_path = shift || undef;

    use Config::Tiny;
    
    return my $configuration = ($config_file_path ? Config::Tiny->read($config_file_path) : Config::Tiny->read('C:/Automation/Configuration/default_config.ini'));
}
# Same as above but more expressive / lengthier
sub get_test_config2 {

    my $config_file_path = shift || undef;
    my $configuration;

    use Config::Tiny;
    
    unless ($config_file_path) {
	$configuration = Config::Tiny->read('C:/Automation/Configuration/.templaterc'); # Load Default test specific configuration parameters
    }
    else {
	$configuration = Config::Tiny->read($config_file_path); # Load test specific configuration parameters
    }

    return $configuration;
}
#
sub insert_into_table {
    
    my $table = shift;
    my $filename = shift;
    my $start_id = shift;
    my $end_id = shift;
    
    open(my $fh, '<:encoding(UTF-8)', $filename)
  or die "Could not open file '$filename' $!";
  
  my $new_file = "C:/Automation/newsql.sql";
  my $id = $start_id;
  
  open(FILE, '>', $new_file) or die "Could not create new file '$new_file' $!";
  
  while (my $row = <$fh>) {
    chomp $row;
    
    my $first_part = 'INSERT INTO `' . $table . '` VALUES (';
    my $first_length = length($first_part);
    my $second_part = substr($row, $first_length);
    my $new_line = $first_part . "'". $id . "'," . $second_part . "\n";
    
    print FILE $new_line;
    
    $id += 1;
    
  }
  
  close $fh;
  close FILE;
  
  if ($id == $end_id) {
    return 1;
  }
  return 0;
}
#

sub update_total_table {
    
    my $dbh = Custom::WepaSubs::db_get_handle();
    my $sth;
    open OUTPUT, '>', "total_tests.txt" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
    
    system("java -jar jenkins-cli.jar -s http://automation:8080/ list-jobs All");
    close(OUTPUT);
    
    open(my $fh,'<:encoding(UTF-8)', "total_tests.txt") or die "Could not open file 'tests_total.txt' $!";
    
    while (my $row = <$fh>) {
        
        chomp $row;
          
        if (length($row) > 1) {
            my $test_query = "SELECT name FROM jenkins_list_tbl WHERE name='$row';";
            $sth = Custom::WepaSubs::db_get_st_handle( $dbh, $test_query );
            Custom::WepaSubs::db_execute( $sth );
            my $test_name = $sth->fetchrow_array();
    
            if (not($test_name)){
            Custom::WepaSubs::db_insert_rows( "INSERT INTO jenkins_list_tbl (name) VALUES ('$row');");
            }
        }
        
    }
    
    my $update_query = "DELETE FROM jenkins_list_tbl where name = 'Pass-Fail Status Report';";
    $sth = Custom::WepaSubs::db_get_st_handle( $dbh, $update_query );
    Custom::WepaSubs::db_execute( $sth );
    
    my $all_tests_query = "SELECT count(*) FROM jenkins_list_tbl;";
    $sth = Custom::WepaSubs::db_get_st_handle( $dbh, $all_tests_query );
    Custom::WepaSubs::db_execute( $sth );
    my $current_total = $sth->fetchrow_array();
    
    print "The current total in Jenkins is " . $current_total;
    
    close($fh);
    Custom::WepaSubs::db_cleanup($dbh, $sth);
    
    return 1;
}

sub get_node_info {
    
    my $session_id = shift;
    my $action = shift;
    
    my $url = "http://localhost:4445/grid/api/testsession?session=" . $session_id;

    use LWP::Simple;
    use HTML::Parser;
    
    my $html = get ($url);
    
    chop($html);
    
    my $html_str = substr($html, 1);
        
    my @html_fields = split /,/, $html_str;
    
    given ($action) {
        
        when 'proxy_id' {
            my @proxy_keys = split /:/, $html_fields[5];
            
            if ($proxy_keys[0] =~/"proxyId"/) {
                my $temp = $proxy_keys[2];
                my $proxy_id = substr($temp, 2);
            
                return $proxy_id;
            }
            
            else {
                
                print "The proxy ID could not be located because the HTML page did not load the correct information";
                return 0;
            }
        }
        
        when 'internal_key' {
            
            my @internal_keys = split /:/, $html_fields[3];
            
            if ($internal_keys[0] =~/"internalKey"/) {
                my $temp = $internal_keys[1];
                chop($temp);
                my $internal_key = substr($temp, 1);
            
                return $internal_key;
            }
            
            else {
                
                print "The internal key could not be located because the HTML page did not load the correct information";
                return 0;
            }
            
            
        }
        
        when 'hostname' {
            my @proxy_keys = split ( '//', $html_fields[5] );
            
            if ($proxy_keys[0] =~/"proxyId"/) {
                my $temp = $proxy_keys[1];
                chop($temp);
                my $proxy_id = $temp;
            
                my $dbh = Custom::WepaSubs::db_get_handle();
                my $sth;
                
                my $hostname_query = "SELECT hostname FROM node_information_mapping_tbl WHERE proxy_id = '$proxy_id';";
                $sth = Custom::WepaSubs::db_get_st_handle( $dbh, $hostname_query );
                Custom::WepaSubs::db_execute( $sth );
                my $hostname = $sth->fetchrow_array();
                
                return $hostname;
            }
            
            else {
                
                print "The proxy ID could not be located because the HTML page did not load the correct information";
                return 0;
            }
        }
    }
}
1;
__END__
