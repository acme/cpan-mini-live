#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'CPAN::Mini::Live',
    VERSION_FROM => 'lib/CPAN/Mini/Live.pm',
    ABSTRACT     => 'Keep CPAN Mini up to date',
    AUTHOR       => 'Leon Brocard <acme@astray.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'CPAN::Mini'      => '0',
        'Net::FriendFeed' => '0',
    },
);

