package Custom::WebApp;
use Custom::WepaSubs;

use strict;
use warnings;
use Selenium::Remote::Driver;
use Selenium::Remote::WDKeys;
use MIME::Base64;
use Try::Tiny;
use feature qw( say );
use Switch qw ( Perl6 );
use HTML::TreeBuilder;
use LWP::UserAgent;
use Encode;
use Time::HiRes qw( sleep );


use constant {
	DEF_HUB_IP   	=> 'localhost',
	X86_HUB_IP   	=> 'localhost',
	X64_HUB_IP   	=> 'localhost',
	MAC_HUB_IP   	=> 'localhost',
	DEF_HUB_PORT 	=> '4444',
	X86_HUB_PORT 	=> '4446',
	X64_HUB_PORT 	=> '4445',
	MAC_HUB_PORT 	=> '4447',
	APPHOME      	=> 'http://blog.teamvgp.com/',    # This is the applications root directory
	MAX_WAIT_TIME	=> 10000 # Default time the driver will wait for elements
};    

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;

	return $self;

}

# Framework Setup and Configuration
sub set_capabilities {

	my $self     = shift;
	my $browser  = shift;
	my $platform = shift;

	my ( $grid_server, $os_platform, $port, $app_name, %desired_capabilities );

	given $platform {
		when 'WIN8x64' {
			$grid_server = X64_HUB_IP;
			$port	     = X64_HUB_PORT;
			$os_platform = 'WIN8';
		}
		when 'WIN8_1x64' {
			$grid_server = X64_HUB_IP;
			$port	     = X64_HUB_PORT;
			$os_platform = 'WIN8_1';
		}
		when 'WIN8x86' {
			$grid_server = X86_HUB_IP;
			$port	     = X86_HUB_PORT;
			$os_platform = 'WIN8';
		}
		when 'WIN7x64' {
			$grid_server = X64_HUB_IP;
			$port        = X64_HUB_PORT;
			$os_platform = 'VISTA';
		}
		when 'WIN7x86' {
			$grid_server = X86_HUB_IP;
			$port        = X86_HUB_PORT;
			$os_platform = 'VISTA';
		}
		when 'XPx86' {
			$grid_server = X86_HUB_IP;
			$port        = X86_HUB_PORT;
			$os_platform = 'XP';
		}
		when 'MACx86' {
			$grid_server = MAC_HUB_IP;
			$port        = MAC_HUB_PORT;
			$os_platform = 'MAC';
		}
		when 'MACx64' {
			$grid_server = MAC_HUB_IP;
			$port        = MAC_HUB_PORT;
			$os_platform = 'MAC';
		}
		when 'VISTAx86' {
			$grid_server = X86_HUB_IP;
			$port        = X86_HUB_PORT;
			$os_platform = 'VISTA';
		}
		when 'VISTAx64' {
			$grid_server = X64_HUB_IP;
			$port        = X64_HUB_PORT;
			$os_platform = 'VISTA';
		}
		default {
			$grid_server = DEF_HUB_IP;
			$port        = DEF_HUB_PORT;
			$os_platform = 'WINDOWS';
		}
	}
	given $browser {
		when 'IE8'  { $browser = 'internet explorer'; $app_name = 'IE8'; }
		when 'IE9'  { $browser = 'internet explorer'; $app_name = 'IE9'; }
		when 'IE10' { $browser = 'internet explorer'; $app_name = 'IE10'; }
		when 'IE11' { $browser = 'internet explorer'; $app_name = 'IE11'; }
		when 'FFX'  { $browser = 'firefox';           $app_name = 'FFX'; }
		when 'CHR'  { $browser = 'chrome';            $app_name = 'CHR'; }
		when 'SFR'  { $browser = 'safari';            $app_name = 'SFR'; }
		when 'OPR'  { $browser = 'opera'; 	      	  $app_name = 'OPR'; }
		default     { $browser = 'firefox';           $app_name = 'FFX'; }
	}
	unless ( $browser eq 'chrome' ) {
		
		%desired_capabilities = (
						remote_server_addr => $grid_server,
						browser_name       => $browser,
						platform           => $os_platform,
						port               => $port,
						application_name   => $platform . $app_name
		);
	}
	else {
		%desired_capabilities = (
						remote_server_addr => $grid_server,
						browser_name       => $browser,
						platform           => $os_platform,
						port               => $port,
						application_name   => $platform . $app_name,
						proxy => { proxyType => 'system' }
		);
	}
	return %desired_capabilities;

}

