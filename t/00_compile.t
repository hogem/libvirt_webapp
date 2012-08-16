use strict;
use Test::More tests => 4;

BEGIN {
  use_ok 'MyApp';
  use_ok 'MyApp::Dispatch';
  use_ok 'MyApp::Index';
  use_ok 'MyApp::KVM';
}

done_testing;
