#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

{
    package Foo;

    sub dumper_class { 'Data::Dumper' }

    sub dump_it {
        my (@args) = @_;

        use universal::dynamic_use;
        print UNIVERSAL->dynamic_use->dumper_class->Dump(\@args);
    }
}


{
    use universal::func;

    Foo->func->dump_it([1..5]);
}

__END__
$VAR1 = [
          1,
          2,
          3,
          4,
          5
        ];