sub setup_selenium {

	my $self         = shift;
	my $browser      = shift;
	my $capabilities = shift;
	my $driver;
	my %desired_capabilities;

	if ($capabilities) {
		%desired_capabilities = %$capabilities;
	}

	# Start selenium with capabilities if passed in from test script
	unless ( keys %desired_capabilities == 0 ) {
		
		$driver = eval {
			Selenium::Remote::Driver->new(%desired_capabilities);
		};
		return $@ if $@;    # Return with error if capability not matched
	}

	# Or just start it with default settings
	else {
		$driver = eval {
			Selenium::Remote::Driver->new( browser_name => $browser,
										   proxy => { proxyType => 'system' } );
		};
		return $@ if $@;    # Return with error if capability not matched
	}
	return $driver;

}

sub check_driver {

	my $self   = shift;
	my $driver = shift;

	return undef
	  if ( ( $driver =~ /Could not create new session/ )
		|| ( $driver =~ /Could not establish a session with the remote server/ )
		|| ( $driver =~ /Could not connect to SeleniumWebDriver/ )
		|| ( $driver =~ /malformed JSON string/ )
		|| ( $driver =~ /Selenium server did not return proper status/) );

	return $driver;

}
# Wait time is in ms
sub set_default_wait_time {

	my $self      = shift;
	my $wait_time = shift;

	$self->{driver}->set_implicit_wait_timeout($wait_time);

	return;
}

# Web page interaction methods
sub go_back {
	
	my $self = shift;
	
	$self->{driver}->go_back();
	
	return;

}
sub where_am_i {

	my $self = shift;

	my $url = $self->{driver}->get_current_url();

	return $url;

}

sub goto_page {

	my $self = shift;
	my $page = shift;

	$self->{driver}->get($page);

	return 1;

}

sub goto_page_and_tell {

	my $self = shift;
	my $page = shift;

	$self->{driver}->get($page);

	my $landing_page = where_am_i($self);

	return $landing_page;
	
}
sub reload_page {

	my $self = shift;

	$self->{driver}->refresh();

	return;

}

sub click_and_tell {

	my $self         = shift;
	my $element_type = shift;
	my $name         = shift;

	my $query = "SELECT element_name, locator
                 FROM html_element_tbl
                 WHERE element_type = '$element_type'
                 AND name = '$name'
                 AND is_active = true;";

	my @elem = $self->{dbh}->selectrow_array($query);

	my ( $target, $locator ) = ( $elem[0], $elem[1] );

	$self->{driver}->find_element( $target, $locator )->click()
	  and Custom::WepaSubs::wait_for(1.5);
	my $landing_page = where_am_i($self);
	return $landing_page;

}

sub select_frame {

	my $self         = shift;
	my $element_type = shift;
	my $name         = shift;

	if ($element_type) {

		my $query = "SELECT element_name, locator
                     FROM html_element_tbl
                     WHERE element_type = '$element_type'
                     AND name = '$name'
                     AND is_active = true;";

		# Get Statement handler
		my $sth = Custom::WepaSubs::db_get_st_handle( $self->{dbh}, $query );

		# Execute the statement
		Custom::WepaSubs::db_execute($sth);

		while ( my ( $target, $locator ) = $sth->fetchrow_array() ) {

			$self->{driver}->switch_to_frame($target);
		}
	}
	else {
		$self->{driver}->switch_to_frame(undef);
	}
	return;

}
# Maximize the current browser window
sub maximize_window {

	my $self 	= shift;
	my $window 	= shift || undef;

	$self->{driver}->maximize_window();

	return;
}

# Utility methods
sub scrape_html {

	my $self = shift;
	my $url  = shift;

	my $response =
	  LWP::UserAgent->new->request( HTTP::Request->new( GET => $url ) );

	unless ( $response->is_success ) {
		warn "Couldn't get $url: ", $response->status_line, "\n";
		return;
	}

	# This is needed so that perl wont warn about Parsing undecoded UTF-8
	return decode_utf8( $response->content );

}

