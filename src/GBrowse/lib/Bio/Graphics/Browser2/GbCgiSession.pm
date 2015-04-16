package Bio::Graphics::Browser2::GbCgiSession;

use base CGI::Session;
use Bio::Graphics::Browser2::OracleSessionDriver;

use strict;
use warnings;

# Copied these "constant" subroutines from CGI::Session
sub STATUS_UNSET    () { 1 << 0 } # denotes session that's resetted
sub STATUS_NEW      () { 1 << 1 } # denotes session that's just created
sub STATUS_MODIFIED () { 1 << 2 } # denotes session that needs synchronization
sub STATUS_DELETED  () { 1 << 3 } # denotes session that needs deletion
sub STATUS_EXPIRED  () { 1 << 4 } # denotes session that was expired.

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    # get args the same way the load function does and save them for later
    my ($dsn, $query_or_sid, $dsn_args, $read_only) = @_;
    $self->{'gcs_dsn'} = $dsn;
    $self->{'gcs_sid'} = $query_or_sid;
    $self->{'gcs_dsn_args'} = $dsn_args;
    $self->{'gcs_readonly'} = $read_only;
    return $self;
}

sub _driver {
    my $self = shift;
    my $driverName = "Bio::Graphics::Browser2::OracleSessionDriver";
    $driverName->new( $self->{_DRIVER_ARGS} );
}

sub logPrefix {
	my $self = shift;
	my $isError = shift;
    return "GbCgiSession (PID $$): " . ($isError ? "Error: " : "");
}

sub flush {
    my $self = shift;

    print STDERR logPrefix(0) . "flush() called\n";

    # Would it be better to die or err if something very basic is wrong here? 
    # I'm trying to address the DESTROY related warning
    # from: http://rt.cpan.org/Ticket/Display.html?id=17541
    # return unless defined $self;

    print STDERR logPrefix(0) . "Session is empty; returning with no action.\n" unless $self->id;
    return unless $self->id;            # <-- empty session

    # neither new, nor deleted nor modified
    print STDERR logPrefix(0) . "Session is not empty but is not new, deleted, or modified; returning with no action.\n" if !defined($self->{_STATUS}) or $self->{_STATUS} == STATUS_UNSET;
    return if !defined($self->{_STATUS}) or $self->{_STATUS} == STATUS_UNSET;

    if ( $self->_test_status(STATUS_NEW) && $self->_test_status(STATUS_DELETED) ) {
        $self->{_DATA} = {};
        return $self->_unset_status(STATUS_NEW | STATUS_DELETED);
    }

    my $driver      = $self->_driver();
    my $serializer  = $self->_serializer();
    my $sid = $self->id;

    if ( $self->_test_status(STATUS_DELETED) ) {
        print STDERR logPrefix(0) . "Deleting GBrowse session with id $sid\n";
        defined($driver->remove($self->id)) or
            return $self->set_error( logPrefix(1) . "flush(): couldn't remove session data: " . $driver->errstr );
        $self->{_DATA} = {};                        # <-- removing all the data, making sure
                                                    # it won't be accessible after flush()
        return $self->_unset_status(STATUS_DELETED);
    }

    if ( $self->_test_status(STATUS_NEW | STATUS_MODIFIED) ) {

        print STDERR logPrefix(0) . "Updating value of GBrowse session with id $sid\n";

        # convert session data to string for storing
        my $datastr = $serializer->freeze( $self->dataref ) or
            return $self->set_error( logPrefix(1) . "flush(): couldn't freeze data: " . $serializer->errstr );

        # test that freeze() returned a value
        unless ( defined $datastr ) {
            print STDERR logPrefix(1) . "Could not freeze data: " . $serializer->errstr . "\n";
            return $self->set_error( logPrefix(1) . "flush(): couldn't freeze data: " . $serializer->errstr );
        }

        # make sure string generated can be reconstituted into an object
        my $sessionData = $serializer->thaw($datastr) or
            return $self->set_error( logPrefix(1) . "flush(): Serialized session is not deserializable!\nSession = \n$datastr" );

        # destructure values saved from original load; need them to test eventual write
        my ($dsn, $sid, $dsn_args, $readonly) = ($self->{'gcs_dsn'}, $self->{'gcs_sid'}, $self->{'gcs_dsn_args'}, $self->{'gcs_readonly'});
        # FIXME: not sure why this value is sometimes different, but for now, just use this sessions ID
        $sid = $self->id;
        #print STDERR "Retrieved values: {$dsn} {$sid} {$dsn_args} {$readonly}\n";
        #if ( $sid ne $self->id ) {
        #    return $self->set_error( "GbCgiSession: Error: passed SID $sid does not match loaded SID " . $self->id );
        #}

        # try some number of times to store session before admitting failure
        my $remainingAttempts = 5;
        my $success = 0;
        while ( $remainingAttempts > 0 && !$success ) {

            # store the session
            print STDERR logPrefix(0) . "Attempting to store session for SID $sid.  $remainingAttempts attempts remaining.\n";
            if ( ! defined($driver->store($self->id, $datastr)) ) {
                print STDERR logPrefix(1) . "store() attempt failed; couldn't store datastr: " . $driver->errstr;
                $remainingAttempts--;
                next;
            }

            # seem to have stored data ok, but let's make sure
            print STDERR logPrefix(0) . "Testing session write for sid $sid\n";
            my $error = 0;
            my $testSession = Bio::Graphics::Browser2::GbCgiSession->load($dsn, $sid, $dsn_args, $readonly) or $error = 1;
            if ( $error ) {
                print STDERR logPrefix(1) . "Unable to load just-written session with sid $sid\n" . CGI::Session->errstr();
                $remainingAttempts--;
                next;
            }
            if ( $testSession->is_expired || $testSession->is_empty ) {
                print STDERR logPrefix(1) . "Very recently stored session is expired or empty!\n";
                $remainingAttempts--;
                next;
            }

            # unset new/modified status if success
            $success = 1;
            $self->_unset_status(STATUS_NEW | STATUS_MODIFIED);
        }

        if (!$success) {
            my $errorMsg = logPrefix(1) . "flush() failed, attempts to save session have been exhausted.";
            print STDERR "$errorMsg\n";
            return $self->set_error($errorMsg);
        }
    }

    print STDERR logPrefix(0) . "flush() complete\n";
    return 1;
}

1;
