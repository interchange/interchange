print "LSB script running\n";

require File::Copy;
require File::Path;

print "File::Copy in\n";

my @mkdirs_root = qw(
	/etc/interchange
	/var/lib/interchange
	/var/cache/interchange
);

my @mkdirs_ic = qw(
	/var/run/interchange
	/var/log/interchange
);

for(@mkdirs_root) {
	if(-d $_) {
	}
	elsif(-e $_) {
		die "$_ already exists and is not a directory! Abort LSB install.\n";
	}
	else {
		print "Making directory $_\n";
		File::Path::mkpath($_);
	}
	chown 0, 0, $_;
	chmod 0755, $_;
}

my $ustart = 277;
my $gstart = 277;
my $icuid = getpwnam('interch');
my $icgid = getgrnam('interch');

while(! $icgid) {
	system '/usr/sbin/groupadd', '-g', $gstart++, 'interch';
	$icgid = getgrnam('interch');
}

while(! $icuid) {
	my @args = (
			'-u', $ustart,
			'-d', '/var/lib/interchange',
			'-g', 'interch',
			'-M',
			'interch',
			);
	system '/usr/sbin/useradd', @args;
	$ustart++;
	$icuid = getpwnam('interch');
}

for(@mkdirs_ic) {
	if(-d $_) {
	}
	elsif(-e $_) {
		die "$_ already exists and is not a directory! Abort LSB install.\n";
	}
	else {
		print "Making directory $_\n";
		File::Path::mkpath($_);
	}
	chown $icuid, $icgid, $_;
	chmod 0755, $_;
}

my %relocate = qw(
	/usr/lib/interchange/etc/makecat.cfg    /etc/interchange/makecat.cfg
	/usr/lib/interchange/catalog_before.cfg /etc/interchange/catalog_before.cfg
	/usr/lib/interchange/catalog_after.cfg  /etc/interchange/catalog_after.cfg
);

while (my ($from, $to) = each %relocate) {
	if(-f $to) {
		$to .= '.lsbdist';
	}
	next unless -f $from;
	File::Copy::move($from, $to)
		or die "Unable to move from $from to $to: $@ --> $!\n";
}

my $data;
my $configdest = '/etc/interchange/interchange.cfg';

if(-f '/etc/interchange.cfg') {
	$data = `cat /etc/interchange.cfg`;
	File::Copy::move('/etc/interchange.cfg', '$configdest.lsbsave');
	symlink 'interchange/interchange.cfg', '/etc/interchange.cfg'
		or die "Unable to symlink /etc/interchange.cfg: $!\n";
}
elsif(-f $configdest) {
	$data = `cat $configdest`;
}
else {
	$data = `cat /usr/lib/interchange/interchange.cfg.dist`;
}

print "Read config data, " . length($data) . " bytes\n";
my @lines = split /\n/, $data;

open CONFIG, "> $configdest"
	or die "cannot write $configdest: $!\n";

my @configextra = qw/
						RunDir
						ConfigDir
						ConfigAllBefore
						ConfigAllAfter
						Inet_Mode
						Unix_Mode
					/;

my %needed ;
for(@configextra) {
	$needed{$_} = 1;
}

my %configextra = qw(
	RunDir          /var/run/interchange
	ConfigDir       /etc/interchange
	ConfigAllBefore /etc/interchange/catalog_before.cfg
	ConfigAllAfter  /etc/interchange/catalog_after.cfg
	Inet_Mode       </etc/interchange/inet_mode
	Unix_Mode       </etc/interchange/unix_mode
);
	
for(@lines) {
	next unless /^\s*([A-Z]\w+)\s+/ and $needed{$1};
	undef $needed{$_};
}

my $firstline;
while(@lines) {
	my $line = shift(@lines);
	if($line =~ /^[A-Z]/) {
		$firstline = $line;
		last;
	}
	print CONFIG "$line\n";
}

