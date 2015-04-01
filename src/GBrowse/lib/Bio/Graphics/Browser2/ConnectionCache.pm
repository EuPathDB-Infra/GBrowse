package Bio::Graphics::Browser2::ConnectionCache;

use DBI;

use strict;
use warnings;

my $instance = undef;

sub get_instance {
    my $class = shift;
    $instance = $class->new if !$instance;
    $instance;
}

sub new {
    my $class = shift;
    my %cache = ();
    bless {
        cache => \%cache,
        closed => 0
    }, $class;
}

sub connect {
    my $self = shift;
    my ($connectionStr, $username, $password, $source) = @_;
    chomp $connectionStr;
    my $delim = "|+|";
    my $hash = $delim.$connectionStr.$delim.$username.$delim.$password.$delim;
    my $cacheRef = $self->{cache};
    my $alreadyPresentStr = (exists($cacheRef->{$hash}) ? "yes" : "no");
    #print STDERR "PID $$: Connection requested from $source, alreadyPresent? $alreadyPresentStr\n";
    # return if already exists
    return $cacheRef->{$hash} if exists $cacheRef->{$hash};
    # if not, create, add to cache, and return
    my $dbh = DBI->connect($connectionStr, $username, $password)
        or $self->throw("Unable to open db handle to ".$connectionStr." with user ".$username.", Error Message: ".$DBI::errstr);

    # solve oracle clob problem
    $dbh->{LongTruncOk} = 0;
    $dbh->{LongReadLen} = 10000000;

    # get 500 rows at a time for efficiency.
    $dbh->{RowCacheSize} = 500;

    # since we will explicitly disconnect, don't disconnect during dbh destroy
    # NOTE: commenting out this line is "safer" since setting to 1 creates a possible
    #       connection leak of any dbh objects DESTROYed before the ConnectionCache
    #       is DESTROYed (see below); however uncommenting it prevents two Oracle
    #       errors we used to see all the time when trying to disconnect:
    #             ORA-03113: end-of-file on communication channel
    #             ORA-03135: connection lost contact
    $dbh->{InactiveDestroy} = 1;
    
    $cacheRef->{$hash} = $dbh;
    return $cacheRef->{$hash};
}

sub close {
    my $self = shift;
    return if $self->{closed};
    my $cacheRef = $self->{cache};
    # (try to) explicitly close cached connections
    while( my ($hash, $dbh) = each %$cacheRef ) {
        #print STDERR "PID $$: Closing connection\n";
        # NOTE: This sometimes fails if DBH is already closed (probably by DESTROY as perl
        #       shuts down).  This is OK and expected since order of DESTROY calls is
        #       undefined.  We still want this call here to be as clean as possible.
        $dbh->disconnect;
    }
    $self->{closed} = 1;
}

sub DESTROY {
    shift->close;
}

1;

