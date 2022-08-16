$MV::Self = {
  'INSTALLMAN1DIR' => '/home/interchange/interchange/man',
  'INSTALLARCHLIB' => '/home/interchange/interchange',
  'PL_FILES' => {
                  'relocate.pl' => [
                                     'scripts/compile_link',
                                     'scripts/config_prog',
                                     'scripts/configdump',
                                     'scripts/crontab',
                                     'scripts/expire',
                                     'scripts/expireall',
                                     'scripts/findtags',
                                     'scripts/ic_mod_perl',
                                     'scripts/interchange',
                                     'scripts/localize',
                                     'scripts/makecat',
                                     'scripts/offline',
                                     'scripts/restart',
                                     'scripts/update'
                                   ]
                },
  'INSTALLPRIVLIB' => '/home/interchange/interchange/lib',
  'EXE_FILES' => [
                   'scripts/compile_link',
                   'scripts/config_prog',
                   'scripts/configdump',
                   'scripts/crontab',
                   'scripts/expire',
                   'scripts/expireall',
                   'scripts/findtags',
                   'scripts/ic_mod_perl',
                   'scripts/interchange',
                   'scripts/localize',
                   'scripts/makecat',
                   'scripts/offline',
                   'scripts/restart',
                   'scripts/update'
                 ],
  'VERSION' => undef,
  'INSTALLSCRIPT' => '/home/interchange/interchange/bin',
  'INSTALLBIN' => '/home/interchange/interchange/bin',
  'INSTALLDIRS' => 'perl',
  'INSTALLMAN3DIR' => '/home/interchange/interchange/man'
}
;
1;