use ExtUtils::MakeMaker;

my @exec_files;
push @exec_files, 'bin/' . $_ for qw/binary files add here/;

WriteMakefile(
    NAME      => 'thread',
    AUTHOR    => 'haryzhou <zcman2005@gmail.com>',
    ABSTRACT  => '---------------add here---------------',
    LICENSE   => 'artistic_2',
    VERSION_FROM => 'lib/-----------add-here-------.pm',
    META_MERGE => {
        requires => { perl => '5.10' },
        resources => {
            homepage    => 'http://mojolicio.us',
            license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
            MailingList => 'http://groups.google.com/group/thread',
            repository  => 'http://github.com/haryzhou/thread',
            bugtracker  => 'http://github.com/haryzhou/thread/issues'
        }
    },

    PREREQ_PM => {
        'Data::Dump'        => 1.21,
        'POE'               => 1.354,
        'POE::Filter::JSON' => 0.04,
    },

    EXE_FILES => [ @exec_files ],
    test      => {
        TESTS => 't/*.t t/*/*.t',
    },
);

