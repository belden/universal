package universal::overridable;
use strict;
use warnings;

use Carp ();

sub import {
  my ($class, @funcs) = @_;
  $class->make_global_stubs(@funcs);
}

sub make_global_stubs {
  my ($class, @funcs) = @_;

  $class->make_global_stub($_) foreach @funcs;
}

sub make_global_stub {
  my ($class, $func) = @_;

  my ($package, $sub) = $func =~ m{^(.*)::(\w+)$};
  my $proto = CORE::prototype($func);
  if (! defined($proto) && $package eq 'CORE') {
    $class->confess_from_perspective_of_using_module("$func has no prototype so is not overridable, please rethink your approach");
  }

  my ($prototype, $pass_args) = $proto
    ? ("($proto)", (defined $proto ? '\@_' : ''))
    : ("", '');

  if ($package eq 'CORE') {
    eval <<"    EVAL";
      sub CORE::MONKEYPATCH::$sub $prototype { return CORE::$sub($pass_args) }
      *CORE::GLOBAL::$sub = sub $prototype { goto &CORE::MONKEYPATCH::$sub };
    EVAL
    die $@ if $@;
  } else {
    my $o = do {
      no strict 'refs';
      *{${"$package\::"}{$sub}}{CODE};
    };
    eval <<"    EVAL";
      no warnings 'redefine';
      *$package\::MONKEYPATCH::$sub = \$o;
      *$package\::$sub = sub $prototype { goto &$package\::MONKEYPATCH::$sub };
    EVAL
    die $@ if $@;
  }
}

sub confess_from_perspective_of_using_module {
  my ($class, $message) = @_;

  # Run back up the stack to a point where someone is trying to 'use' us.
  # (Unfortunately setting @CARP_NOT didn't help here, since some frames we need to
  # ignore are 'eval' frames, but the one we're looking for is also an 'eval'

  my $lookback = 0;
  while (my @frame = caller($lookback++)) {
    next if ! defined $frame[6];
    last if $frame[6] =~ /$class/;
  }
  local $Carp::CarpLevel = $lookback;

  Carp::confess($message);
}

1;

__END__

=head1 NAME

universal::overridable - make CORE functions universally overridable across all Perl versions

=head1 SYNOPSIS

    #!/usr/bin/env perl

    use strict;
    use warnings;

    my $now = time;

    my $then = do {
      use universal::overridable qw(CORE::time);
      no warnings 'redefine';
      local *CORE::GLOBAL::time = sub () { 19490201 };
      time;
    };

    my $later = time;

    my $subsequently = do {
      use universal::overridable +{
        'CORE::time' => sub { 9770 },
      };

      time;
    };

    my $again = time;

    print <<PRINT
    now: $now
    then: $then
    later: $later (pretty close to $now)
    subsequently: $subsequently (a long time ago)
    again: $again
    PRINT

    __END__
