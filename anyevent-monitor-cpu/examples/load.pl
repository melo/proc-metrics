#!perl

use strict;
use warnings;
use lib '../lib';
use AnyEvent;
use AnyEvent::Monitor::CPU 'monitor_cpu';

my $monitor = monitor_cpu cb => sub {
  my ($self, $on_off_flag) = @_;

  if ($on_off_flag) {
    print "... triggered CPU idle\n";
  }
  else {
    print "... triggered CPU loaded\n";
  }
};
$monitor->start();

sub simulate_high_load {
  my $cnt = 100_000;
  while ($cnt--) {
    $_ = $cnt * 100;
  }
}


## High load phase
my $cv   = AE::cv;
my $load = AE::timer(.01, .01, \&simulate_high_load);
my $t    = AE::timer(5, 0, sub { undef $load; $cv->send });

print "Start high-load simulation for 5 seconds...\n";
$cv->recv;
print "Ended high-load simulation.\n";


## Low load phase
$cv = AE::cv;
$t = AE::timer(5, 0, sub { $cv->send });

print "Start idle-load simulation for 5 seconds...\n";
$cv->recv;
print "Ended simulation.\n";
