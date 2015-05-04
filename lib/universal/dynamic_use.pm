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

  my $use_it_up_format = "package $orig_class; use %s" . (@imports
    ? sprintf(' qw(%s)', join(' ', @imports))
    : ''
  );

  my $to_eval = <<EVAL;

    package $dynamic_user;
    no strict;
    no warnings;

    sub AUTOLOAD {
      my \$class = shift;
      my (\$method) = our \$AUTOLOAD =~ m{^.*:(.+)};
      my \$module = $orig_class->\$method;

      local \$@;
      eval sprintf('$use_it_up_format', \$module);
      die \$@ if \$@;
      return \$module;
    }

    1;

EVAL

  local $@;
  eval $to_eval;
  die $@ if $@;

  return $dynamic_user;
}

1;

__END__

