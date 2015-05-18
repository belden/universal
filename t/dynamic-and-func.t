#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 1;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

{
  package yo::gabba::gabba;

  sub gab_class { 'Data::Dumper' }

  sub dump_it {
    use universal::dynamic_use;
    return UNIVERSAL->dynamic_use->gab_class->Dump(@_);
  }
}

use universal::func;
my $dump = yo::gabba::gabba->func->dump_it([[1..4]], ['$dump']);
eval $dump;

is_deeply( $dump, [1..4], 'universal::func and universal::dynamic_use play nicely together' );
