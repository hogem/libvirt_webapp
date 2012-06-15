use strict;
use warnings;
use Plack::Builder;
use Plack::App::WrapCGI;
use Plack::App::File;
use Plack::Middleware::Header;
use File::Basename;

my $root_dir = File::Basename::dirname(__FILE__);

builder {
  enable 'Static',
    path => qr!^/(?:(?:css|js|img)/|favicon\.ico$)!,
    root => $root_dir . '/static';
  mount "/"    => Plack::App::WrapCGI->new(script => "index.cgi")->to_app;
};
