# This -*-perl -*- module implements a persistent counter class.
#
# $Id: CounterFile.pm,v 1.7 2007-08-09 13:40:53 pajamian Exp $
#

package Vend::CounterFile;
use Vend::Util;
use POSIX qw/strftime/;


=head1 NAME

Vend::CounterFile - Persistent counter class

=head1 SYNOPSIS

 use Vend::CounterFile;
 $c = new Vend::CounterFile "COUNTER", "aa00";

 $id = $c->inc;
 open(F, ">F$id");

=head1 DESCRIPTION

(This module is modified from Gisle Aas File::CounterFile to use 
 Interchange's locking protocols -- lack of fcntl locking was causing
 counter problems.)

This module implements a persistent counter class.  Each counter is
represented by a separate file in the file system.  File locking is
applied, so multiple processes might try to access the same counters
at the same time without risk of counter destruction.

You give the file name as the first parameter to the object
constructor (C<new>).  The file is created if it does not exist.

If the file name does not start with "/" or ".", then it is
interpreted as a file relative to C<$Vend::CounterFile::DEFAULT_DIR>.
The default value for this variable is initialized from the
environment variable C<TMPDIR>, or F</usr/tmp> is no environment
variable is defined.  You may want to assign a different value to this
variable before creating counters.

If you pass a second parameter to the constructor, that sets the
initial value for a new counter.  This parameter only takes effect
when the file is created (i.e. it does not exist before the call).

When you call the C<inc()> method, you increment the counter value by
one. When you call C<dec()> the counter value is decrementd.  In both
cases the new value is returned.  The C<dec()> method only works for
numerical counters (digits only).

You can peek at the value of the counter (without incrementing it) by
using the C<value()> method.

The counter can be locked and unlocked with the C<lock()> and
C<unlock()> methods.  Incrementing and value retrieval is faster when
the counter is locked, because we do not have to update the counter
file all the time.  You can query whether the counter is locked with
the C<locked()> method.

There is also an operator overloading interface to the
Vend::CounterFile object.  This means that you might use the C<++>
operator for incrementing the counter, C<--> operator for decrementing
and you can interpolate counters diretly into strings.

=head1 BUGS

(This problem alleviated by this modified module)

It uses flock(2) to lock the counter file.  This does not work on all
systems.  Perhaps we should use the File::Lock module?


=head1 COPYRIGHT

Copyright (c) 1995-1998 Gisle Aas. All rights reserved.
Modifications made by and copyright (C) 2002 Red Hat, Inc.
and (c) 2002-2007 Interchange Development Group

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Gisle Aas <aas@sn.no>

=cut

require 5.005;
use Carp   qw(croak);
use Symbol qw(gensym);
my $rewind_check;
eval {
		require 5.005;
		require Errno;
		import Errno qw(EINTR);
		$rewind_check = 1;
};

sub Version { $VERSION; }
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

# first line in counter file, regex to match good value
$MAGIC           = "#COUNTER-1.0\n";    # first line in standard counter files
# first line in date counter files
$MAGIC_RE        = qr/^#COUNTER-1.0-(gmt|date)-([A-Za-z0-9]+)/;
$MAGIC_DATE      = "#COUNTER-1.0-date"; # start of first line in date counter files
$MAGIC_GMT       = "#COUNTER-1.0-gmt";  # start of first line in gmt counter files

$DEFAULT_INITIAL	 	= 0;          # default initial counter value
$DEFAULT_DATE_INITIAL	= '0000';     # default initial counter value in date mode
$DATE_FORMAT     = '%Y%m%d';

 # default location for counter files
$DEFAULT_DIR     ||= $ENV{TMPDIR} || "/usr/tmp";

# Experimental overloading.
use overload ('++'     => \&inc,
			  '--'     => \&dec,
			  '""'     => \&value,
			  fallback => 1,
			 );


