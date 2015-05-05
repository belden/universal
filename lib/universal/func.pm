package universal::func;
use strict;
use warnings;

use Carp ();
use File::Spec ();

sub import {
  my ($class, @args) = @_;

  if (@args) {
    my ($call_pack) = (caller(0))[0];
    $class->set_up_invisible_method_calls(for => $call_pack, with => \@args);
    $^H{'universal::func'} = $class->freeze(map { ($_ => 1) } @args);
  } else {
    $^H{'universal::func'} = 1;
  }
}

sub unimport {
  my ($class, @args) = @_;

  if (@args) {
    my ($call_pack, $hints) = (caller(0))[0,10];
    my %h = $class->thaw($hints->{'universal::func'});
    delete @h{@args};
    $^H{'universal::func'} = $class->freeze(%h);
  } else {
    $^H{'universal::func'} = 0;
  }
}

# This gets used in the simple case:
#
#    use universal::func;
#    FooClass->func->this_looks_like_a_method_call_but_is_a_function_call(@args);
#
sub UNIVERSAL::func {
  my $orig_class = shift;

  my ($hints) = (caller(0))[10];
  if (! $hints->{'universal::func'}) {
    Carp::croak(qq{Can't locate object method "func" via package "$orig_class"});
  }

  my $function_dispatcher = "$orig_class\::function_dispatcher";
  my $putative_file_name = File::Spec->join(split /::/, $function_dispatcher);

  if (! $INC{"$putative_file_name.pm"}++) {
    local $@;
    my $to_eval = <<EVAL;
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
eval $to_eval;
    die $@ if $@;
  }
  return $function_dispatcher;
}

# Everything below here gets used in the saccharine case:
#
#   use universal::func qw(FooClass::this_looks_like_a_method_call_but_is_a_function_call);
#   FooClass->this_looks_like_a_method_call_but_is_a_function_call(@args);
#
sub freeze {
  my ($class, %hash) = @_;
  my @out;
  while (my ($k, $v) = each %hash) {
    push @out, "$k=$v";
  }
  return join ';', @out;
}

sub thaw {
  my ($class, $hints) = @_;
  return map { (split /=/, $_) } split /;/, $hints;
}

sub is_active {
  my ($class, $sub, $hints) = @_;
  return 0 unless exists $hints->{'universal::func'};
  return $hints->{'universal::func'} =~ /=/
    ? +{$class->thaw($hints->{'universal::func'})}->{$sub}
    : $class->{'universal::func'};
}

sub set_up_invisible_method_calls {
  my ($class, %args) = @_;

  foreach my $wrap (@{$args{with}}) {
    no strict 'refs';
    no warnings 'redefine';

    my $orig = \&{"$wrap"};

    # I didn't write a test for this condition, boo me
    die "You wanted me to wrap $wrap but I couldn't find it" if ! $orig;

    my ($provider) = $wrap =~ m{^(.*)::};

    # this here is the so-called 'invisible wrapper'
    *{$wrap} = sub { # xxx kills prototype
      my $hints = (caller(0))[10];
      shift if                               # Discard 0th argument (the invocant) if:
        UNIVERSAL::isa($_[0], $provider)     #   - you've got a class or object invocant
        && $class->is_active($wrap, $hints); #   - and you've told me to discard invocants

      goto &$orig;
    };
  }
}

1;

__END__

=head1 NAME

universal::func - turn things that look like method calls into function calls

=head1 SYNOPSIS

Transparently call functions as methods:

    #!/usr/bin/env perl
    use strict;
    use warnings;

    sub SomeClass::do_it { print "$_\n" foreach @_ }

    use universal::func qw(SomeClass::do_it);
    SomeClass->do_it(1..5);

    __END__
    1          # surprise, $_[0] is not 'SomeClass'
    2
    3
    4
    5

Less invasive syntax:

    #!/usr/bin/env perl
    use strict;
    use warnings;

    sub SomeClass::do_it { print "$_\n" foreach @_ }

    use universal::func;
    SomeClass->func->do_it(1..5);     # the universal method '->func' removes SomeClass as the invocant

    __END__
    1           # note, $_[0] is not 'SomeClass'
    2
    3
    4
    5

=head1 DESCRIPTION

Sometimes within a large system you have classes that have both a procedural and a class/object
interface to them:

    {
      package MixedInterface;
      use strict;
      use warnings;
      use base qw(Exporter);

      our @EXPORT = qw(helper_function);

      sub do_something {
        my ($class, %args) = @_;

        my $val = helper_function($args{x}, $args{y}, $args{z});
        return $val + 1_000;
      }

      sub helper_function {
        my ($x, $y, $z) = @_;
        return ($x + $y) * $z;
      }

      1;
    }

At some point you may decide that you'd like MixedInterface->do_something(...) to write
your call to MixedInterface::helper_function as a class method rather than a function:

    @@ -9,7 +9,7 @@
       sub do_something {
         my ($class, %args) = @_;

    -    my $val = helper_function($args{x}, $args{y}, $args{z});
    +    my $val = $class->helper_function($args{x}, $args{y}, $args{z});
         return $val + 1_000;
       }

However, you may subsequently discover that `helper_function` is imported widely through
your application, and you wish to minimize the scope of your change. (Perhaps you do not
want to create unnecessary merge conflicts for other developers on your project.)

One option is to abandon your efforts to clean up the class's interface. Another is to
decide that the merge conflicts, though painful, serve the greater good of reconciling
the interface. Yet another option is to `use universal::func` in your original class,
which allows you to write the code you want without breaking the code you have:

    @@ -9,7 +9,9 @@
       sub do_something {
         my ($class, %args) = @_;

    -    my $val = helper_function($args{x}, $args{y}, $args{z});
    +    use universal::func;
    +    my $val = $class->func->helper_function($args{x}, $args{y}, $args{z});
    +
         return $val + 1_000;
       }

By importing `universal::func`, you load `UNIVERSAL::func`; now all classes and objects
can `->func`. The implementation of `->func` is such that the next chained method call
will be treated as a function call.

The final revised code within your system now looks like this:

    {
      package MixedInterface;
      use strict;
      use warnings;
      use base qw(Exporter);

      our @EXPORT = qw(helper_function);

      sub do_something {
        my ($class, %args) = @_;

        use universal::func;
        my $val = $class->func->helper_function($args{x}, $args{y}, $args{z});

        return $val + 1_000;
      }

      sub helper_function {
        my ($x, $y, $z) = @_;
        return ($x + $y) * $z;
      }

      1;
    }

There is nothing to say that this needs to only be used within a class. Without changing the
implementation of `MixedInterface->do_something` from its original, we might approach this
same problem from the perspective of the consuming code:

    {
      package Application;
      use strict;
      use warnings;

      use MixedInterface qw(helper_function);

      sub mega_math {
        my $x = helper_function(1, 2, 3);
        my $y = helper_function(2, 3, 4);
        my $z = helper_function(3, 4, 5);

        MixedInterface->do_something(x => $x, y => $y, z => $z);
      }
    }

If we wanted to sprinkle arrows all around, then we can write the above as:

    {
      package Application;
      use strict;
      use warnings;

      use MixedInterface (); # import nothing

      sub mega_math {
        use universal::func;

        my $x = MixedInterface->func->helper_function(1, 2, 3);
        my $y = MixedInterface->func->helper_function(2, 3, 4);
        my $z = MixedInterface->func->helper_function(3, 4, 5);

        MixedInterface->do_something(x => $x, y => $y, z => $z);
      }
    }

=head1 CHOOSING BETWEEN FORMS

This module presents two slightly different interfaces. Though they look similar, they act quite
different under the hood.

For a simple system, you may like to use the pragmatic-looking syntax:

    use universal::func qw(TargetClass::target_function);

    TargetClass->target_function;   # 'TargetClass' will not be $_[0], despite what your eyes tell you

The preceding `use` line does a little symbol table skulduggery: it locates TargetClass::target_function
and swaps it out for a wrapper function which will disregard the zero'th argument (aka "the invocant")
if (a) it looks like it is an invocant; and (b) you have a 'use universal::func' currently active for
the called function.

While this looks nice, and preserves the illusion that a given function is offered as a class method,
this form of using `universal::func` has a drawback: it involves replacing targeted functions in various
symbol tables. This will not play nicely with prototyped functions; nor will it handle unwrapping functions
that have 'around/before/after' advice applied to them via Moose.

A more explicit and less invasive form of this module can be used:

    use universal::func;

    TargetClass->func->target_function;  # 'TargetClass' will not be the object returned by '->func'

=head1 AUTHOR

Belden Lyman (belden@cpan.org)
