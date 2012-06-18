package MyApp::Index;
use strict;
use warnings;
#use base qw(CGI::Application);
#use CGI::Application::Plugin::TT;
#use CGI::Application::Plugin::Config::YAML;
use CGI::Carp qw(fatalsToBrowser);
use MyApp::KVM;
use List::MoreUtils qw(any);
use base qw(MyApp);

sub setup {
  my $self = shift;
  $self->mode_param('rm');
  $self->run_modes(
    'index'     => 'index',
    'start'     => 'index',
    'status'    => 'status',
    'console'   => 'console',
  );
}

sub index {
  my $self  = shift;

  my $host  = $self->untaint($self->param('host'));
  my $conf  = $self->config_param();
  my @hosts = @{ $conf->{hosts} }; 
  my $user  = $conf->{libvirt_ssh_user};
  my $timeout = $conf->{timeout};

  if ($host) {
    if (any {$host eq $_} @hosts) {
      @hosts = $host;
    }
    else {
      return $self->error(404, "$host: no such hypervisor");
    }
  }

  my $data;
  my @dead_hosts;
  for my $host ( @hosts ) {
    my $kvm = MyApp::KVM->new({
      user => $user, host => $host, timeout => $timeout, readonly => 1,
    });

    my $domains = $kvm->get_active_domain;
    if (defined $domains) {
      $data->{$host} = $domains;
    }
    else {
      push @dead_hosts, $host;
    }
  }

  my $dom_state_table = MyApp::KVM::get_dom_state_table;

  return $self->tt_process('index.tt', {
    state => $dom_state_table,
    data  => $data,
    dead_hosts => \@dead_hosts,
  });
}

sub status {
  my $self   = shift;
  my $host   = $self->untaint($self->param('host'))
    || return $self->error('404', 'host parameter is invalid');
  my $vm     = $self->untaint($self->param('vm'))
    || return $self->error('404', 'vm parameter is invalid');
  my $action = $self->untaint($self->query->param('action'));
  #my $action = $self->untaint($self->param('action'));

  my $conf    = $self->config_param();
  my $timeout = $conf->{timeout};
  my $user    = $conf->{libvirt_ssh_user};
  my @hosts   = @{ $conf->{hosts} }; 
  if (! any {$host eq $_} @hosts) {
    return $self->error(404, "$host: no such hypervisor");
  }

  my $readonly = $action ? 0 : 1;

  my $kvm = MyApp::KVM->new({ 
    user => $user, host => $host, readonly => $readonly, timeout => $timeout,
  });

  $kvm->set_dom($vm);
  my $dom = $kvm->get_dom;

  my $info = $kvm->get_vm_info($vm);
  if (! $info ) {
    return $self->error(404, "$vm: no such virtual machine");
  }

  $info = $kvm->modify_info($info);

  my $error;
  if ($action) {
    if ($ENV{REQUEST_METHOD} eq 'POST') {
      $error = $kvm->action($action);
    }
  }
  return $self->tt_process('status.tt', {
    host  => $host,
    vm    => $vm,
    info  => $info,
    error => $error,
  });
} 

sub console {
  my $self   = shift;
  my $host   = $self->untaint($self->param('host'))
    || return $self->error('404', 'host parameter is invalid');
  my $vm     = $self->untaint($self->param('vm'))
    || return $self->error('404', 'vm parameter is invalid');

  my $conf    = $self->config_param();
  my $timeout = $conf->{timeout};
  my $user    = $conf->{libvirt_ssh_user};
  my $vnc_ssh_user    = $conf->{vnc_ssh_user};
  my @hosts   = @{ $conf->{hosts} }; 
  if (! any {$host eq $_} @hosts) {
    return $self->error(404, "$host: no such hypervisor");
  }

  my $readonly = 1;

  my $kvm = MyApp::KVM->new({ 
    user => $user, host => $host, readonly => $readonly, timeout => $timeout,
  });

  $kvm->set_dom($vm);
  my $dom = $kvm->get_dom;

  my $graphics = $kvm->get_graphics_config;

  return $self->tt_process('console.tt', {
    vnc_ssh_user  => $vnc_ssh_user,
    host  => $host,
    vm    => $vm,
    port  => $graphics->{port},
  });
}

sub is_verbose {
  my $self = shift;
  my $query = $self->query;
  return $query->param('verbose');
}

sub error {
  my ($self, $status, $error) = @_;
  $status ||= 200;
  $self->header_add(-Status => $status);
  return $self->tt_process('error.tt', {
    class  => "alert alert-error",
    error  => $error,
    status => $status,
  });
}

sub untaint {
  my ($self, $str) = @_;
  $str = '' if not defined $str;
  $str =~ m{^([-_\.0-9A-Za-z]+)$}o;
  return $1;
}


1;