sub new
{
	my($class, $file, $initial, $date, $inc_routine, $dec_routine) = @_;
	croak "No file specified\n" unless defined $file;

	$file = "$DEFAULT_DIR/$file" unless $file =~ /^[\.\/]/;
	$initial = $date ? $DEFAULT_DATE_INITIAL : $DEFAULT_INITIAL
		unless defined $initial;

	my $gmt;
	my $magic_value;

	local($/, $\) = ("\n", undef);
	my ($fh, $first_line, $value) = get_initial_fh($file);
	if (! $fh) {
		if($first_line eq $MAGIC) {
			# do nothing
		}
		elsif( $first_line =~ $MAGIC_RE) {
			$date = $1;
			$initial = $2;
#::logDebug("read existing date counter, date=$date initial=$initial");
			$gmt = 1 if $date eq 'gmt';
			$magic_value = $first_line;
		}
		else {
			chomp($first_line);
			croak ::errmsg("Bad counter magic '%s' in %s", $first_line, $file);
		}
		chomp($value);
	} else {
		if($date) {
			my $ivalue;
			if($date eq 'gmt') {
				$magic_value = $MAGIC_GMT . "-$initial\n";
				print $fh $magic_value;
				$ivalue = strftime('%Y%m%d', gmtime()) . $initial;
				print $fh "$ivalue\n";
				$gmt = 1;
			}
			else {
				$magic_value = $MAGIC_DATE . "-$initial\n";
				print $fh $magic_value;
				$ivalue = strftime('%Y%m%d', localtime()) . $initial;
				print $fh "$ivalue\n";
			}
			$value = $ivalue;
		}
		else {
			print $fh $MAGIC;
			print $fh "$initial\n";
			$value = $initial;
		}
		close($fh);
	}

	my $s = { file    => $file,  # the filename for the counter
		   'value'  => $value, # the current value
			updated => 0,      # flag indicating if value has changed
			inc_routine => $inc_routine,      # Custom incrementor
			dec_routine => $dec_routine,      # Custom decrementor
			initial => $initial,      # initial value for date-based
			magic_value => $magic_value,      # initial magic value for date-based
			date	=> $date,  # flag indicating date-based counter
			gmt		=> $gmt,   # flag indicating GMT for date
			# handle => XXX,   # file handle symbol. Only present when locked
		  };
#::logDebug("counter object created: " . ::uneval($s));
	return bless $s;
}

sub get_initial_fh {
	my $file = shift;

	my $created;
	my $fh = gensym();

	( open $fh, "+<$file" or
		(++$created and open $fh, ">>$file" and open $fh, "+<$file" )
		) or croak "Can't open $file: $!";

	Vend::Util::lockfile($fh, 1, 1)
		or croak "Can't lock $file: $!";

	seek $fh, 0, 0;

	local($/) = "\n";
	my $magic = <$fh>;
	my $value = <$fh>;

	unless($created) {
		close $fh;
		undef $fh;
	}
	return ($fh, $magic, $value);
}

sub inc_value {
	my $self = shift;
	if ($self->{inc_routine}) {
		$self->{value} = $self->{inc_routine}->($self->{value});
		return;
	}
	$self->{'value'}++, return unless $self->{date};
	my $datebase = $self->{gmt}
				 ? strftime($DATE_FORMAT, gmtime())
				 : strftime($DATE_FORMAT, localtime());
	$self->{value} = $datebase . ($self->{initial} || $DEFAULT_DATE_INITIAL)
		if $self->{value} lt $datebase;
	my $inc = substr($self->{value}, 8);
#::logDebug("initial=$self->{initial} inc before autoincrement value=$inc");
	$inc++;
#::logDebug("initial=$self->{initial} inc after  autoincrement value=$inc");
	$self->{value} = $datebase . $inc;
}

sub dec_value {
	my $self = shift;
	if ($self->{dec_routine}) {
		$self->{value} = $self->{dec_routine}->($self->{value});
		return;
	}
	$self->{'value'}--;
	return;
}

sub locked
{
	exists shift->{handle};
}


sub lock
{
	my($self) = @_;
	$self->unlock if $self->locked;

	my $fh = gensym();
	my $file = $self->{file};

	open($fh, "+<$file") or croak "Can't open $file: $!";
	Vend::Util::lockfile($fh, 1, 1)
		or croak "Can't flock: $!";

	local($/) = "\n";
	my $magic = <$fh>;
	if ($magic ne $MAGIC and $magic !~ $MAGIC_RE ) {
		$self->unlock;
		chomp $magic;
		croak errmsg("Bad counter magic '%s' in %s on lock", $magic, $file);
	}
	chomp($self->{'value'} = <$fh>);

	$self->{handle}  = $fh;
	$self->{updated} = 0;
	$self;
}


