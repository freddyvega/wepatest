package Custom::WebApp::WepaDriver;
use parent 'Custom::WebApp';

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;

    return $self;
}
sub drive {

    my $self = shift;
    
    if ( lc ( $self->{mode}) eq 'csv' ) {
        # Use a CSV file with keywords / args
        if ( $self->{keyword_file} ) {
            Custom::WepaSubs::write_log(4, "Drive: '$self->{keyword_file}'",  $self->{logfile});
            
            open KEYWORDFILE, $self->{keyword_file} or die "couldn't open file: $!";
            
            while ( <KEYWORDFILE> ) {
                
                chomp;
                my @records = split ( /\n/ , $_ );
                
                foreach my $record ( @records ) {
                    my ( $keyword, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6 ) = split ( /,/ , $_ );
                    
                    my $command = "$keyword(";

                    my $comma = "";
                    foreach ( $arg1, $arg2, $arg3, $arg4, $arg5, $arg6 ) {
                        my $arg = $_;
                        if ( $arg ne "" ) {
                            $command .= "$comma\"$arg\"";
                            $comma = ", ";
                        }
                        else {
                            last;
                        }
                    }
                    $command .= ");";
                    
                    my $result = eval $command;
                    if ($result == 1) {
                        Custom::WepaSubs::write_log(4, "$command succeeded",  $self->{logfile});
                    }
                    elsif ($result == 0) {
                        Custom::WepaSubs::write_log(4, "$command failed",  $self->{logfile});
                    }
                }
            }
            close KEYWORDFILE;
        }
        # Or use a DB table with keywords / args
        else {
            my $sql = "SELECT keyword, arg1, arg2, arg3, arg4, arg4, arg6 FROM keyword_test_tbl WHERE app_id = '" . $self->{app_name} . "' AND completed = false;";
            my $dbh = db_get_handle();
            my $sth = db_get_st_handle($dbh, $sql);
            db_execute($sth);
        
            while (my($keyword, $arg1, $arg2, $arg3, $arg4, $arg5, $arg6) = $sth->fetchrow_array() ) {
                my $command = "$keyword($arg1, $arg2, $arg3, $arg4, $arg5, $arg6)";
                
                my $result = eval $command;
                if ($result == 1) {
                    Custom::WepaSubs::write_log(4, "$command succeeded",  $self->{logfile});
                }
                elsif ($result == 0) {
                    Custom::WepaSubs::write_log(4, "$command failed",  $self->{logfile});
                }
            }
        }
    }
}
1;
__END__