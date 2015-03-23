use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'Zeta',
    AUTHOR    => 'haryzhou <zcman2005@gmail.com>',
    ABSTRACT  => 'Account system generator',
    LICENSE   => 'artistic_2',
    VERSION_FROM => 'lib/Zeta/Run.pm',
    META_MERGE => {
        requires => { perl => '5.10' },
        resources => {
            homepage    => 'http://mojolicio.us',
            license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
            MailingList => 'http://groups.google.com/group/zeta',
            repository  => 'http://github.com/haryzhou/zeta',
            bugtracker  => 'http://github.com/haryzhou/zeta/issues'
        }
    },

    PREREQ_PM => {
        'Data::Dump'        => 1.21,
        'POE'               => 1.354,
        'POE::Filter::JSON' => 0.04,
    },

    EXE_FILES => [ 'bin/zeta', 'bin/zdq', ],
    test      => {
        TESTS => 't/*.t t/*/*.t',
    },
);
