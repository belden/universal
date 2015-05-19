use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME                => 'universal::insanity',
  AUTHOR              => 'Belden Lyman <belden@cpan.org>',
  VERSION_FROM        => 'lib/universal/insanity.pm',
  ABSTRACT_FROM       => 'lib/universal/insanity.pm',
  PL_FILES            => {},
  PREREQ_PM => {
    'Test::More'      => 0,
  },
  META_MERGE => {
    resources => {
      bugtracker => 'https://github.com/belden/universal/issues',
      homepage   => 'https://github.com/belden/universal',
      repository => 'git://github.com/belden/universal.git',
    },
  },
  dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
  clean               => { FILES => 'universal-insanity-*' },
);
