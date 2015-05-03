#!/usr/bin/env perl

use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/../lib";

use Test::More tests => 3;

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
}

# UNIVERSAL::func turns the next chained method call into a function call
{
  is( MixedInterface::helper_function(2, 5, 9), 63, 'sanity: helper_function()' );
  is( MixedInterface->existing_class_method(x => 2, y => 5, z => 9), 100_063, 'sanity: ->existing_class_method' );
  is( MixedInterface->revised_class_method(x => 2, y => 5, z => 9), 200_063, '$class->func->$method chains properly' );
}
