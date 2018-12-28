####################################################################
#
# ECSCM::Vault::Driver  Object to represent interactions with 
#        Vault.
####################################################################
package ECSCM::Vault::Driver;
@ISA = (ECSCM::Base::Driver);
use ElectricCommander;
use XML::XPath;
use XML::XPath::XMLParser;
use Time::Local;
use File::Basename;
use Getopt::Long;
use HTTP::Date(qw {str2time time2str time2iso time2isoz});
use strict;


$|=1;


####################################################################
# Object constructor for ECSCM::Vault::Driver
#
# Inputs
#    cmdr          previously initialized ElectricCommander handle
#    name          name of this configuration
#                 
####################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $cmdr = shift;
    my $name = shift;

    my $cfg = new ECSCM::Vault::Cfg($cmdr, $name);
    
    if ($name ne '') {
        my $sys = $cfg->getSCMPluginName();
        if ($sys ne 'ECSCM-Vault') { die "SCM config $name is not type ECSCM-Vault"; }
    }

    my ($self) = new ECSCM::Base::Driver($cmdr,$cfg);

    bless ($self, $class);
    return $self;
}

####################################################################
# isImplemented
####################################################################
sub isImplemented {
    my ($self, $method) = @_;
    
    if ($method eq 'getSCMTag'  ||
        $method eq 'apf_driver' ||     
        $method eq 'cpf_driver' ||
        $method eq 'checkoutCode') {
        return 1;
    } else {
        return 0;
    }
}

####################################################################
# collects the standar command line options and return an array
# with them
####################################################################
sub collectCommonOpts{
    my ($self, $opts, @cmd) = @_;
    
    if($opts->{Server} && $opts->{Server} ne ""){
        push(@cmd,"-host $opts->{Server}");
    }
    
    if($opts->{VaultUserName} && $opts->{VaultUserName} ne ""){
        push(@cmd,"-user $opts->{VaultUserName}");
    }
    
    if($opts->{VaultPassword} && $opts->{VaultPassword} ne ""){
        push(@cmd,"-password $opts->{VaultPassword}");
    }
    
    if($opts->{VaultRepository} && $opts->{VaultRepository} ne ""){
        push(@cmd,qq{-repository "$opts->{VaultRepository}"});
    }
    
    return @cmd;
}

####################################################################
# get scm tag for sentry (continous integration)
####################################################################

