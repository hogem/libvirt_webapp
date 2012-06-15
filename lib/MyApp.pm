package MyApp;
use base qw(CGI::Application);
use strict;
use warnings;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::Config::YAML;
use CGI::Carp qw(fatalsToBrowser);
use MyApp::KVM;
use List::MoreUtils qw(any);

sub cgiapp_init {
  my $self = shift;
  $self->header_props(
    -type => 'text/html; charset=UTF-8',
    -cache_control => 'no-cache',
    -pragma => 'no-cache',
  );
  $self->tt_config(
    TEMPLATE_OPTIONS => {
      INCLUDE_PATH => "tmpl",
    },
  );

  $self->config_file('conf/config.yaml');

}

sub setup {
  my $self = shift;
  $self->mode_param('rm');
  $self->run_modes(
    'index'    => 'do_index',
    'start'    => 'do_index',
    'status'   => 'do_status',
  );
}

sub do_index {
  my $self  = shift;
  my $query = $self->query;

  my $conf  = $self->config_param();
  my @hosts = @{ $conf->{hosts} }; 
  my $user  = $conf->{user};

  my $data;
  for my $host ( @hosts ) {
    my $kvm = MyApp::KVM->new({ user => $user, host => $host});

    my $domains = $kvm->get_active_domain;
    $data->{$host} = $domains;
  }

  my $dom_state_table = MyApp::KVM::get_dom_state_table;

  return $self->tt_process('index.tt', {
    state => $dom_state_table,
    data  => $data,
  });
}

sub do_status {
  my $self   = shift;
  my $query  = $self->query;
  my $host   = $self->untaint($query->param('host'))
    || return $self->do_error('404', 'host parameter is invalid');
  my $vm     = $self->untaint($query->param('vm'))
    || return $self->do_error('404', 'vm parameter is invalid');
  my $action = $self->untaint($query->param('action'));

  my $conf   = $self->config_param();
  my $user   = $conf->{user};
  my @hosts = @{ $conf->{hosts} }; 
  if (! any {$host eq $_} @hosts) {
    return $self->do_error(404, "$host: no such hypervisor");
  }

  my $kvm = MyApp::KVM->new({ user => $user, host => $host});

  my $info = $kvm->get_vm_info($vm);
  if (! $info ) {
    return $self->do_error(404, "$vm: no such virtual machine");
  }

  $info = $kvm->modify_info($info);

  my $error;
  if ($action) {
    $error = $kvm->action($vm, $action);
  }
  return $self->tt_process('status.tt', {
    host  => $host,
    vm    => $vm,
    info  => $info,
    error => $error,
  });
} 

sub is_verbose {
  my $self = shift;
  my $query = $self->query;
  return $query->param('verbose');
}

sub do_error {
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
