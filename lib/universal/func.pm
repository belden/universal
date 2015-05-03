package universal::func;
use strict;
use warnings;

use Carp ();

sub import { $^H{'universal::func'} = 1 }
sub unimport { $^H{'universal::func'} = 0 }

sub UNIVERSAL::func {
  my $orig_class = shift;

  my ($hints) = (caller(0))[10];
  if (! $hints->{'universal::func'}) {
    Carp::croak(qq{Can't locate object method "func" via package "$orig_class"});
  }

  my $function_dispatcher = "$orig_class\::function_dispatcher";
  (my $putative_file_name = $function_dispatcher) =~ s{::}{/}g; # assumes '/' is your OS's path separator

  if (! $INC{$function_dispatcher}++) {
    local $@;
    eval <<EVAL;
package $function_dispatcher;

sub AUTOLOAD {
  my \$class = shift;

  my (\$method) = our \$AUTOLOAD =~ m{^.*:(.+)};

  my \$target_class = '$orig_class';
  my \$subref = UNIVERSAL::can(\$target_class, \$method);

  if (! defined \$subref) {
    require Carp;
    Carp::croak("Undefined subroutine &\$target_class\::\$method");
  }

  goto &\$subref;
}
EVAL
    die $@ if $@;
  }
  return $function_dispatcher;
}

1;
