#!/usr/bin/env perl

use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/../lib";

use Test::More tests => 11;

{
  package MixedInterface;

  sub helper_function {
    my ($x, $y, $z) = @_;

    return ($x + $y) * $z;
  }

  sub existing_class_method {
    my ($class, %args) = @_;

    my $out = helper_function($args{x}, $args{y}, $args{z});
    return 100_000 + $out;
  }

  sub revised_class_method {
    my ($class, %args) = @_;

    use universal::func;
    my $out = $class->func->helper_function($args{x}, $args{y}, $args{z});
    return 200_000 + $out;
  }

  sub stacktrace {
    my @call_stack;

    my $lookback = 0;
    while (my @frame = caller($lookback++)) {
      push @call_stack, \@frame;
    }

    return @call_stack;
  }
}

# UNIVERSAL::func turns the next chained method call into a function call
{
  is( MixedInterface::helper_function(2, 5, 9), 63, 'sanity: helper_function()' );
  is( MixedInterface->existing_class_method(x => 2, y => 5, z => 9), 100_063, 'sanity: ->existing_class_method' );
  is( MixedInterface->revised_class_method(x => 2, y => 5, z => 9), 200_063, '$class->func->$method chains properly' );
}

# UNIVERSAL::func doesn't expose its inner workings in its call stack
{
  # the anonymous sub is here to force an extra call frame
  my @exp = sub { MixedInterface::stacktrace }->();
  my @got = sub { use universal::func; MixedInterface->func->stacktrace } ->();

  # strip out some elements of the call frames that we know will differ: line number, 'is require'
  is( scalar @got, scalar @exp, 'no extra call frames in strack trace' );
}

# UNIVERSAL::func acts pragmatically: you've got to opt in to its behavior
{
  my $yes = eval {
    use universal::func;
    MixedInterface->func->helper_function(2, 3, 5);
  };
  is( $@, '', 'no exception' );
  is( $yes, 25, 'we can use universal::func wherever seems fit' );

  # use 'eval STRING' rather than 'eval BLOCK' - though both let us play with line numbering
  # to have a deterministic error message, the latter treats line numbers as persisting forward
  # from our fixed fake number; the former resets them.
  my $not_set_up = eval<<'EVAL';
#line 19490201
    MixedInterface->func->helper_function(3, 4, 6);
EVAL
  like( $@, qr/Can't locate object method "func" via package "MixedInterface" at .* line 19490201/, 'got expected error' );
  is( undef, $not_set_up, 'sanity check: code really did die' );

  my $turned_off = eval<<'EVAL';
    use universal::func;
    my $five = MixedInterface->func->helper_function(2, 3, 1);
    is( $five, 5, 'first call lived' );
    no universal::func;
#line 19490201
    MixedInterface->func->helper_function($five, $five, $five);
EVAL
  like( $@, qr/Can't locate object method "func" via package "MixedInterface" at .* line 19490201/, 'got expected error' );
  is( undef, $turned_off, 'this exception is virtually indistinguishable from the previous one' );
}
