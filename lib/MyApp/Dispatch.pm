package MyApp::Dispatch;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use base 'CGI::Application::Dispatch';

sub dispatch_args {
  return {
    prefix => 'MyApp',
    table  => [
      ''               => { app => 'Index', rm => 'index' },
      ':host'          => { app => 'Index', rm => 'index' },
      ':host/:vm/'     => { app => 'Index', rm => 'status' },
      ':host/:vm/:rm/' => { app => 'Index' },
    ],
    args_to_new => {
      PARAMS => {
        conf => './conf/config.yaml',
      },
    },
    #error_document => '<' . '/error/%s.html',
    error_document => '/error/%s.html',
  };
}

1;
