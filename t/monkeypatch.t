#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 8;

use FindBin ();
use File::Spec;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

# sieze control of CORE functions across all versions of Perl
{
  use universal::overridable qw(CORE::time);

  my $now = time();
  cmp_ok( $now, '==', CORE::time(), 'CORE::time is in effect' );

  {
    no warnings 'redefine';
    local *CORE::MONKEYPATCH::time = sub { 1 };
    cmp_ok( time(), '==', 1, 'monkeypatch time is in effect' );
  }

  cmp_ok( time(), '>=', $now, 'CORE::time is back in effect' );

  # {
  #   my $random_time = 4475;
  #   use universal::overridable +{
  #     'CORE::time' => sub { $random_time },
  #   };
  #   cmp_ok( time(), '==', $random_time, 'second monkeypatch time overlaid' );
  # }
}

# functions with an 'undef' prototype cannot be overridden, let's catch that
{
  my $me = File::Spec->join($FindBin::Bin, $FindBin::Script);

  {
    local $@;
    eval <<EVAL;
      use universal::overridable qw(CORE::map);
EVAL
    my $error = $@;

    like(
      $error,
      qr/CORE::map has no prototype so is not overridable, please rethink your approach at $me line \d+/,
      'We correctly inform the programmer about non-overridable functions'
     );
  }

  {
    my $return = 'markup-wormed';
    local $@;
    eval <<EVAL;
      BEGIN {
        sub sixth::bating { return "$return" }
        use universal::overridable qw(sixth::bating);
      }
EVAL
    my $error = $@;

    is( $error, '', 'no errors trying to override non-core functions without a prototype' );
    is( sixth->bating, $return, 'we get the proper return value' );

    {
      no warnings 'redefine';
      my $revised_return = 4548;
      local *sixth::MONKEYPATCH::bating = sub { $revised_return };
      is( sixth->bating, $revised_return, 'we can swap out the function' );
    }

    # This is really a test of the 'local' in 'local *sixth::MONKEYPATCH::bating = sub { ... }'
    # but it's reassuring to prove that this works like it should.
    is( sixth->bating, $return, 'original return value restored' );
  }
}