sub verify_html_elements {

	my $self        = shift;
	my $target      = shift;
	my $locator     = shift;
	my $page_source = shift;

	# Create a tree object
	my $tree = HTML::TreeBuilder->new;

	$tree->parse_content($page_source);

	my $elem = $tree->look_down( $locator, $target );

	return $elem;

}

sub get_screenshot {

	my $self             	= shift;
	my $cap_type         	= shift;
	my $file_name_prefix 	= shift;
	my $wait_time		= shift || 0;
	my $random_number    	= int( rand(99999) );
	my $file_path;

	given ($cap_type) {
		when "NORMAL" {
			$file_path = "C:\\Automation\\Results\\Screenshots\\Normal\\";
		}
		when "ERROR" {
			$file_path = "C:\\Automation\\Results\\Screenshots\\Error\\";
		}
		when "SYSTEM" {
			$file_path = "C:\\Automation\\Results\\Screenshots\\System\\";
		}  # TODO directory structure and logic for system generated screenshots
		default { print "Capture type was not defined"; };
	}

	open FH, '>',
	    $file_path
	  . $file_name_prefix
	  . $self->{test_plan_name} . '_'
	  . $random_number . '_'
	  . $self->{platform}
	  . $self->{browser} . '_'
	  . $self->{test_timestamp}
	  . '_screenshot.png';

	Custom::WepaSubs::wait_for( $wait_time ); # Wait for specified amount if applicable
	
	binmode FH;
	my $png_base64 = $self->{driver}->screenshot();
	print FH MIME::Base64::decode_base64($png_base64);
	close FH;

	if ( $cap_type eq "NORMAL" ) {
		push @{ $self->{cap_list_ref} },
		    $file_path
		  . $file_name_prefix
		  . $self->{test_plan_name} . '_'
		  . $random_number . '_'
		  . $self->{platform}
		  . $self->{browser} . '_'
		  . $self->{test_timestamp}
		  . '_screenshot.png';
	}
	elsif ( $cap_type eq "ERROR" ) {
		push @{ $self->{error_cap_ref} },
		    $file_path
		  . $file_name_prefix
		  . $self->{test_plan_name} . '_'
		  . $random_number . '_'
		  . $self->{platform}
		  . $self->{browser} . '_'
		  . $self->{test_timestamp}
		  . '_screenshot.png';
	}
	elsif ( $cap_type eq "SYSTEM" ) {
		push @{ $self->{cap_list_ref} },
		    $file_path
		  . $file_name_prefix
		  . $self->{test_plan_name} . '_'
		  . $random_number . '_'
		  . $self->{platform}
		  . $self->{browser} . '_'
		  . $self->{test_timestamp}
		  . '_screenshot.png';
	}
	my $cap_file =
	    $file_path
	  . $file_name_prefix
	  . $self->{test_plan_name} . '_'
	  . $random_number . '_'
	  . $self->{platform}
	  . $self->{browser} . '_'
	  . $self->{test_timestamp}
	  . '_screenshot.png';

	Custom::WepaSubs::write_log( 4, "$cap_file\n", $self->{log_file} );

	return 1;
}

