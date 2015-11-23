package Custom::DbInterface;

use strict;
use warnings;
use Custom::WepaSubs;

sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;
    return $self;
}
sub proc_query {
	my $self = shift;
	
	my $dbh = Custom::WepaSubs::db_get_handle();
	my $dataset = $dbh->selectall_arrayref($self->{query});
	
	return $dataset;
}
sub get_hash_hashes {
    my $self = shift;
    #my $query = shift;
    #my $column_key = shift;

    my $dbh = Custom::WepaSubs::db_get_handle();
    my $hash_of_hashes = $dbh->selectall_hashref($self->{query}, $self->{column_key});

    return $hash_of_hashes;
}
sub db_insert_rows {
    my $self = shift;
    
    return my $result = Custom::WepaSubs::db_insert_rows($self->{query});
    
}
sub get_data_ref {
    my $self = shift;
    my $sql = shift || undef;
    
    say $sql;

    my $dbh = Custom::WepaSubs::db_get_handle();
    my $sth = Custom::WepaSubs::db_get_st_handle($dbh, $sql);

    my $array_ref = $sth->fetchall_arrayref({});
    
    return $array_ref;
}
# TEST SPECIFIC METHODS
sub get_test_run_data {
    my $self = shift;
    
    my $timestamp = shift || undef;
    my $sql = shift || "SELECT test_plan_name, test_name, status
                        FROM test_run_tbl
                        WHERE test_timestamp = '$timestamp';";

    say $sql;
    my %TEST_RUN_RESULTS = ();

    my $dbh = Custom::WepaSubs::db_get_handle();

    my @row_parms = $dbh->selectrow_array($sql);
    
    # Build a data structure from the records
    $TEST_RUN_RESULTS{$self->{test_timestamp}} = {      # $test_timestamp -> QC Run ID

            test_plan_name   => $row_parms[0],
            test_name   => $row_parms[1],
            status => $row_parms[2],            # QC Run Status
            step_results => [],                 # QC StepFactory details
    };
    
    my $sql2;
    if ($self->{browser}) {
        $sql2 = "SELECT test_id, test_result, test_case_name, test_case_details, browser, platform, image_link
                 FROM test_results_tbl
                 WHERE test_timestamp = '$self->{test_timestamp}'
                 AND browser = '$self->{browser}';";
    }
    else {
        $sql2 = "SELECT test_id, test_result, test_case_name, test_case_details, image_link
                 FROM qt_test_results_tbl
                 WHERE test_timestamp = '$self->{test_timestamp}'
                 AND (image_link LIKE '%_qc_%' OR is_qc_step = true);";
    }
    my $sth = Custom::WepaSubs::db_get_st_handle($dbh, $sql2);
    
    $sth->execute();

    my $i = 0;
    while (my($test_id, $test_result, $test_case_name, $test_case_details, $image_link) = $sth->fetchrow_array() ) {
        
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{test_id} = $test_id;                     # QC StepFactory Step ID
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{test_result} = $test_result;             # QC StepFactory Step Status
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{test_case_name} = $test_case_name;
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{test_case_details} = $test_case_details; # QC StepFactory Actual Result
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{browser} = $self->{browser} if $self->{browser}; # Only if browser used
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{platform} = $self->{platform} if $self->{platform}; # Only if platform used
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{image_link} = $image_link;               # QC AttachmentFactory ST_ATTACHMENT
        $TEST_RUN_RESULTS{$self->{test_timestamp}}{step_results}->[$i]{test_timestamp} = $self->{test_timestamp};       # QC Run ID
        $i++;
    }
    return %TEST_RUN_RESULTS;
}
1;
