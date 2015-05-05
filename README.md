### NAME

universal - things that I think would be perfectly fine to stick into Perl's UNIVERSAL

### SYNOPSIS

#### universal::dynamic_use - runtime loading of classes and functions

These two classes have a circular use: using `Ouroborus::Head` uses `Ouroborus::Tail`, which in
turn uses `Ouroborus::Head`. This means `Head` cannot be compiled without first compiling `Head`.

```perl
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
```

One pattern to break such circles is to implement a method that returns the name of a class to
be loaded at runtime, and then to do so. `universal::dynamic_use` makes the "load it up" portion
of that pattern look like a regular method call.

```perl
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

{
  package Ouroborus::Tail;
  use strict;
  use warnings;

  sub head_class { 'Ouroborus::Head' }

  sub be_eaten {
    my ($class) = @_;
    use universal::dynamic_use;
    return $class->dynamic_use->head_class->new;
  }

  1;
}
```

#### universal::func - make function calls look like method calls

```perl
  sub SillyMath::add_two_things { my ($l, $r) = @_; return $l + $r }

  sub SomewhereElse::do_math {
    use universal::func qw(SillyMath::add_two_things);
    SillyMath->add_two_things(1, 2); # 3
  }

  sub Elsewhere::add_two_gizmos {
    my ($class_or_object) = shift;

    use univeral::func;
    SillyMath->func->add_two_things(1, 2); # 3
  }
```

It's worth knowing that the first call, as shown in `SomewhereElse::do_math`, manipulates the
`SillyMath` symbol table to replace `SillyMath::add_two_things` with a wrapped function. The wrapper
simply discards the invocant if it looks like you have a relevant `use universal::func` active.

The second call, as shown in `Elsewhere::add_two_gizmos`, does not tamper with the `SillyMath` symbol
table.

### AUTHOR

(c) 2015 - Belden Lyman <belden@cpan.org>

