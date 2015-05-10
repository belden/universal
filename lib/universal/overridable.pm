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

    use FindBin qw($Bin);
    use lib "$Bin/../lib";

    my $now = time;

    my $then = do {
      use universal::overridable qw(CORE::time);
      no warnings 'redefine';
      local *CORE::GLOBAL::time = sub () { 19490201 };
      time;
    };

    my $later = time;

    print <<PRINT
    now:   $now (${\scalar localtime($now)})
    then:    $then (${\scalar localtime($then)})
    later: $later (pretty close to $now)
    PRINT

    __END__
    now:   1431025089 (Thu May  7 18:58:09 2015)
    then:    19490201 (Fri Aug 14 13:56:41 1970)
    later: 1431025089 (pretty close to 1431025089)

=head1 DESCRIPTION

This is my attempt to make a single pattern for making targetable code that can be monkeypatched ad nauseum.
Monkeypatching is used to varying extents within most large applications' test suites; and it is used on
occasion in one-off scripts and actual long-running application code.

There are two types of functions that the Perl developer may wish to monkeypatch:

1. Regular functions implemented in perl by other module developers;
2. CORE functions provided by the perl language itself.

Various techniques already exist for solving the first problem. The second problem, however, has a few
not-so-obvious pitfalls which this module attempts to alleviate.

=head1 REGULAR CORE:: MONKEYPATCHING

Here is a script that siezes control of the clock, as seen by perl:

     1	#!/usr/bin/env perl
     2	use strict;
     3	use warnings;
     4
     5	use Test::More tests => 2;
     6
     7	use My::Application::Model::SomeModel;
     8
     9	BEGIN {
    10	  *CORE::GLOBAL::time = sub { 12345 };
    11	}
    12
    13	cmp_ok( time(), '==', 12345, 'fake time in effect' );
    14
    15	no warnings 'redefine';
    16	*CORE::GLOBAL::time = sub { 678910 };
    17	cmp_ok( time(), '==', 678910, 'revised fake time in effect' );
    18	__END__

On perl 5.10.1, the above script yields this output:

    ok 1 - fake time in effect
    ok 2 - revised fake time in effect