####################################################################
# getSCMTag
# 
# Get the latest changelist on this branch/client
#
# Args:
# Return: a string representing the latest changes
#         
####################################################################
sub getSCMTag
{
    my ($self, $opts) = @_;

    # add configuration that is stored for this config
    my $name = $self->getCfg()->getName();
    my %row = $self->getCfg()->getRow($name);
    foreach my $k (keys %row) {
            $opts->{$k}=$row{$k};
    }

    # Load userName and password from the credential
    ($opts->{VaultUserName}, $opts->{VaultPassword}) = 
        $self->retrieveUserCredential($opts->{config},
        $opts->{VaultUserName}, $opts->{VaultPassword});

    # set the Vault command
    #   vault.exe VERSIONHISTORY -user admin -password Adm1234 -host velecloudserver -repository test $
    my @cmd = ();
    
    if($opts->{VaultPath} && $opts->{VaultPath} ne ""){
        push(@cmd, qq{"$opts->{VaultPath}"});
    }
    
    push(@cmd,"VERSIONHISTORY");
    
    @cmd = $self->collectCommonOpts($opts, @cmd);
    
    if($opts->{RepositoryFolder} && $opts->{RepositoryFolder} ne ""){
        push(@cmd, qq{"$opts->{RepositoryFolder}"});
    }

    my $commandLine = join(" ",@cmd);
    
    my $passwordStart = index($commandLine,"-password ");
    $passwordStart += 10;
    my $passwordLength = (length $commandLine) - $passwordStart;
    
    my $cmndReturn = $self->RunCommand("$commandLine", 
                {LogCommand => 1, LogResult => 1, HidePassword => 1,
                passwordStart => $passwordStart, 
                passwordLength => $passwordLength } );

    # parse the result looking for the most recent date
    #   <vault>
    #     <history>
    #       <item version="3" date="26/10/2010 04:29:33 PM" user="admin" objverid="6" txid="4" />
    #       <item version="2" date="26/10/2010 03:36:22 PM" user="admin" objverid="4" txid="3" />
    #       <item version="1" date="26/10/2010 02:12:22 PM" user="admin" comment="creating repository" objverid="1" txid="1" />
    #     </history>
    #     <result>
    #       <success>True</success>
    #     </result>
    #   </vault>
    #   
    #   =============================================================================
    my $changesetNumber = undef;
    my $changeTimeStamp = undef;
    
    my $xPath = XML::XPath->new($cmndReturn);
    my $nodeset = $xPath->find('/vault/history/item'); # find all items
    my @node = $nodeset->get_nodelist; #store all nodes in an array
    my $lastNode = XML::XPath::XMLParser::as_string(@node[0]); # the last change will be always in the first possition
    $lastNode =~ m/version=\"(\d+)\" date=\"(\d+)\/(\d+)\/(\d+)\s(\d+)\:(\d+)\:(\d+)\s((a.m|p.m))/i;
    
    $changesetNumber = $1;
    my $day = $2;
    my $month = $3;
    my $year = $4;
    my $hours = $5;
    my $minutes = $6;
    my $seconds = $7;
    
    if ($8 =~ /P.M/i  &&  ($hours < 12) ) {
        $hours += 12;
    }
    if ($8 =~ /AM/i  &&  ($hours == 12) ) {
        $hours = 0;
    }
    
    $changeTimeStamp = timelocal($seconds, $minutes, $hours, $day, $month-1, $year);
    
    return ($changesetNumber, $changeTimeStamp);
}

####################################################################
# checkoutCode
#
# Results:
#   Collects data to call functions to set up the scm change log.
#
# Arguments:
#   self -              the object reference
#   opts -              A reference to the hash with values
#
# Returns
#   Output of the the "stcmd co" command.
#
####################################################################
sub checkoutCode
{
    my ($self, $opts) = @_;
 
    # add configuration that is stored for this config
    my $name = $self->getCfg()->getName();
    my %row = $self->getCfg()->getRow($name);
    foreach my $k (keys %row) {
            $opts->{$k}=$row{$k};
    }

    # Load userName and password from the credential
    ($opts->{VaultUserName}, $opts->{VaultPassword}) = 
        $self->retrieveUserCredential($opts->{config},
        $opts->{VaultUserName}, $opts->{VaultPassword});
    
    my @cmd = ();

    if($opts->{VaultPath} && $opts->{VaultPath} ne ""){
        push(@cmd, qq{"$opts->{VaultPath}"});
    }else{
        push(@cmd, qq{vault});
    }
    
    push(@cmd,"GET");
    
    @cmd = $self->collectCommonOpts($opts, @cmd);
    
    if($opts->{WorkingFolder} && $opts->{WorkingFolder} ne ""){
        push(@cmd, qq{-workingfolder "$opts->{WorkingFolder}"});
    }
    
    if($opts->{RepositoryFolder} && $opts->{RepositoryFolder} ne ""){
        push(@cmd, qq{"$opts->{RepositoryFolder}"});
    }elsif($opts->{dest} && $opts->{dest} ne ""){
        push(@cmd, qq{"$opts->{dest}"});
    }
    
    my $commandLine = join(" ",@cmd);
    
    my $passwordStart = index($commandLine,"-password ");
    $passwordStart += 10;
    my $passwordLength = (length $commandLine) - $passwordStart;
    
    my $cmndReturn = $self->RunCommand("$commandLine", 
                {LogCommand => 1, LogResult => 0, HidePassword => 1,
                passwordStart => $passwordStart, 
                passwordLength => $passwordLength } );
    
    return $cmndReturn;
}

###############################################################################
# agentPreflight routines  (apf_xxxx)
###############################################################################

