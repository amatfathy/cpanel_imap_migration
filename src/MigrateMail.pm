package Cpanel::API::MigrateMail;

use strict;
use warnings;

our $VERSION = '1.0';

use Cpanel::FindBin         ();
use Cpanel::SafeRun::Simple ();
use Cpanel::JSON            ();
use Cpanel::API::Email      (); # For validating email accounts

our $_services_file = '/usr/local/cpanel/etc/services.json';

sub check_destination_quota {
    my ( $args, $result ) = @_;
    my $localuser = $args->get('localEmail');
    
    # Get email account quota information
    my $quota_info = Cpanel::API::Email::get_pop_quota({'email' => $localuser});
    
    if( $quota_info && $quota_info->{data} ) {
        my $quota_limit = $quota_info->{data}->{quota} || 0;
        my $quota_used = $quota_info->{data}->{used} || 0;
        my $quota_available = $quota_limit - $quota_used;
        
        # Convert to human readable
        my $limit_gb = sprintf("%.2f", $quota_limit / 1024);
        my $used_gb = sprintf("%.2f", $quota_used / 1024);
        my $available_gb = sprintf("%.2f", $quota_available / 1024);
        
        return {
            'limit_mb' => $quota_limit,
            'used_mb' => $quota_used,
            'available_mb' => $quota_available,
            'limit_gb' => $limit_gb,
            'used_gb' => $used_gb,
            'available_gb' => $available_gb,
            'has_space' => ($quota_available > 1024) # At least 1GB free
        };
    }
    
    return undef;
}

