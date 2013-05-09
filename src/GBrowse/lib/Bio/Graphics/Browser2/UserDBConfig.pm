package Bio::Graphics::Browser2::UserDBConfig;

use strict;
use Carp;
use XML::Simple;
use File::Basename;
use Data::Dumper;
use Bio::Graphics::Browser2::DbUtils qw(resolveOracleDSN jdbc2oracleDbi jdbc2postgresDbi);

sub new {
    my $class = shift;
    
    my $configFile = "$ENV{GUS_HOME}/config/$ENV{PROJECT_ID}/gb-userdb-config.xml";

    unless (-e $configFile) {
    	die "Config file does not exist.  Looking for $configFile\n";
    }

    my $cfg = XMLin($configFile, ForceArray => 1);

    # check DB type
    my $dbType = lc($cfg->{'dbType'}[0] ||= "oracle"); # default to Oracle
    
    # get connection string; this will be a JDBC value
    my $jdbcString = $cfg->{'connectionDsn'}[0];
    my $dbiString;
    
    if ($dbType eq "oracle") {
    	$dbiString = jdbc2oracleDbi($jdbcString);
    	if (-e "$ENV{ORACLE_HOME}/bin/tnsping") {
          # attempt to resolve the Oracle TNS name into a connection string DBI understands
          $dbiString = resolveOracleDSN("Bio::Graphics::Browser2::DbUtils", $dbiString);
    	}
    	else {
    	  print STDERR "WARNING: Found Oracle DSN but cannot find tnsping utility; if your ".
    	    "connection string contains a TNS name, it may not be properly resolved.\n";
    	}
    }
    elsif ($dbType eq "postgres") {
    	$dbiString = jdbc2postgresDbi($jdbcString);
    }
    else {
    	die "Only 'oracle' and 'postgres' are valid values for dbType. '$dbType' is unsupported.";
    }
    
    # add trailing dot to schema if not already present
    my $schema = $cfg->{'schema'}[0];
    $schema .= "." if ($schema !~ /\.$/);

    # check if performance logging turned on (default off)
    my $perfLogOn = $cfg->{'loggingOn'} ||= 0;

    my $self = bless {
        dbiString   => $dbiString,
        jdbcString  => $jdbcString,
        username    => $cfg->{'username'}[0],
        password    => $cfg->{'password'}[0],
        schema      => $schema,
        perfLogOn   => $perfLogOn,
        dbType      => $dbType
    }, ref $class || $class;
    
    return $self;
}

# db connection params
sub getDbiString   { shift->{'dbiString'} };
sub getJdbcString  { shift->{'jdbcString'} };
sub getUsername    { shift->{'username'} };
sub getPassword    { shift->{'password'} };
sub getSchema      { shift->{'schema'} };
sub perfLogOn      { shift->{'perfLogOn'} };
sub getDbType      { shift->{'dbType'} };
sub isOracle       { (shift->{'dbType'} == 'oracle'); };
sub isPostgres     { (shift->{'dbType'} == 'postgres'); };
1;