###############################################################################
# apf_getScmInfo
#
#       If the client script passed some SCM-specific information, then it is
#       collected here.
###############################################################################

sub apf_getScmInfo
{
    my ($self,$opts) = @_;
    my $scmInfo = $self->pf_readFile('ecpreflight_data/scmInfo');
    $scmInfo =~ m/(.*)\n(.*)\n(.*)\n(.*)\n(.*)\n(.*)/;

    $opts->{WorkingFolder} = $1;
    $opts->{Server} = $2;
    $opts->{VaultUserName} = $3;
    $opts->{VaultPassword} = $4;
    $opts->{VaultRepository} = $5;
    $opts->{VaultPath} = $6;
  
   print(qq{Vault information received from client:
            WorkingFolder:  $opts->{WorkingFolder}
            Server name:    $opts->{Server}
            Repository:     $opts->{VaultRepository}
            Vault Location: $opts->{VaultPath}
                });
}

###############################################################################
# apf_createSnapshot
#
#       Create the basic source snapshot before overlaying the deltas passed
#       from the client.
###############################################################################
sub apf_createSnapshot
{   
    my ($self,$opts) = @_;

    my $jobId = $::ENV{COMMANDER_JOBID};
            
    my $result = $self->checkoutCode($opts);
    if (defined $result) {
        print "checked out $result\n";
    }
}

################################################################################
# apf_driver
#
# agent preflight driver for Vault
################################################################################
sub apf_driver()
{
    my $self = shift;
    my $opts = shift;
    
    if ($opts->{test}) { $self->setTestMode(1); }
    $opts->{delta} = 'ecpreflight_files'; 
    
    $self->apf_downloadFiles($opts);
    $self->apf_transmitTargetInfo($opts);
    $self->apf_getScmInfo($opts);
    $self->apf_createSnapshot($opts);
    $self->apf_deleteFiles($opts);
    $self->apf_overlayDeltas($opts);
}

###############################################################################
# clientPreflight routines  (cpf_xxxx)
###############################################################################

#------------------------------------------------------------------------------
# cpf_localDelta
#
#   use bzr status to find deltas between working dir and local repo
#   retrieves both tracked and untracked files
#
#  returns the files in a list   
#------------------------------------------------------------------------------
sub cpf_localDelta {
    my ($self, $opts) = @_;
    $self->cpf_display('Collecting deltas from local repo');
    
    my @cmd = ();
    if($opts->{scm_vaultLocation} && $opts->{scm_vaultLocation} ne ""){
        push(@cmd,qq{"$opts->{scm_vaultLocation}"});
    }else{
        push(@cmd, "vault");
    }
    
    push(@cmd, "LISTCHANGESET");
    
    @cmd = $self->collectCommonOpts($opts, @cmd);
    
    my $commandLine = join(" ",@cmd);
    
    my $output  = $self->RunCommand($commandLine, {LogCommand => 0, IgnoreError=>1, LogResult => 0});
    
    #<vault>
    #    <changeset>
    #        <UnmodifiedFile>
    #            <id>0</id>
    #            <respospath>$/QAtest/testFolder1/QADocument.txt</respospath>
    #            <localpath>C:\\VaultTest\\QAtest\\testFolder1\\QADocument.txt</localpath>
    #        </UnmodifiedFile>
    #        <ModifyFile>
    #            <id>1</id>
    #            <repospath>$/QAtest/testFolder1/test1.txt</repospath>
    #            <localpath>C:\\VaultTest\\QAtest\\testFolder1\\test1.txt</localpath>
    #        </ModifyFile>
    #    </changeset>
    #    <result>
    #        <success>True</success>
    #    </result>
    #</vault>
    
    my $xPath = XML::XPath->new($output);
    my $nodeset = $xPath->find('/vault/changeset/ModifyFile');
    my @nodes = $nodeset->get_nodelist;
    my %deltas;
    foreach my $node (@nodes){
        my $currentLine = XML::XPath::XMLParser::as_string($node);
        $currentLine =~ m/<repospath>(.*)<\/repospath>\s+<localpath>(.*)<\/localpath>/g;
        my $localPath = $1;
        $localPath =~ s/\$\///;
        $deltas{$localPath} = $localPath;
    }
    return %deltas;
}