for(@configextra) {
	next unless $needed{$_};
	print CONFIG sprintf("%-15s %s\n", $_, $configextra{$_});
}

print CONFIG "$firstline\n";
for(@lines) {
	print CONFIG "$_\n";
}

close CONFIG;

my $inetmode = '/etc/interchange/inet_mode';
my $unixmode = '/etc/interchange/unix_mode';
if(! -f $unixmode) {
	open MODE, "> $unixmode"
		or die "Cannot write $unixmode: $!\n";
	print MODE "Yes\n";
	close MODE;
}
if(! -f $inetmode) {
	open MODE, "> $inetmode"
		or die "Cannot write $inetmode: $!\n";
	print MODE "No\n";
	close MODE;
}

my $initscript  = '/etc/init.d/interchange';
my $logscript   = '/etc/logrotate.d/interchange';
my $runwrap = '/usr/sbin/interchange';
my $makewrap = '/usr/sbin/makecat';

for($runwrap, $makewrap, $initscript, $logscript) {
	if(-f $_) {
		rename $_, "$_.old"
			or die "Couldn't rename $_ to $_.old: $!\n";
	}
}

File::Copy::copy('SPECS/interchange-init', $initscript);
File::Copy::copy('SPECS/interchange-logrotate', $logscript);

my $wrap = <<'EOF';
#!/bin/sh

# Interchange control script
# Calls Interchange with special locations of files as installed by RPM
# http://www.icdevgroup.org/

IC=/usr/lib/interchange
ETC=/etc/interchange
RUN=/var/run/interchange
LOG=/var/log/interchange

RUNSTRING="$IC/bin/interchange \
	--unix \
	-configfile $ETC/interchange.cfg \
	-pidfile $RUN/interchange.pid \
	-logfile $LOG/error.log \
	ErrorFile=$LOG/error.log \
	PIDfile=$RUN/interchange.pid \
	-confdir $ETC \
	-rundir $RUN \
	SocketFile=$RUN/socket \
	IPCsocket=$RUN/socket.ipc"

if test "`whoami`" = root
then 
	exec su - interch -c "$RUNSTRING $*"
else
	exec $RUNSTRING $*
fi
EOF

open WRITEWRAP, "> $runwrap"
	or die "Can't write wrapper script $runwrap: $!\n";

print WRITEWRAP $wrap;
close WRITEWRAP;

open WRITEWRAP, "> $makewrap"
	or die "Can't write wrapper script $makewrap: $!\n";

$wrap = <<'EOF';
#!/bin/sh

# Interchange make catalog script
# Calls Interchange makecat with special locations of files as installed for LSB
# http://www.icdevgroup.org/

ETC=/etc/interchange
IC=/usr/lib/interchange
RUN=/var/run/interchange
LOG=/var/log/interchange
CACHE=/var/cache/interchange
CATDIR=/var/lib/interchange

EXTRA=
for i in $*
do
	if test -n "$last"
	then
		EXTRA="$EXTRA $last"
	fi
	last=$i
done

RUNSTRING="$IC/bin/makecat \
	-permtype U
    -basedir $CATDIR \
    -c $ETC/makecat.cfg \
    -catuser interch \
    -cgibase /cgi-bin \
    -cgidir /var/www/cgi-bin \
    -configfile $ETC/interchange.cfg \
    -documentroot /var/www/html \
    -interchangegroup interch \
    -interchangeuser interch \
    -linkfile $RUN/socket \
    -serverconf /etc/httpd/conf/httpd.conf \
    -vendroot $IC \
	logdir=$LOG/$last \
	cachedir=$CACHE/$last \
	$EXTRA -- $last"

exec $RUNSTRING
EOF

print WRITEWRAP $wrap;
close WRITEWRAP;

for($runwrap, $makewrap, $initscript) {
	chmod 0755, $_
		or die "Couldn't change mode of $_: $!\n";
}

