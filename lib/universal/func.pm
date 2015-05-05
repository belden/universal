package universal::func;
use strict;
use warnings;

use Carp ();
use File::Spec ();

sub import { $^H{'universal::func'} = 1 }
sub unimport { $^H{'universal::func'} = 0 }

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

__END__

=head1 NAME

universal::func - add a UNIVERSAL method to turn the next method call into a function call

=head1 SYNOPSIS

    sub foo {
      use universal::func;
      SomeClass->func->this_gets_called_as_a_function_not_a_method(1..5);
    }

    sub SomeClass::this_gets_called_as_a_function_not_a_method { print "$_\n" foreach @_ }

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

The final revised code within your system, now looks like this:

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

=head1 AUTHOR

Belden Lyman (belden@cpan.org)
