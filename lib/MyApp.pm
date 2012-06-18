package MyApp;
use base qw(CGI::Application);
use strict;
use warnings;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::Config::YAML;
use CGI::Carp qw(fatalsToBrowser);

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

1;
