use strict;
use warnings;
package universal::autochain;

our $VERSION = 0.0.01;

sub import { $^H{autochain} = 1 }
sub unimport { $^H{autochain} = 0 }

my %autochained;

sub build_dispatcher_class {
  my ($class, $target) = @_;

  my $target_class = ref($target) || $target;

  if (! $autochained{$target_class}) {
    my $finder = 'autochain::' . $target_class;
    my $code = <<EVAL;
      use strict;
      use warnings;
      package $finder;

      use overload (
        '""' => \\&lastval,
        '0+' => \\&lastval,
        'bool' => \\&lastval,
        fallback => 1,
      );

      sub lastval {
        my \$s = shift;
        return wantarray ? \@\$s : \$s->[0];
      }

      sub DESTROY {}
      sub AUTOLOAD {
        my \$s = shift;
        my \$c = ref(\$s) || \$s;
        my (\$t) = \$c =~ m{autochain::(.+)\$};
        my (\$m) = our \$AUTOLOAD =~ m{.*:(.+)\$};
        my \$l = \$t->can(\$m);

        my \$f = bless [], '$finder';

        # XXX here is where we would grab return values
        push \@\$f, \$target->\$l(\@_);

        return \$f;
      }
EVAL

    eval $code;
    die @$ if $@;
    $autochained{$target_class} = $finder;
  }

  return $autochained{$target_class};
};

sub UNIVERSAL::autochain {
  my ($self_or_class) = @_;

  my ($callpack, $hints) = (caller(0))[0,10];

  die qq{Can't locate object method "autochain" via package "$callpack"}
    unless $hints->{autochain};

  my $dispatcher = __PACKAGE__->build_dispatcher_class($self_or_class);
  return $dispatcher;
}

1;

__END__

=head1 NAME

universal::autochain - add method chaining to artibrary classes and objects

=head1 DESCRIPTION

C<autochain> universally adds arbitrary chaining of method calls onto existing objects
and classes which do not naturally support method chaining.

=head1 SYNOPSIS

Since this class's methods do not return the object being operated on, this class
does not allow method chaining:

    package Mumble;

    sub new {
      my ($class, %args) = @_;
      return bless \%args, $class;
    }

    sub set {
      my ($self, $key, $val) = @_;

      $self->{$key} = $val;
      return undef;
    }

    sub get {
      my ($self, $key) = @_;

      return $self->{$key};
    }


Which means that this code will not work as one might desire:

    my $whisper = Mumble->new(type => 'message');
    my $type = $whisper->set(duration => '10s')
                       ->set(longevity => '10y')
                       ->get('type');

By simply invoking this module, the above code can be made to behave
reasonbly sensibly:

    my $whisper = Mumble->new(type => 'message');
    use univeral::autochain;
    my $type = $whisper->autochain->set(duration => '10s')
                                  ->set(longevity => '10y')
                                  ->get('type');

=head1 APOLOGIA

I'm not entirely sure whether I would ever use this module for myself, much less for
any paying employer. But this struck me as a weird problem to try solving, so I've
attempted to do that.

=head1 AUTHOR

(c) 2015 Belden Lyman <belden@cpan.org>

=head1 LICENSE

Whatever license I release everything else under.