# Web application interaction methods
sub do_action {

	my $self         		= shift;
	my $action       		= shift;
	my $element_type 		= shift;
	my $name         		= shift;
	my $app_id       		= shift;
	my $screen_id    		= shift || undef;
	my $text         		= shift || undef; # used in send_text
	my $target2      		= shift || undef; # used in select_from_dropdown
	my $dont_clear_field	= shift || undef; # used to indicate that we do not want to clear field prior to entering text

	my $page_id     		= $self->{test_site};
	my $status				= 0;
	my $time_before_click 	= 0; # How long to additionally wait before performing "actions". Defaults to 0.
	
	my ( $query, $select_target );
	
	# NOTE: all queries to a database would better be implemented using stored procedures.
	if ( defined $screen_id ) {

		$query = "SELECT element_name, locator
                FROM html_element_tbl
                WHERE element_type = '$element_type'
                AND name = '$name'
                AND app_id = '$app_id'
                AND screen_id = '$screen_id'
                AND is_active = true;";
	}
	else {
		$query = "SELECT element_name, locator
                FROM html_element_tbl
                WHERE element_type = '$element_type'
                AND name = '$name'
                AND app_id = '$app_id'
                AND is_active = true;";
	}

	# Get Statement handler
	my $sth = Custom::WepaSubs::db_get_st_handle( $self->{dbh}, $query );

	# Execute the statement
	Custom::WepaSubs::db_execute($sth);

	if ( defined $target2 ) {    # used in select from dropdown list

		($select_target) = $self->{dbh}->selectrow_array( "SELECT element_name FROM html_element_tbl WHERE name = '$target2'" );
	}
	
	while ( my ( $target, $locator ) = $sth->fetchrow_array() ) {
		# Try three times to find the element
		my $attempts = 0;
		my $elem;
		while ( $attempts <= 2 ) {
			# Elem will be either an object or 0
			$elem =
					try {
						$self->{driver}->find_element( $target, $locator );
					}
					catch {
							say 'Element Not Found: ' . $target . ',' . $locator;
							return 0;
					};
					
			Custom::WepaSubs::wait_for(2);
			last if $elem != 0;
			$attempts++;
		}
		# Log element info if not found
		if ( $elem == 0 ) {
				say "$locator, $target was not found on $self->{test_site}";
				my $sql = "SELECT element_type, name FROM html_element_tbl WHERE element_name = '$target';";
				my @rows = Custom::WepaSubs::db_get_rows($sql);
				my $query = "INSERT INTO html_update_tbl (page_name, method, selector, element_type, name, last_update, completed) VALUES ('$page_id', '$locator', '$target', '$rows[0]', '$rows[1]', now(), false)";
				Custom::WepaSubs::db_insert_rows($query);
				return 0;
		}
		
		#  Just click if any of the below conditions are true
		#  NOTE - Added this if until I figure out what is up with link_text et al
		if (    ( $action eq 'click_on' ) && ( ( $locator eq 'link_text' ) || $locator eq 'css' ) )	{
			unless ( $elem == 0 ) { # we don't have an element so why click
				$elem->click();
				return $status = 1;    # action was a success
			}
		}
		
		
		unless ( ( $locator eq 'link_text' ) && ( $action eq 'click_on' ) || ( $elem == 0 ) ) {

				Custom::WepaSubs::wait_for($time_before_click);
				
				given ($action) {
					
					
					when 'find_element' {
						
						return $elem;
					}
					
					when 'click_on' {

						# Only click if the element is actually displayed. Could be on the page but hidden attribute is on.
						my $displayed = $elem->is_displayed();

						if ( $displayed == 1 ) {
							$elem->click();
							return $status = 1;    # Action assumed to be successful
						}
						else {
							return $status = 0; # Element was not visible to the human eye so fail
						}

					}
					when 'get_text_present' {

						my ( @text, $text );
						eval {
							$text = $elem->get_text();
						};
						push @text, $text;
						return @text;

					}
					when 'get_text' {

						my $text = $elem->get_text();

						return $text;

					}
					when 'is_element_enabled' {

						return my $bool =
						  $elem->is_enabled();

					}
					when 'is_element_selected' {

						return my $bool =
						  $elem->is_selected();

					}
					when 'get_element_attribute' {

						return my $attrib =
						  $elem->get_attribute($text);

					}
					when 'is_element_visible' {

						return my $bool =
							$elem->is_displayed();

					}
					when 'select_from_dropdown' {

						my $child =
						  $self->{driver}->find_child_element( $elem, $select_target );
						$child->click() and return;

					}
					when 'select_from_dropdown2' {

						my $drop_down = $elem;
						my @all_options = $self->{driver}->find_child_elements( $drop_down, 'option', 'tag_name' );
						foreach my $option ( @all_options ) {
							my $option_text = lc ( $option->get_text() );
							if ( $option_text =~ lc $text || $option_text eq lc $text ) {
								$option->click();
								return 1;
							}
						}
					}
					when 'click_by_tag_name' {

						my @values =
						  $self->{driver}->find_elements( $target, $locator );

						foreach my $e ( @values ) {
							print "rvalue:$e \n";
							my $text1 = $e->get_text();
							print "text1:$text1 \n";
							if ( $text1 eq $text ) {
								$e->click();
								print "selected \n";
								last;
							}
						}
					}
					when 'send_text' {
						
						if ( $dont_clear_field ) {
							
							Custom::WepaSubs::wait_for(1.5);
							$elem->send_keys( $text );
						}
						else {
							$elem->clear();
							$elem->send_keys( $text );

						}
						return $status = 1;    # Action assumed successful

					}
					when 'type_text' {

						if ( $dont_clear_field ) {
							
							Custom::WepaSubs::wait_for(1.5);
							$elem->send_keys( $text );
						}
						else {
							$elem->clear();
							$elem->send_keys( $text );

						}
						return $status = 1;    # Action assumed successful

					}
					when 'send_text_to_active_element' {
						
						$elem->click();
						$elem->clear();

						$self->{driver}->send_keys_to_active_element( $text ) and return $status = 1;

					}
					when 'get_element_value' {

						return my $value =
							$elem->get_value();

					}
					when 'clear_field' {

						$elem->clear();
						return $status = 1;    # Action assumed successful

					}
					when 'click_and_tell' {

						$elem->click();
						return my $landing_page = where_am_i($self);

					}
					when 'move_mouse' {

						$self->{driver}->move_to( element => $elem )
						  and return $status = 1
						  or return $status = 0;

					}
					when 'move_mouse_and_click' {
						
						$self->{driver}->move_to( element => $elem );
						$elem->click() and return $status = 1 or return $status = 0;
						
					}
					when 'move_mouse_with_coordinates' {

						my ( $x, $y ) = ( $_[9], $_[10] );
						$self->{driver}->move_to( element => $elem,
									  xoffset => $x,
									  yoffset => $y )
						  and return $status = 1
						  or return $status = 0;
					}
					when 'get_table_data' {

						my @table_data =
						  $self->{driver}->find_elements( $target, $locator );

						my $max_rows = $#table_data + 1;
						my @stored_text;

						for ( my $i = 0 ; $i <= $max_rows ; $i++ ) {
							my $text =
							  $self->{driver}->find_element( 'element_target' . $i . 'T1', 'id' )->get_text();
							push @stored_text, $text;
						}
						return \@stored_text;
					}
				}
		}
	}
	return;
}
# Enter text in a slick grid
sub enter_data_in_grid_cell {
	
	my $self 	= shift;
	#my $grid_id 	= shift;
	#my $cell_id	= shift;
	my $attribute	= shift;
	my $value	= shift;
	my $data	= shift;
	
	my $page_source = $self->{driver}->get_page_source();
	
	my $invoice_amount_elem = find_html_element($self, $attribute, $value, $page_source);
	
	#my $grid = $self->{driver}->find_element( $grid_id, 'id' );
	#my $child_elem = $self->{driver}->find_child_element( $grid, './div[\@class[contains($cell_id)]', 'xpath' );
	
	my $invoice_amount_field_elem = $self->{driver}->find_element( $invoice_amount_elem, $attribute );
	
	$invoice_amount_field_elem->click();
	
	$invoice_amount_field_elem->send_keys( $data );
	
	return;
}
sub find_html_element {
	
	my $self = shift;
	my $attribute = shift;
	my $value = shift;
	my $page_source = shift;
	
	# Create a tree object
	my $tree = HTML::TreeBuilder->new;
	
	$tree->parse_content($page_source);

	my $elem = $tree->look_down( $attribute, qr/$value/ );
	
	my $target = $elem->{class};
	
	return $target;
}
# Helper methods
sub _transfer_file {

	my $self      = shift;
	my $file_name = shift;
	my $target    = shift;
	my $locator   = shift;

	my $remote_fname;

	unless ( $self->{platform} =~ /MAC/ ) {
		$remote_fname = $self->{driver}->upload_file($file_name);
	}
	else {
		$file_name =~ s/\\/\//g; # replace \ with / on MAC
		$remote_fname = $self->{driver}->upload_file($file_name);
	}
	
	my $file_location_element = $self->{driver}->find_element( $target, $locator );
	#my $fullfilepath = $remote_fname . '\\' . substr $file_name, 5;
	
	unless ( $self->{platform} =~ /MAC/ ) {
		$file_location_element->send_keys( $remote_fname . '\\' . substr $file_name, 5 ); # use back slash on Windows
	}
	else {
		$file_location_element->send_keys( $remote_fname . '//' . substr $file_name, 5 ); # use forward slash on MAC
	}

	Custom::WepaSubs::wait_for(5);

	return;

}
# Sends a single keycode to the active window
# NOTE: The window being interacted with natively must have the focus (i.e. be the active window)
sub _send_native_key_to_active_window {
	
	my $self	= shift;
	my $win_id	= shift;
	my $win_title	= shift;
	my $win_class	= shift;
	my $keycode 	= shift;

	use Win32::GuiTest qw( FindWindowLike GetWindowText SetForegroundWindow SendKeys );
    
	$Win32::GuiTest::debug = 0; # Set to "1" to enable verbose mode
	# First find the window of interest.
	my @windows = FindWindowLike( $win_id, "^" . $win_title, "^" . $win_class . "\$" );

	# Then we iterate through that list and send the "keys" to any matching window.
	for (@windows) {
		print "$_>\t'", GetWindowText( $_ ), "'\n";
		SetForegroundWindow( $_ );
		SendKeys( "{$keycode}" );
		Custom::WepaSubs::wait_for(1.5);
	}
	return;
}
# Sends a series of keycodes to the active window
# NOTE: The window being interacted with natively must have the focus (i.e. be the active window)
sub _send_native_keys_to_active_window {
	
	my $self	= shift;
	my $win_id	= shift;
	my $win_title	= shift;
	my $win_class	= shift;
	my @keycodes 	= shift;

	#use Win32::GuiTest qw( FindWindowLike GetWindowText SetForegroundWindow SendKeys );
      
	$Win32::GuiTest::debug = 0; # Set to "1" to enable verbose mode
	# First find the window of interest.
	my @windows = FindWindowLike( $win_id, "^" . $win_title, "^" . $win_class . "\$" );

	# Then we iterate through that list and send the "keys" to any matching window.
	for (@windows) {
		print "$_>\t'", GetWindowText( $_ ), "'\n";
		SetForegroundWindow( $_ );
		foreach my $keycode ( @keycodes ) {
			SendKeys( "{$keycode}" );
			Custom::WepaSubs::wait_for(1.5);
		}
	}
	return;
}
# Sends a series of keycodes to the remote active window
# NOTE: The window being interacted with natively must have the focus (i.e. be the active window)
sub _send_native_keys_to_remote_active_window {
	
	my $self	= shift;
	my $win_id	= shift;
	my $win_title	= shift;
	my $win_class	= shift;
	my @keycodes 	= shift;

	use Win32::GuiTest qw( FindWindowLike GetWindowText SetForegroundWindow SendKeys );
      
	$Win32::GuiTest::debug = 0; # Set to "1" to enable verbose mode
	# First find the window of interest.
	my @windows = FindWindowLike( $win_id, "^" . $win_title, "^" . $win_class . "\$" );

	# Then we iterate through that list and send the "keys" to any matching window.
	for (@windows) {
		print "$_>\t'", GetWindowText( $_ ), "'\n";
		SetForegroundWindow( $_ );
		foreach my $keycode ( @keycodes ) {
			SendKeys( "{$keycode}" );
			Custom::WepaSubs::wait_for(1.5);
		}
	}
	return;
}
# Click and drag the mouse on an element
# INPUTS: 6 Required
sub _click_and_drag {

	my $self 	= shift;
	my $target 	= shift; # Selenium target
	my $locator 	= shift; # Selenium locator
	my $x1		= shift; # Button down X location
	my $y1		= shift; # Button down Y location
	my $x2		= shift; # Button up X location
	my $y2		= shift; # Button up Y location

	my $element = $self->{driver}->find_element( $target, $locator );

	$self->{driver}->move_to( element => $element, xoffset => $x1, yoffset => $y1 ) and $self->{driver}->button_down();
	#$self->{driver}->button_up();
	$self->{driver}->move_to( element => $element, xoffset => $x2, yoffset => $y2 ) and $self->{driver}->button_up();
	#$self->{driver}->click();

	return;

}
# Check if a file exists in the file system
sub _is_file_present {

    my $file_to_check = shift;
    write_log("FileName to check: $file_to_check");
    if (-e ($file_to_check)) {
        print -e $file_to_check;
        write_log("FileName Present");
        return 1;
    }
    else {
        write_log("FileName not Present");
        return 0;
    }
}
# Create a directory in the local file system (Windows Only)
sub _create_directory {

    #my $dir_name = "%USERPROFILE%\\Desktop\\" . shift;
    my $dir_name = "$ENV{USERPROFILE}\\Desktop\\" . shift;
    my $result;

    unless (-e $dir_name) {
        $result = mkdir $dir_name;
    }
    else {
        write_log("$dir_name already existed in the file system");
        $result = "directory already created";
    }
    return $result;
}
# Delete a directory in the file system (Windows Only)
sub _delete_directory {

    #my $dir_name = "%USERPROFILE%\\Desktop\\" . shift;
    my $dir_name = "$ENV{USERPROFILE}\\Desktop\\" . shift;
    my $result;

    write_log("directory to delete: $dir_name");
    if (-e $dir_name) {
	use File::Path;
        my $files_deleted = File::Path::rmtree($dir_name);
        write_log("result from within if: $files_deleted");
        $result = 1;
    }
    else {
        write_log("$dir_name did not exist in the file system, no need to delete");
        $result = 1;
        write_log("result from within else: $result");
    }
    write_log("delete_dir result: $result");
    return $result;
}
# System level keywords
# Used to log no run tests (for incomplete features)
sub norun {

    my $self = shift;
    
    if (Custom::WepaSubs::write_log(4, shift . "\n", $self->{driver}->{logfile})) {
        return 1;
    }
    else {
        return 0,
    }
}
# Use to end a test if certain condition(s) is/are not met
sub end_test {

	my $self 	= shift;
	my $parms 	= shift;

	
}
sub check_for_error {
	
	my $self 	= shift;
	my $result 	= 0;
	
	my $text = do_action( $self, 'get_text', 'text', 'login_validation', $self->{app_id}, 'login' );
	if ($text =~ /password you entered is incorrect/) {
		$result = 1; # there was an error
	}

	$result == 0 ? return 1 : return 0;
}
# Test site specific and custom methods (Page Objects)
#
# Log into the system
# INPUTS: 2 'login name', 'password' OR none
sub login_as {
	

	my $self       	= shift;
	my $login_type 	= shift || 'normal';
	my $count		= 0;
	

	my $res1 = do_action( $self, 'send_text', 'input', 'Username', $self->{app_id}, 'login', $self->{login_name} );
	if ( $res1 == 1 ) {
		$count++;
	}
	else {
		get_screenshot( $self, 'SYSTEM', 'Login_As_' . $self->{login_name} . '_Failure_' );
	}
	
	my $res2 = do_action( $self, 'send_text', 'input', 'Password', $self->{app_id}, 'login', $self->{new_password} );
	if ( $res2 == 1 ) {
		$count++;
	}
	else {
		get_screenshot( $self, 'SYSTEM', 'Login_As_' . $self->{login_name} . '_Failure_' );
	}
	
	my $res3 = 0;
	if ($login_type eq 'admin' ) {
		$res3 = do_action( $self, 'click_on', 'button', 'Admin_Login', $self->{app_id}, 'login' );
	}
	
	else {
		$res3 = do_action( $self, 'click_on', 'button', 'Login', $self->{app_id}, 'login' );
	}
	
	
	if ( $res3 == 1 ) {
		$count++;
	}
	else {
		get_screenshot( $self, 'SYSTEM', 'Login_As_' . $self->{login_name} . '_Failure_' );
	}

	$count == 3 ? return 1 : return 0;

}
# Log off the system
# INPUTS: NONE
sub log_off {

	my $self = shift;
	
	my $result = 0;


	$result == 0 ? return 1 : return 0;
}
1;

__END__

