#!perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use_ok('AnyEvent::Monitor::CPU');

throws_ok sub { AnyEvent::Monitor::CPU->new },
  qr/Required parameter 'cb' not found, /;

done_testing();
