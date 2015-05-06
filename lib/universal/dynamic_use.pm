package universal::dynamic_use;
use strict;
use warnings;

use Carp ();
use File::Spec ();

sub import {
  my ($class, @args) = @_;
  $^H{dynamic_use} = 1;

  if (@args) {
    my ($callpack) = (caller(0))[0];
    $class->set_up_prototypes_for_caller($callpack, \@args);
  }
}

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

sub set_up_prototypes_for_caller {
  my ($class, $callpack, $args) = @_;

  my @tidy = map { my $c = $_; $c =~ s{^.*:}{}; $c } @$args;
  die "Cowardly refusing to continue until you set I_AM_BANANA_PANTS_INSANE to some value\n"
    if ! exists $ENV{I_AM_BANANA_PANTS_INSANE};

  my $example_prototype = $class->prototype_for_function($args->[0]);
  my ($provider) = $args->[0] =~ m{^(.*)::\w+};

  die <<INSANE if $ENV{I_AM_BANANA_PANTS_INSANE} ne 'and there is no backing out now';
I see you're insane! welcome, we need more programmers like you. But before you activate this
section of code: have you considered a simple forward declaration of '@tidy'
within $callpack to have the prototypes that you know you need?

For example, since $args->[0] has the prototype $example_prototype, you can simply write

  package $callpack;

  sub $tidy[0] ($example_prototype);  # forward declaration of BLOCK-prototyped function

and later you can go ahead and `universal::dynamic_use` that function into $callpack.

On the other hand, if you really want to proceed, then you need to set

  I_AM_BANANA_PANTS_INSANE='and there is no backing out now'

As a quick gut check: your program presumably hasn't loaded $provider yet, but somehow this
module has already figured out the prototype for $args->[0] to be $example_prototype. How do
you think we achieved that? THROUGH INSANITY, FRIEND. THROUGH INSANITY.

INSANE

  # okay, you asked for it
  my @prototypes = map { $class->prototype_for_function($_) } @$args;
  my @to_eval;
  foreach my $sub (@tidy) {
    my $proto = shift(@prototypes);
    push @to_eval, "sub $sub ($proto);";
  }
  my $to_eval = sprintf <<EVAL, $callpack, join("\n", @to_eval);
package %s;
%s;
EVAL
  local $@;
  eval $to_eval;
  die $@ if $@;
}

sub prototype_for_function {
  my ($class, $function) = @_;

  my ($module, $function_name) = $function =~ m{^(.*)::(\w+)$};
  my $putative_file_name = File::Spec->join(split /::/, $module);

  my $prototype;

  my ($found) =
    grep { -f $_ }
    map { File::Spec->join($_, "$putative_file_name.pm") }
    @INC;

  if ($found && open(my $fh, '<', $found)) {
    while (<$fh>) {
      if (/^ \s* sub \s+ (?:$module\::)? $function_name \s* \( ([^)]+) \)/x) {
        # This is how normal people write prototyped functions:
        # sub foo (&@) { ... }  -> '&@'
        $prototype = $1;
        last;
      } elsif (/^ \s* \* (?:$module\::)? $function_name \s* = \s* sub \s* \(([^)]+)\)/x) {
        # I did typeglob assignment of a prototyped subref in Hash::MostUtils:
        # *foo = sub (&@) { ... } -> '&@'
        $prototype = $1;
        last;
      }
    }
    close $fh;
  } else  {
    chomp($prototype = `$^X -le 'require $module; print CORE::prototype(q,$function,)'`);
  }

  return $prototype;
}

1;

__END__

