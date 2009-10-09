package AnyEvent::Monitor::CPU;

use common::sense;
use AnyEvent;
use Proc::CPUUsage;
use Carp qw( croak );
use parent qw( Exporter );

@AnyEvent::Monitor::CPU::EXPORT_OK = ('monitor_cpu');

## Shortcut, optional import
sub monitor_cpu { return __PACKAGE__->new(@_) }


sub new {
  my $class = shift;
  my %args = @_ == 1 ? %{$_[0]} : @_;

  my $self = bless {
    cb => delete $args{cb} || croak("Required parameter 'cb' not found, "),

    after => delete $args{after} || $args{interval} || .25,
    interval => delete $args{interval} || .25,

    high         => delete $args{high}         || .95,
    low          => delete $args{low}          || .80,
    high_samples => delete $args{high_samples} || 1,
    low_samples  => delete $args{low_samples}  || 1,
    cur_high_samples => 0,
    cur_low_samples  => 0,

    cpu => delete $args{cpu} || Proc::CPUUsage->new,
    usage => undef,
    state => 1,
  }, $class;

  $self->start;

  return $self;
}

sub start {
  my $self = shift;

  $self->{timer} = AnyEvent->timer(
    after    => $self->{after},
    interval => $self->{interval},
    cb       => sub { $self->_check_cpu },
  );

  $self->{usage} = $self->{cpu}->usage;

  return;
}

sub stop { delete $_[0]->{timer} }

sub usage   { return $_[0]->{usage} }
sub is_low  { return $_[0]->{state} == 1 }
sub is_high { return $_[0]->{state} == 0 }

sub _check_cpu {
  my $self = $_[0];
  my $chs  = $self->{current_high_samples};
  my $cls  = $self->{current_low_samples};

  my $usage = $self->{usage} = $self->{cpu}->usage;
  if    ($usage > $self->{high}) { $chs++; $cls = 0 }
  elsif ($usage < $self->{low})  { $cls++; $chs = 0 }

  my $hs      = $self->{high_samples};
  my $ls      = $self->{low_samples};
  my $state   = $self->{state};
  my $trigger = 0;
  if ($chs >= $hs) {
    $chs = $hs;
    if ($state) {
      $state   = 0;
      $trigger = 1;
    }
  }
  elsif ($cls >= $ls) {
    $cls = $ls;
    if (!$state) {
      $state   = 1;
      $trigger = 1;
    }
  }

  $self->{state}                = $state;
  $self->{current_high_samples} = $chs;
  $self->{current_low_samples}  = $cls;

  $self->{cb}->($self, $state) if $trigger;
}

1;
