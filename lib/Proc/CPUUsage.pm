package Proc::CPUUsage;

use strict;
use warnings;
use BSD::Resource qw( getrusage );
use Time::HiRes qw( gettimeofday tv_interval );

sub new {
  my $class = shift;
  
  return bless [ [gettimeofday()], _cpu_time() ], $class;
}

sub usage {
  my $self = $_[0];
  my ($t0, $r0) = @$self;
  return unless defined $r0;
  
  my ($dt, $dr, $t1, $r1);
  $t1 = [gettimeofday()];
  $dt = tv_interval($t0, $t1);
  $self->[0] = $t1;
  
  $r1 = _cpu_time();
  $dr = $r1 - $r0;
  $self->[1] = $r1;
  
  return $dr/$dt;
}

sub _cpu_time {
  my ($utime, $stime) = getrusage();
  return unless defined $utime && defined $stime;
  return $utime+$stime;
}

1;
