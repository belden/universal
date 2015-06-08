#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 2;

use FindBin qw($Bin);
use lib ("$Bin/../lib");

{
  package Unchained;

  sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
  }

  sub set {
    my ($self, $key, $value) = @_;
    $self->{$key} = $value;
    return undef;
  }

  sub get {
    my ($self, $key) = @_;
    my $val = $self->{$key};
    return ref $val
      ? @$val
      : $val;
  }

  sub join {
    my ($self, $delim, @keys) = @_;
    return join $delim, map { $self->{$_} } @keys;
  }
}

# ->autochain
{
  use universal::autochain;

  my $song = Unchained->new(type => 'melody');
  my $type = $song->autochain
    ->set(artist => 'Monet')
    ->set(amount => 4456)
    ->get('type');

  is( $type, $song->{type}, 'result of autochain is expected' );
  is_deeply( $song, +{
    type => 'melody',
    artist => 'Monet',
    amount => 4456,
  }, 'object looks as expected' );
}
