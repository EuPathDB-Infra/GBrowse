package Bio::Graphics::Browser2::UserDBConfig;

use strict;
use Carp;
use XML::Simple;
use File::Basename;
use Data::Dumper;
#use Bio::Graphics::Browser2::DbUtils qw(jdbc2oracleDbi dbi2connectString);

sub new {
    my $class = shift;

    my $cfg = XMLin(
        "$ENV{GUS_HOME}/config/$ENV{PROJECT_ID}/gb-userdb-config.xml",
        ForceArray => 1
    );

    # build connection string based on other values
    my $host = $cfg->{'host'}[0];
    my $serviceName = $cfg->{'serviceName'}[0];
    my $port = $cfg->{'port'}[0];
    my $connectionString = "DBI:Oracle:HOST=".$host.";SERVICE_NAME=".$serviceName.";PORT=".$port;

    # add trailing dot to schema if not already present
    my $schema = $cfg->{'schema'}[0];
    $schema .= "." if ($schema !~ /\.$/);

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