sub unlock
{
	my($self) = @_;
	return unless $self->locked;

	my $fh = $self->{handle};

	if ($self->{updated}) {
		# write back new value
		local($\) = undef;
		my $sstatus;
		do {
				$sstatus = seek($fh, 0, 0)
		} while $rewind_check and ! $sstatus and $!{EINTR};
				
		croak "Can't seek to beginning: $!"
				if ! $sstatus;

		print $fh $self->{magic_value} || $MAGIC;
		print $fh "$self->{'value'}\n";
	}

	close($fh) or warn "Can't close: $!";
	delete $self->{handle};
	$self;
}


sub inc
{
	my($self) = @_;

	if ($self->locked) {
		$self->inc_value();
		$self->{updated} = 1;
	} else {
		$self->lock;
		$self->inc_value();
		$self->{updated} = 1;
		$self->unlock;
	}
	$self->{'value'}; # return value
}


sub dec
{
	my($self) = @_;

	if ($self->locked) {
		croak "Autodecrement is not magical in perl"
			unless $self->{dec_routine} || $self->{'value'} =~ /^\d+$/;
		croak "cannot decrement date-based counters"
			if $self->{date};
		$self->dec_value();
		$self->{updated} = 1;
	} else {
		$self->lock;
		croak "Autodecrement is not magical in perl"
			unless $self->{dec_routine} || $self->{'value'} =~ /^\d+$/;
		croak "cannot decrement date-based counters"
			if $self->{date};
		$self->dec_value();
		$self->{updated} = 1;
		$self->unlock;
	}
	$self->{'value'}; # return value
}


sub value
{
	my($self) = @_;
	my $value;
	if ($self->locked) {
		$value = $self->{'value'};
	} else {
		$self->lock;
		$value = $self->{'value'};
		$self->unlock;
	}
	$value;
}


sub DESTROY
{
	my $self = shift;
	$self->unlock;
}

####################################################################
#
# S E L F   T E S T   S E C T I O N
#
#####################################################################
#
# If we're not use'd or require'd execute self-test.
#
# Test is kept behind __END__ so it doesn't take uptime
# and memory  unless explicitly required. If you're working
# on the code you might find it easier to comment out the
# eval and __END__ so that error line numbers make more sense.

package main;

eval join('',<DATA>) || die $@ unless caller();

1;

__END__


$cf = "./zz-counter-$$";  # the name for out temprary counter

# Test normal object creation and increment

$c = new Vend::CounterFile $cf;

$id1 = $c->inc;
$id2 = $c->inc;

$c = new Vend::CounterFile $cf;
$id3 = $c->inc;
$id4 = $c->dec;

die "test failed" unless ($id1 == 1 && $id2 == 2 && $id3 == 3 && $id4 == 2);
unlink $cf;

# Test magic increment

$id1 = (new Vend::CounterFile $cf, "aa98")->inc;
$id2 = (new Vend::CounterFile $cf)->inc;
$id3 = (new Vend::CounterFile $cf)->inc;

eval {
	# This should now work because "Decrement is not magical in perl"
	$c = new Vend::CounterFile $cf; $id4 = $c->dec; $c = undef;
};
die "test failed (No exception to catch)" unless $@;

#print "$id1 $id2 $id3\n";

die "test failed" unless ($id1 eq "aa99" && $id2 eq "ab00" && $id3 eq "ab01");
unlink $cf;

# Test operator overloading

$c = new Vend::CounterFile $cf, "100";

$c->lock;

$c++;  # counter is now 101
$c++;  # counter is now 102
$c++;  # counter is now 103
$c--;  # counter is now 102 again

$id1 = "$c";
$id2 = ++$c;

$c = undef;  # destroy object

unlink $cf;

die "test failed" unless $id1 == 102 && $id2 == 103;


print "Selftest for Vend::CounterFile $Vend::CounterFile::VERSION ok\n";
