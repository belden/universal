use strict;
use warnings;
package SimpleExporter;
use base qw(Exporter);

our @EXPORT = qw(default_export);
our @EXPORT_OK = qw(optional_export);

my $unique = sub { my %s; return grep { ! $s{$_}++ } @_ };
our %EXPORT_TAGS = (all => [$unique->(@EXPORT, @EXPORT_OK)]);

sub default_export { return 'default_export output' }
sub optional_export { return 'optional_export output' }

1;
