package MyApp::KVM;

use strict;
use warnings;
use Sys::Virt;
use Sys::Virt::Domain;
use IO::Socket;
use Carp;
use XML::Simple;


sub new  {
  my ($class, $stuff) = @_;

  $stuff->{timeout} ||= 3;
  bless $stuff, $class;
  $stuff->{vmm} = $stuff->get_sysvirt_object($stuff->{readonly}); 
  return $stuff;
}

sub set_dom {
  my ($self, $vm) = @_;

  my $vmm = $self->get_vmm || croak;

  my $dom;
  eval {
    $self->{dom} = $vmm->get_domain_by_name($vm);
  };

}

sub get_active_domain {
  my ($self) = @_;

  my $vmm = $self->get_vmm || return;

  my $domains;
  for my $vm ($vmm->list_domains, $vmm->list_defined_domains) {
    $domains->{ $vm->get_name } = $vm->get_info->{state};
  };

  return $domains;
}

sub get_vm_info {
  my ($self) = @_;

  my $vmm = $self->get_vmm || return;
  my $dom = $self->get_dom || return; 

  return $dom->get_info;
}

sub action {
  my ($self, $action) = @_;

  my $vmm = $self->get_vmm || return;
  my $dom = $self->get_dom || return;

  if ($action eq 'destroy') {
    eval { $dom->destroy() };
    return $@;
  }
  elsif ($action eq 'create') {
    eval { $dom->create() };
    return $@;
  }

  return;
}

sub get_graphics_config {
  my ($self) = @_;
  
  my $vmm = $self->get_vmm || return;
  my $dom = $self->get_dom || return;

  my $xml = $dom->get_xml_description();
  my $xs  = XML::Simple->new();
  my $ref = $xs->XMLin($xml);

  return $ref->{devices}->{graphics};

}

sub get_sysvirt_object {
  my ($self, $readonly) = @_;

  $self->is_ssh_active( $self->get_host ) || return;

#  $SIG{ALRM} = sub {
#    croak "timeout";
#  };
  my $uri = sprintf "qemu+ssh://%s\@%s/system", $self->get_user, $self->get_host;
  my $vmm; eval {
#    alarm $self->get_timeout;
    $vmm = Sys::Virt->new(uri => $uri, readonly => $readonly);
#    alarm 0;
  };
#  alarm 0;
  if ($@) {
    return;
    #croak $@;
  }
  else {
    return $vmm;
  }
}

sub modify_info {
  my ($self, $info) = @_;

  my $new;
  push @$new, { "メモリ"   => sprintf "%d%s", $info->{memory}/1024, "MB"};
  push @$new, { "CPU"      => $info->{nrVirtCpu} };
  push @$new, { "状態"     => get_dom_state_table()->{ $info->{state} } };
  return $new;
}

sub get_vmm {
  return shift->{vmm};
}

sub get_dom {
  return shift->{dom};
}

sub get_host {
  return shift->{host};
}

sub get_user {
  return shift->{user};
}

sub get_timeout {
  return shift->{timeout} || 0;
}

sub is_ssh_active {
  my ($self, $host) = @_;

  my $socket = IO::Socket::INET->new(
    PeerAddr => $host,  PeerPort => 22,
    Proto    => 'tcp',  Timeout  => 1,
  );
  if ($socket) {
    return 1;
  }
  else {
    return;
  }
}

sub get_dom_state_table {
  return {
    Sys::Virt::Domain::STATE_NOSTATE  => 'nostate',
    Sys::Virt::Domain::STATE_RUNNING  => '起動中',
    Sys::Virt::Domain::STATE_BLOCKED  => 'blocked',
    Sys::Virt::Domain::STATE_SHUTDOWN => '停止中',
    Sys::Virt::Domain::STATE_PAUSED   => '一時停止中',
    Sys::Virt::Domain::STATE_SHUTOFF  => '停止',
    Sys::Virt::Domain::STATE_CRASHED  => 'crached',
  };
}

1;
