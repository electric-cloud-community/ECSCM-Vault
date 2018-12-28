####################################################################
#
# ECSCM::Vault::Cfg: Object definition of CC  configuration.
#
####################################################################
package ECSCM::Vault::Cfg;
@ISA = (ECSCM::Base::Cfg);
if (!defined ECSCM::Base::Cfg) {
    require ECSCM::Base::Cfg;
}


####################################################################
# Object constructor for ECSCM::Vault::Cfg
#
# Inputs
#   cmdr  = a previously initialized ElectricCommander handle
#   name  = a name for this configuration
####################################################################
sub new {
    my $class = shift;

    my $cmdr = shift;
    my $name = shift;

    my($self) = ECSCM::Base::Cfg->new($cmdr,"$name");
    bless ($self, $class);
    return $self;
}

####################################################################
# VaultHostName
####################################################################
sub getVaultHostName {
    my ($self) = @_;
    return $self->getServer();
}
sub setVaultHostName {
    my ($self, $name) = @_;
    print "Setting VaultHostName to $name\n";
    return $self->setServer("$name");
}

####################################################################
# VaultPassword
####################################################################
sub getVaultPassword {
    my ($self) = @_;
    return $self->getPassword();
}
sub setVaultPassword {
    my ($self, $name) = @_;
    print 'Setting VaultPassword to ***\n';
    return $self->setPassword("$name");
}

####################################################################
# VaultUserName
####################################################################
sub getVaultUserName {
    my ($self) = @_;
    return $self->getUser();
}
sub setVaultUserName {
    my ($self, $name) = @_;
    print "Setting VaultUserName to $name\n";
    return $self->setUser("$name");
}

####################################################################
# VaultRepository
####################################################################
sub getVaultRepository {
    my ($self) = @_;
    return $self->getUser();
}
sub setVaultRepository {
    my ($self, $name) = @_;
    print "Setting VaultRepository to $name\n";
    return $self->setUser("$name");
}

####################################################################
# VaultServer
####################################################################
sub getVaultServer {
    my ($self) = @_;
    return $self->getUser();
}
sub setVaultServer {
    my ($self, $name) = @_;
    print "Setting VaultServer to $name\n";
    return $self->setUser("$name");
}

1;
