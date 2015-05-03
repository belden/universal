#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 9;

use FindBin ();
use lib "$FindBin::Bin/../lib";

{
  package DynamicUser;

  sub dumper_class { 'Data::Dumper' }
  sub dump_it {
    my $class = shift;
    use universal::dynamic_use;
    return $class->dynamic_use->dumper_class->Dump(\@_);
  }
}

# basic usage
{

  my $dump = eval {
    DynamicUser->dump_it('hello');
  };
  is( $@, '', 'no exceptions' );
  like( $dump, qr/\$VAR1 .* = .* 'hello'/x, 'We got a data::dumper output' );
}

# pragmatic behavior
{
  local $@;
  my $ok = eval {
    use universal::dynamic_use;
    DynamicUser->dynamic_use->dumper_class->Dump([1]);
  };
  is( $@, '', 'no exception' );
  like( $ok, qr/\$VAR1 .* = .* 1/x, 'got expected output' );

  local $@;
  my $not_set_up_yet = eval<<'EVAL';
#line 19490201
    DynamicUser->dynamic_use->dumper_class->Dump([2]);
EVAL
  like( $@, qr/Can't locate object method "dynamic_use" via package "DynamicUser" at .* line 19490201/, 'got expected error' );
  is( $not_set_up_yet, undef, 'no unexpected output' );

  local $@;
  my $unimported = eval<<'EVAL';
    use universal::dynamic_use;
    my $ok = DynamicUser->dynamic_use->dumper_class->Dump([3]);
    like( $ok, qr/\$VAR1 .* = .* 3/x, 'first call succeeds' );

    no universal::dynamic_use;
#line 19490201
    DynamicUser->dynamic_use->dumper_class->Dump([4]);
EVAL
  like( $@, qr/Can't locate object method "dynamic_use" via package "DynamicUser" at .* line 19490201/, 'got expected error after unimport' );
  is( $unimported, undef, 'no unexpected output' );
}
