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
    cb => delete $args{cb},

    interval => delete $args{interval} || .25,

    high         => delete $args{high}         || .95,
    low          => delete $args{low}          || .80,
    high_samples => delete $args{high_samples} || 1,
    low_samples  => delete $args{low_samples}  || 1,
    cur_high_samples => 0,
    cur_low_samples  => 0,

    cpu   => Proc::CPUUsage->new,
    usage => undef,
    state => 1,
  }, $class;

  croak("Required parameter 'cb' not found, ") unless $self->{cb};

  $self->start;

  return $self;
}

sub start {
  my $self = shift;

  $self->{timer} = AnyEvent->timer(
    after    => $self->{interval},
    interval => $self->{interval},
    cb       => sub { $self->_check_cpu },
  );

  $self->{usage} = $self->{cpu}->usage;
  $self->reset_stats;  

  return;
}

sub stop { delete $_[0]->{timer} }

sub usage   { return $_[0]->{usage} }
sub is_low  { return $_[0]->{state} == 1 }
sub is_high { return $_[0]->{state} == 0 }

sub reset_stats {
  my ($self) = @_;
  
  $self->{usage_sum} = 0;
  $self->{usage_count} = 0;
}

sub stats {
  my ($self) = @_;
  my %stats;
  
  my ($count, $sum);
  if ($count = $self->{usage_count}) {
    $sum = $self->{usage_sum};
    $stats{usage_avg} = $sum/$count;
  }
  $stats{usage_count} = $count;
  $stats{usage_sum}   = $sum;
  $stats{usage}       = $self->{usage};

  return \%stats;
}

sub _check_cpu {
  my $self = $_[0];
  my $chs  = $self->{current_high_samples};
  my $cls  = $self->{current_low_samples};

  my $usage = $self->{usage} = $self->{cpu}->usage;
  if    ($usage > $self->{high}) { $chs++; $cls = 0 }
  elsif ($usage < $self->{low})  { $cls++; $chs = 0 }
  $self->{usage_sum} += $usage;
  $self->{usage_count}++;

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
