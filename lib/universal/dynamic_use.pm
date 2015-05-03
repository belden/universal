package universal::dynamic_use;
use strict;
use warnings;

require Carp;

sub import { $^H{dynamic_use} = 1 }
sub unimport { $^H{dynamic_use} = 0 }

sub UNIVERSAL::dynamic_use {
  my ($orig_class, @imports) = @_;

  my ($hints) = (caller(0))[10];
  Carp::croak(qq{Can't locate object method "dynamic_use" via package "$orig_class"}) unless $hints->{dynamic_use};

  my $dynamic_user = "$orig_class\::dynamic_user";
  (my $nominal_file_name = $dynamic_user) =~ s{::}{/}g;
  if (! $INC{"$nominal_file_name.pm"}++) {
    local $@;
    eval <<EVAL;

      package $dynamic_user;
      use strict;
      use warnings;
      
      sub AUTOLOAD {
        my \$class = shift;
        my (\$method) = our \$AUTOLOAD =~ m{^.*:(.+)};
        my \$module = '$orig_class'->\$method;

        local \$@;
        eval <<INNER_EVAL;
          package $orig_class;
          use \$module;
INNER_EVAL
        die \$@ if \$@;
        return \$module;
      }
      
      1;

EVAL
    die $@ if $@;
  }

  return $dynamic_user;
}

1;

__END__

