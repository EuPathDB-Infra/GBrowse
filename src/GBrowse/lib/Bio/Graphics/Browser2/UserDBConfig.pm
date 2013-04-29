package Bio::Graphics::Browser2::UserDBConfig;

use strict;
use Carp;
use XML::Simple;
use File::Basename;
use Data::Dumper;
use Bio::Graphics::Browser2::DbUtils qw(resolveOracleDSN);

sub new {
    my $class = shift;

    my $cfg = XMLin(
        "$ENV{GUS_HOME}/config/$ENV{PROJECT_ID}/gb-userdb-config.xml",
        ForceArray => 1
    );

    # resolve the Oracle TNS name into a connection string DBI understands
    my $connectionDsn = $cfg->{'connectionDsn'}[0];
    my $connectionString = resolveOracleDSN("Bio::Graphics::Browser2::DbUtils", $connectionDsn);

    # add trailing dot to schema if not already present
    my $schema = $cfg->{'schema'}[0];
    $schema .= "." if ($schema !~ /\.$/);

    # check if performance logging turned on (default off)
    my $perfLogOn = $cfg->{'loggingOn'} ||= 0;

    my $self = bless {
        connectionString => $connectionString,
        username         => $cfg->{'username'}[0],
        password         => $cfg->{'password'}[0],
        schema           => $schema,
        perfLogOn        => $perfLogOn
    }, ref $class || $class;
    
    return $self;
}

# db connection params
sub getConnectionString { shift->{'connectionString'} };
sub getUsername         { shift->{'username'} };
sub getPassword         { shift->{'password'} };
sub getSchema           { shift->{'schema'} };
sub perfLogOn           { shift->{'perfLogOn'} };

1;
