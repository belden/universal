package universal::dynamic_use;
use strict;
use warnings;

require Carp;

sub import { $^H{dynamic_use} = 1 }
sub unimport { $^H{dynamic_use} = 0 }

sub UNIVERSAL::dynamic_use {
  my ($orig_class, @imports) = @_;

  my ($callpack, $hints) = (caller(0))[0,10];
  Carp::croak(qq{Can't locate object method "dynamic_use" via package "$orig_class"}) unless $hints->{dynamic_use};
  $orig_class = $callpack if ! $orig_class || $orig_class eq 'UNIVERSAL';

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

=head1 NAME

universal::dynamic_use - pattern for runtime loading of code

=head1 SYNOPSIS

    package Some::Class;

    sub user_agent_class { 'LWP::UserAgent' }

    sub fetch_url {
        my ($class, @args) = @_;

        use universal::dynamic_use;
        my $ua = $class->dynamic_use->user_agent_class->new(@args);

        ...
    }

=head1 DESCRIPTION

C<universal::dynamic_use> adds a pragmatically available method, L<UNIVERSAL::dynamic_use>, which
will treat the next method call as returning the name of a module which needs to be loaded at
runtime.

You may use `universal::dynamic_use` in two fashions. The simplest fashion is for interacting with
classes that have a class- or object-oriented interface.

Here are two classes that have circular uselines:

    {
      package Ouroborus::Head;
      use strict;
      use warnings;

      use Ouroborus::Tail;

      sub eat {
        my ($class) = @_;
        return Ouroborus::Tail->new;
      }

      1;
    }

    {
      package Ouroborus::Tail;
      use strict;
      use warnings;

      use Ouroborus::Head;

      sub be_eaten {
        my ($class) = @_;
        return Ouroborus::Head->new->eat;
      }

      1;
    }

Attempting to use either of these two classes results in a warning:

    $ perl -Mstrict -Mwarnings -wc Ouroborus/Head.pm
    Subroutine eat redefined at Ouroborus/Head.pm line 7.
    Ouroborus/Head.pm syntax OK

In this case, the circular use is of negligible impact, because there is no compile-time code that runs
in either package. In larger systems, circular uselines lead to convolutions whereby developers learn
through painful experience that one module must be loaded before another.

Here's how to write the above two classes in a way that does not have a circular use issue, which in turn
allows compile-time code to run just once:


    {
      package Ouroborus::Head;
      use strict;
      use warnings;

      sub tail_class { 'Ouroborus::Tail' }

      sub eat {
        my ($class) = @_;
        use universal::dynamic_use;
        return $class->dynamic_use->tail_class->new;
      }

      1;
    }

If you prefer to C<use universal::dynamic_use> alongside your more typical pragmas, you may do
that too.

    {
      package Ouroborus::Tail;
      use strict;
      use warnings;
      use universal::dynamic_use;

      use Ouroborus::Head;

      sub head_class { 'Ouroborus::Head' }

      sub be_eaten {
        my ($class) = @_;
        return UNIVERSAL->dynamic_use->head_class->new->eat;
      }

      1;
    }

=head1 RUNTIME LOADING OF CLASSES

Once C<universal::dynamic_use> is loaded, you may access C<-I<gt>dynamic_use> in any number of ways. Any
object or class will have a C<dynamic_use> method available to it. If you do not have an object or class
to invoke C<dynamic_use> on, you may invoke any of C<__PACKAGE__-I<gt>dynamic_use>, C<UNIVERSAL-I<gt>dynamic_use>,
or C<UNIVERSAL::dynamic_use>.

=head1 RUNTIME IMPORTING OF FUNCTIONS

This part is a bit hairy.

=head1 AUTHOR

(c) 2015 Belden Lyman <belden@cpan.org>

=head1 LICENSE

As Perl.
