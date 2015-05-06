package universal::overridable;

sub import {
  my ($class, @funcs) = @_;
  $class->make_global_stub($_) foreach @funcs;
}

sub make_global_stub {
  my ($class, $func) = @_;

  my ($sub) = $func =~ m{^.*:(\w+)$};
  my $proto = CORE::prototype($func);
  my $prototype = defined $proto ? "($proto)" : "";
  my $pass_args = $proto ? "\@_" : "";

  eval <<"EVAL";
    sub CORE::MONKEYPATCH::$sub $prototype { return CORE::$sub($pass_args) }
    *CORE::GLOBAL::$sub = sub $prototype { goto &CORE::MONKEYPATCH::$sub };
EVAL
}

1;

__END__

=head1 NAME

universal::overridable - make CORE functions universally overridable across all Perl versions

=head1 SYNOPSIS

    #!/usr/bin/env perl

    use strict;
    use warnings;

    my $now = time;

    my $then = do {
      use universal::overridable qw(CORE::time);
      no warnings 'redefine';
      local *CORE::GLOBAL::time = sub () { 19490201 };
      time;
    };

    my $later = time;

    my $subsequently = do {
      use universal::overridable +{
        'CORE::time' => sub { 9770 },
      };

      time;
    };

    my $again = time;

    print <<PRINT
    now: $now
    then: $then
    later: $later (pretty close to $now)
    subsequently: $subsequently (a long time ago)
    again: $again
    PRINT

    __END__
