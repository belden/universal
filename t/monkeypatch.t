#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 3;

use FindBin ();
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
