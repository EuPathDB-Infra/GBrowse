package Bio::Graphics::Browser2::UserDBConfig;

use strict;
use Carp;
use XML::Simple;
use File::Basename;
use Data::Dumper;
use Bio::Graphics::Browser2::DbUtils qw(resolveOracleDSN jdbc2oracleDbi jdbc2postgresDbi);

my $USE_CUSTOM_CONFIG_FILE = 0;
my $DEFAULT_SCHEMA_NAME = "gbrowseUsers";

sub new {
    my $class = shift;

    my $STANDARD_CONFIG_FILE = "$ENV{GUS_HOME}/config/$ENV{PROJECT_ID}/model-config.xml";
    my $CUSTOM_CONFIG_FILE = "$ENV{GUS_HOME}/config/$ENV{PROJECT_ID}/gb-userdb-config.xml";

    my ($dbType, $jdbcString, $username, $password, $schema, $perfLogOn) =
        $USE_CUSTOM_CONFIG_FILE ? parseCustomConfig() : parseStandardConfig();

    # check DB type
    $dbType = lc($dbType ||= "oracle"); # default to Oracle
    
    # convert connection string (JDBC value) to DBI value
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
    $schema .= "." if ($schema !~ /\.$/);

    my $self = bless {
        dbiString   => $dbiString,
        jdbcString  => $jdbcString,
        username    => $username,
        password    => $password,
        schema      => $schema,
        perfLogOn   => $perfLogOn,
        dbType      => $dbType
    }, ref $class || $class;
    
    return $self;
}

sub parseXml {
    my $configFile = $_[0];
    #print STDERR "Parsing $configFile\n";
    unless (-e $configFile) {
        die "Config file does not exist.  Looking for $configFile\n";
    }
    return XMLin($configFile, ForceArray => 1);
}

# must return, in order: $dbType, $connectionDsn, $username, $password, $schema, $loggingOn
sub parseStandardConfig {
    #print STDERR "Inside standard, using $STANDARD_CONFIG_FILE\n";
    my $modelConf = parseXml($STANDARD_CONFIG_FILE);
    my $cfg = $modelConf->{'userDb'}[0];
    return (
        $cfg->{'platform'},
        $cfg->{'connectionUrl'},
        $cfg->{'login'},
        $cfg->{'password'},
        $DEFAULT_SCHEMA_NAME,     # schema is hard-coded in the general case
        0                         # can't turn logging on without custom config
    );
}

# must return, in order: $dbType, $connectionDsn, $username, $password, $schema, $loggingOn
sub parseCustomConfig {
    #print STDERR "Inside custom, using $CUSTOM_CONFIG_FILE\n";
    my $cfg = parseXml($CUSTOM_CONFIG_FILE);
    return (
        $cfg->{'dbType'}[0],
        $cfg->{'connectionDsn'}[0],
        $cfg->{'username'}[0],
        $cfg->{'password'}[0],
        $cfg->{'schema'}[0] ||= $DEFAULT_SCHEMA_NAME,
        $cfg->{'loggingOn'}[0] ||= 0  # logging turned off by default
    );
}

# db connection params
sub getDbiString   { shift->{'dbiString'} };
sub getJdbcString  { shift->{'jdbcString'} };
sub getUsername    { shift->{'username'} };
sub getPassword    { shift->{'password'} };
sub getSchema      { shift->{'schema'} };
sub perfLogOn      { shift->{'perfLogOn'} };
sub getDbType      { shift->{'dbType'} };
sub isOracle       { (shift->{'dbType'} eq 'oracle'); };
sub isPostgres     { (shift->{'dbType'} eq 'postgres'); };
1;
