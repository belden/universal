use strict;
use warnings;
package SimpleExporter;
use base qw(Exporter);

our @EXPORT = qw(default_export default_with_block_prototype);
our @EXPORT_OK = qw(optional_export optional_with_block_prototype);

my $unique = sub { my %s; return grep { ! $s{$_}++ } @_ };
our %EXPORT_TAGS = (all => [$unique->(@EXPORT, @EXPORT_OK)]);

sub default_export { return 'default_export output' }
sub optional_export { return 'optional_export output' }
sub default_with_block_prototype(&@) { my $code = shift; return map { $code->() } @_ }
sub optional_with_block_prototype(&@) { my $code = shift; return map { $code->() } @_ }

1;