#------------------------------------------------------------------------------
# copyDeltas
#
#       Finds all new and modified files, and calls putFiles to upload them
#       to the server.
#------------------------------------------------------------------------------
sub cpf_copyDeltas() {
    my ($self, $opts) = @_;
    $self->cpf_display('Collecting delta information');
      
    # change to the bazaar dir
    if (!defined($opts->{scm_workdir}) ||  "$opts->{scm_workdir}" eq '') {
        $self->cpf_error("Could not change to directory $opts->{scm_workdir}");
    }   
    
    chdir ($opts->{scm_workdir}) || $self->cpf_error("Could not change to directory $opts->{scm_workdir}");
    
    $self->cpf_saveScmInfo($opts,join("\n",$opts->{scm_workdir},
                                        $opts->{Server},
                                        $opts->{VaultUserName},
                                        $opts->{VaultPassword},
                                        $opts->{VaultRepository},
                                        $opts->{VaultPath})); 
    $self->cpf_findTargetDirectory($opts);
    $self->cpf_createManifestFiles($opts);
    
    # get files that are different between the working directory
    # and the repostitory
    my %deltas =  $self->cpf_localDelta($opts);
    while ( my ($source, $dest) = each(%deltas) ) {
        $self->cpf_addDelta($opts, $source, $dest);
    }
     
    $self->cpf_closeManifestFiles($opts);
    $self->cpf_uploadFiles($opts);    
}

#------------------------------------------------------------------------------
# driver
#
#       Main program for the application.
#------------------------------------------------------------------------------
sub cpf_driver {
         my ($self, $opts) = @_;
    
    $::gHelpMessage .= "
Vault Options:
  --workdir   <path>      The developer's source directory.
  --host                  Hostname of the server to connect to.
  --user                  Username to use when connecting to server.
  --password              Password to use when connecting to server.
  --repository            Repository to connect to.
  --vaultLocation         Absolute path to vault.exe.
";

    $self->cpf_display('Executing Vault actions for ecpreflight');

    ## override config file with command line options 
    
    my %ScmOptions = (       
    'workdir=s'             => \$opts->{scm_workdir},
    'host=s'             => \$opts->{scm_server},
    'user=s'             => \$opts->{scm_user},
    'password=s'             => \$opts->{scm_password},
    'repository=s'             => \$opts->{scm_repository},
    'vaultLocation=s'             => \$opts->{scm_vaultLocation},    
    );

    Getopt::Long::Configure('default');
    if (!GetOptions(%ScmOptions)) {
        error($::gHelpMessage);
    }

    if ($::gHelp eq '1') {
        $self->cpf_display($::gHelpMessage);
        return;
    }
    #search the options in the config file if they are not defined already 
    $self->extractOption($opts,'scm_workdir', { required => 1, cltOption => 'workdir' });
    $self->extractOption($opts,'scm_server', { required => 1, cltOption => 'server' });    
    $self->extractOption($opts,'scm_user', { required => 1, cltOption => 'user' });    
    $self->extractOption($opts,'scm_password', { required => 1, cltOption => 'password' });    
    $self->extractOption($opts,'scm_repository', { required => 1, cltOption => 'repository' });
    $self->extractOption($opts,'scm_vaultLocation', { required => 0, cltOption => 'vaultLocation' });     
    
    $opts->{Server}          = $opts->{scm_server};
    $opts->{VaultUserName}   = $opts->{scm_user};
    $opts->{VaultPassword}   = $opts->{scm_password};
    $opts->{VaultRepository} = $opts->{scm_repository};
    $opts->{VaultPath}       = $opts->{scm_vaultLocation};
    
    # Copy the deltas to a specific location.
    $self->cpf_copyDeltas($opts);
    
}
1;