sub domigrateuser {

    my ( $args, $result ) = @_;

    my ( $remoteuser, $remotepass, $localuser, $localpass, $mailservice, $customserver, $customport ) = 
        $args->get( 'remoteEmail', 'remotePassword', 'localEmail', 'localPassword', 'mailService', 'customServer', 'customPort' );

    # Basic validation
    if( ! $remoteuser || $remoteuser !~ m/\@/ ){
        $result->error( 'Please enter a valid source email address');
        return;
    }
    if( !$remotepass ){
        $result->error( 'Source email password is required' );
        return;
    }
    if( ! $localuser || $localuser !~ m/\@/ ){
        $result->error( 'Please select a destination email account' );
        return;
    }
    if( !$localpass ){
        $result->error( 'Destination email password is required' );
        return;
    }
    if( ! $mailservice ){
        $result->error( 'Please select an email service');
        return;
    }

    # Validate destination email account exists in cPanel
    my $email_accounts = Cpanel::API::Email::list_pops();
    my $account_exists = 0;
    
    if( $email_accounts && $email_accounts->{data} ) {
        foreach my $account ( @{ $email_accounts->{data} } ) {
            if( $account->{email} eq $localuser ) {
                $account_exists = 1;
                last;
            }
        }
    }
    
    if( !$account_exists ) {
        $result->error( "Destination email account '$localuser' does not exist in cPanel. Please create it first." );
        return;
    }

    # NEW: Check destination quota before starting
    my $quota_check = check_destination_quota($args, $result);
    
    if( $quota_check && !$quota_check->{has_space} ) {
        $result->error( "Insufficient space in destination mailbox. Available: $quota_check->{available_gb}GB, Used: $quota_check->{used_gb}GB of $quota_check->{limit_gb}GB total. Please free up space or increase quota before migration." );
        return;
    }

    # Set up server connection details
    my $remoteserver = 'imap.gmail.com';
    my $remoteport = 993;
    my $localserver  = 'localhost';
    my $localport  = '993';

    # Load service configurations
    my $_services;
    eval {
        $_services = Cpanel::JSON::LoadFile( $_services_file );
    };
    if( $@ ) {
        $result->error( 'Email service configuration file not found' );
        return;
    }
    
    my $use_ssl = 1;  # Default to SSL
    
    if( $mailservice eq 'custom_imap_ssl' || $mailservice eq 'custom_imap_plain' ){
        if( !$customserver ){
            $result->error( 'IMAP server address is required for custom configuration' );
            return;
        }
        $remoteserver = $customserver;
        $remoteport = $customport || ($mailservice eq 'custom_imap_ssl' ? 993 : 143);
        $use_ssl = ($mailservice eq 'custom_imap_ssl') ? 1 : 0;
        
        # Basic validation for custom server
        if( $remoteserver !~ m/^[a-zA-Z0-9.-]+$/ ) {
            $result->error( 'Invalid IMAP server address format' );
            return;
        }
    } elsif( exists $_services->{ $mailservice } ){
        $remoteserver = $_services->{ $mailservice }->{'server'};
        $remoteport = $_services->{ $mailservice }->{'port'};
        $use_ssl = $_services->{ $mailservice }->{'ssl'};
    } else {
        $result->error( 'Unknown email service selected' );
        return;
    }

    # Check if imapsync is available
    my $imapsync = Cpanel::FindBin::findbin('imapsync');
    if( !$imapsync ){
        $result->error( 'Email migration tool (imapsync) is not installed on this server. Please contact your hosting provider.' );
        return;
    }

    # Test connection to source server first (dry run)
    my @test_options = ( 
        '--host1', $remoteserver,
        '--user1', $remoteuser,
        '--password1', $remotepass,
        '--port1', $remoteport,
        '--justconnect'
    );
    
    # Add SSL option only if needed
    if( $use_ssl ) {
        push @test_options, '--ssl1';
    }
    
    my $test_result = Cpanel::SafeRun::Simple::saferun( $imapsync, @test_options );
    
    if( $test_result =~ m/authentication failed|login failed|connection refused/im ) {
        $result->error( 'Cannot connect to source email account. Please check your email address and password.' );
        return;
    }

    # Add quota warning for migrations
    my @quota_options = ();
    if( $quota_check && $quota_check->{available_mb} < 5120 ) { # Less than 5GB free
        push @quota_options, '--maxsize', '25000000'; # Limit individual messages to 25MB
        push @quota_options, '--skipmess', 'LARGER than 25000000'; # Skip very large messages
    }

    # Build full migration command with quota considerations
    my @defaultoptions = ( 
        '--automap', 
        '--syncinternaldates', 
        '--ssl2',  # Always use SSL for local cPanel connection
        '--noauthmd5',
        '--exclude', 'All Mail|Spam|Trash|Deleted Items|Junk|Draft',
        '--allowsizemismatch',
        '--logdir', '/tmp',
        '--logfile', "imapsync_" . time() . '_' . $$ . '.txt',
        '--timeout1', '120',
        '--timeout2', '120',
        '--nofoldersizes',  # Skip folder size calculation for speed
        @quota_options      # Add quota-aware options
    );
    
    # Add SSL for source only if configured
    if( $use_ssl ) {
        push @defaultoptions, '--ssl1';
    }

    my @mailoptions = ( 
        '--host1', $remoteserver, 
        '--user1', $remoteuser, 
        '--password1', $remotepass, 
        '--host2', $localserver, 
        '--user2', $localuser, 
        '--password2', $localpass, 
        '--port1', $remoteport, 
        '--port2', $localport 
    );

    # Execute actual migration
    my $migration_result = Cpanel::SafeRun::Simple::saferun( $imapsync, @mailoptions, @defaultoptions );
    
    # Parse results more carefully
    if( $migration_result =~ m/authentication failed.*host2|login failed.*host2/im ) {
        $result->error( 'Cannot connect to destination email account. Please check the password for your cPanel email account.' );
        return;
    }
    
    if( $migration_result =~ m/authentication failed.*host1|login failed.*host1/im ) {
        $result->error( 'Cannot connect to source email account. Please check your email address and password.' );
        return;
    }
    
    if( $migration_result !~ m/detected 0 errors|EX_OK|SUCCESS/im ) {
        $result->error( 'Email migration encountered errors. Please try again or contact support.' );
        return;
    }
    
    # Extract some stats if possible
    my $transferred = 0;
    if( $migration_result =~ m/(\d+) messages transferred/im ) {
        $transferred = $1;
    }
    
    # After successful migration, report final usage
    if( $quota_check ) {
        my $final_quota = check_destination_quota($args, $result);
        if( $final_quota ) {
            $result->data({
                'status' => 'success',
                'messages_transferred' => $transferred,
                'source_account' => $remoteuser,
                'destination_account' => $localuser,
                'quota_before' => "$quota_check->{used_gb}GB",
                'quota_after' => "$final_quota->{used_gb}GB",
                'quota_limit' => "$final_quota->{limit_gb}GB"
            });
        } else {
            $result->data({
                'status' => 'success',
                'messages_transferred' => $transferred,
                'source_account' => $remoteuser,
                'destination_account' => $localuser
            });
        }
    } else {
        $result->data({
            'status' => 'success',
            'messages_transferred' => $transferred,
            'source_account' => $remoteuser,
            'destination_account' => $localuser
        });
    }
    
    return 1;
}

sub services {
    my ( $args, $result ) = @_;

    my $_services;
    eval {
        $_services = Cpanel::JSON::LoadFile( $_services_file );
    };
    
    if( $@ ) {
        $result->error( 'Email service configuration not available' );
        return;
    }

    my @services = sort keys %{ $_services };

    $result->data( \@services );
    return 1;
}

1;