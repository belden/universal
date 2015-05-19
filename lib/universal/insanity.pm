use strict;
use warnings;
package universal::insanity;

our $VERSION = 0.01;

1;

__END__

=pod

=head1 NAME

universal::insanity - crazy things that I think would be perfectly sane to stick into Perl's UNIVERSAL.

=head1 SYNOPSIS

    #!/usr/bin/env perl

    use strict;
    use warnings;

    {
        package Foo;

        sub dumper_class { 'Data::Dumper' }

        sub dump_it {
            my (@args) = @_;

            use universal::dynamic_use;
            print UNIVERSAL->dynamic_use->dumper_class->Dump(\@args);
        }
    }


    {
        use universal::func;

        Foo->func->dump_it([1..5]);
    }

    __END__
    $VAR1 = [
              1,
              2,
              3,
              4,
              5
            ];

This program demonstrates C<universal::func> and C<universal::dynamic_use> in their simple forms. More
insane usages are supported.

=head1 DESCRIPTION

C<universal::dynamic_use> encapsulates the runtime-loading pattern in a syntactically pleasing way.
Additionally, this module allows you to import prototyped functions at runtime; function prototypes
are either declared by the programmer, or are discovered at compile time.

C<universal::func> converts the next method call into a function call. The code that accomplishes
this can be glossed away by declaring at compile time the list of functions that you wish to make
callable as either functions or methods.

See documentation on these individual modules for more in-depth information.

=head1 AUTHOR

(c) 2015 Belden Lyman <belden@cpan.org>

=head1 LICENSE

As Perl.

=cut
