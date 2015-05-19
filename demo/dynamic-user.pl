#!/usr/bin/env perl

use strict;
use warnings;

{
  package toy::class;

  sub dumper_class { 'Data::Dumper' }

  sub go {
    my ($class) = @_;

    use universal::dynamic_use;
    print $class->dynamic_use->dumper_class->Dump([qw(hello world)]);
  }
}

toy::class->go;
