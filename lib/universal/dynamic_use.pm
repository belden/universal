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

  my ($callpack, $hints) = (caller(0))[0,10];
  Carp::croak(qq{Can't locate object method "dynamic_use" via package "$orig_class"}) unless $hints->{dynamic_use};

  if ($orig_class eq 'UNIVERSAL') {
    $orig_class = $callpack;
  }

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

sub unzip(&@) {
  my $code = shift;
  my ($l, $r) = ([], []);
  foreach (@_) {
    push @{$code->() ? $l : $r}, $_;
  }
  return ($l, $r);
}

sub set_up_prototypes_for_caller {
  my ($class, $callpack, $args) = @_;

  my ($known, $unknown) =
    unzip { m{\w+::[\w:]+\([^)]+\)} }
    @$args;

  push @$known, $class->guess_prototypes($callpack, $unknown) if @$unknown;

  my @to_eval;
  foreach my $forward_declaration (@$known) {
    my ($sub, $proto) = $forward_declaration =~ m{^.*: (\w+) \( ([^\)]+) \)$}x;
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

sub guess_prototypes {
  my ($class, $callpack, $args) = @_;

  die "Cowardly refusing to continue until you set I_AM_BANANA_PANTS_INSANE to some value\n"
    if ! exists $ENV{I_AM_BANANA_PANTS_INSANE};

  my $example_prototype = $class->prototype_for_function($args->[0]);
  my ($provider) = $args->[0] =~ m{^(.*)::\w+};

  my $tidy = map { "    $_" } join "\n", @$args;

  die <<INSANE if $ENV{I_AM_BANANA_PANTS_INSANE} ne 'and there is no backing out now';
I see you're insane! welcome, we need more programmers like you. But before you activate this
section of code: I bet you already know the prototypes of the functions you want to import:

$tidy

You can specify the prototypes in your 'use' line; for example, if you were trying to say:

    use dynamic_use qw{Hash::MostUtils::hashmap};

then you could instead say

    use universal::dynamic_use qw{Hash::MostUtils::hashmap(&@)};

to indicate that Hash::MostUtils::hashmap has a $@ prototype to it.

On the other hand, if you really want to proceed with letting me figure out your functions'
prototypes, then you need to set

  I_AM_BANANA_PANTS_INSANE='and there is no backing out now'

As a quick gut check: your program presumably hasn't loaded $provider yet, but somehow this
module has already figured out the prototype for $args->[0] to be $example_prototype. How do
you think we achieved that? THROUGH INSANITY, FRIEND. THROUGH INSANITY.

INSANE

  # okay, you asked for it
  my @prototypes = map { $class->prototype_for_function($_) } @$args;
  my @out;
  foreach my $sub (@$args) {
    my $proto = shift @prototypes;
    push @out, "$sub($proto)";
  }

  return @out;
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
    while (my $line = <$fh>) {
      if ($line =~ /^ \s* sub \s+ (?:$module\::)? $function_name \s* \( ([^)]+) \)/x) {
        # This is how normal people write prototyped functions:
        # sub foo (&@) { ... }  -> '&@'
        $prototype = $1;
        last;
      } elsif ($line =~ /^ \s* \* (?:$module\::)? $function_name \s* = \s* sub \s* \(([^)]+)\)/x) {
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

=head1 NAME

universal::dynamic_use - compile-time predeclaration of runtime-imported subroutines

=head1 SYNOPSIS

    package Your::Module;

    sub dump_something {
      my ($class, $thing) = @_;

      use universal::dynamic_use;
      return $class->dynamic_use->dumper_class->Dump($thing);
    }

    sub dumper_class { 'Data::Dumper' }

=head1 DESCRIPTION

C<universal::dynamic_use> provides a pattern for runtime-loading of modules into your application. Modules which
provide an object-oriented interface or a class interface may be easily changed to load at runtime; rather than
writing something like this:

    package Your::Application::Model::Foo;

    use Your::Application::Model::Bar;  # which might, in turn, 'use Your::Application::Model::Foo' - a circle, yikes

    sub do_stuff {
        my ($class, @args) = @_;

        my $bar = Your::Application::Model::Bar->new(...);

        $bar->...

    }

You can instead write this:

    package Your::Application::Model::Foo;

    sub bar_class { 'Your::Application::Model::Bar' }

    sub do_stuff {
        my ($class, @args) = @_;

        use universal::dynamic_use;
        my $bar = $class->dynamic_use->bar_class->new(...);

        $bar->...

    }

C<universal::dynamic_use> can also be used to import functions from other classes at runtime. In particular, this
module handles runtime loading of functions with BLOCK prototypes on them.

This contrived code does not perform as you would expect:

    sub contains_even_numbers {
        eval "use List::MoreUtils qw(any)";
        return any { $_ % 2 == 0 } @_;
    }

At compile-time, perl does not know that `any` has the C<&@> prototype, so sets up an optree to reflect that
`any` will receive a hash reference as a first argument. Unfortunately, using the techniques specified in
L<perlref> to disambiguate that we intend a code block, and not a hash reference, do not work here:

    sub contains_even_numbers {
        eval "use List::MoreUtils qw(any)";
        return any {; $_ % 2 == 0 } @_;
    }

One way to solve this problem is to predeclare `any` to have the proper prototype:

    sub any (&@);

    sub contains_even_numbers {
        eval "use List::MoreUtils qw(any)";
        return any { $_ % 2 == 0 } @_;
    }

Another way is to use C<universal::dynamic_use> to predeclare your signatures:

    sub contains_even_numbers {
        use universal::dynamic_use qw{List::MoreUtils::any(&@)};
        return any { $_ % 2 == 0 } @_;
    }

If you don't want to provide a hint C<universal::dynamic_use> as to what signature you expect, you can
ask C<universal::dymamic_use> to figure the prototype out for you:

    sub contains_even_numbers {
        BEGIN { $ENV{I_AM_BANANA_PANTS_INSANE} = 1 }
        use universal::dynamic_use qw(List::MoreUtils::any);

        return any { $_ % 2 == 0 } @_;
    }

You absolutely must be banana-pants insane to ever want to use this section of code.

=head1 AUTHOR

Belden Lyman <belden@cpan.org>

