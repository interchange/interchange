package IniConf;
require 5.002;
$VERSION = 0.97;

use strict;
use Carp;
use vars qw( $VERSION @instance $instnum @oldhandler @errors );

=head1 NAME

IniConf - A Module for reading .ini-style configuration files

=head1 SYNOPSIS

  use IniConf;

=head1 DESCRIPTION

IniConf provides a way to have readable configuration files outside
your Perl script.  The configuration can be safely reloaded upon
receipt of a signal.

=cut

=head1 USAGE

Get a new IniConf object with the I<new> method:

  $cfg = IniConf->new( -file => "/path/configfile.ini" );
  $cfg = new IniConf -file => "/path/configfile.ini";

Optional named parameters may be specified after the configuration
file name.  See the I<new> in the B<METHODS> section, below.

INI files consist of a number of sections, each preceeded with the
section name in square brackets.  The first nonblank character of
the line indicating a section must be a left bracket and the last
nonblank character of a line indicating a section must be a right
bracket. The characters making up the section name can be any 
symbols at all. The section may even be be empty. However section
names must be unique.

Parameters are specified in each section as Name=Value.  Any spaces
around the equals sign will be ignored, and the value extends to the
end of the line

  [section]
  Parameter=Value

Both the hash mark (#) and the semicolon (;) are comment characters.
Lines that begin with either of these characters will be ignored.  Any
amount of whitespace may preceed the comment character.

Multiline or multivalued fields may also be defined ala UNIX "here
document" syntax:

  Parameter=<<EOT
  value/line 1
  value/line 2
  EOT

You may use any string you want in place of "EOT".  Note that what
follows the "<<" and what appears at the end of the text MUST match
exactly, including any trailing whitespace.

See the B<METHODS> section, below, for settable options.

Values from the config file are fetched with the val method:

  $value = $cfg->val('Section', 'Parameter');

If you want a multi-line/value field returned as an array, just
specify an array as the receiver:

  @values = $cfg->val('Section', 'Parameter');

=head1 METHODS

=cut


#
# Package variables
#
@instance = ( );
$instnum  = 0;
@oldhandler =  ( );
@errors = ( );


=head2 new (-file=>$filename, [-option=>value ...] )

Returns a new configuration object (or "undef" if the configuration
file has an error).  One IniConf object is required per configuration
file.  The following named parameters are available:

=over 10

=item I<-default> section

Specifies a section is used for default values.  For example, if you
look up the "permissions" parameter in the "users" section, but there
is none, IniConf will look to your default section for a "permissions"
value before returning undef.

=item I<-reloadsig> signame

You may specify a signal (such as SIGHUP) that will cause the
configuration file to be read.  This is useful for static daemons
where a full restart in order to realize a configuration change would
be undesirable.  Note that your application must be tolerant of the
signal you choose.  If a signal handler was already in place before
the IniConf object is created, it will be called after the
configuration file is reread.  The signal handler will not be
re-enabled until after the configuration file is reread any the
previous signal handler returns.

=item I<-reloadwarn> 0|1

Set -reloadwarn => 1 to enable a warning message (output to STDERR)
whenever the config file is reloaded.  The reload message is of the
form:

  PID <PID> reloading config file <file> at YYYY.MM.DD HH:MM:SS

See your system documentation for information on valid signals.

=item I<-nocase> 0|1

Set -nocase => 1 to handle the config file in a case-insensitive
manner (case in values is preserved, however).  By default, config
files are case-sensitive (i.e., a section named 'Test' is not the same
as a section named 'test').  Note that there is an added overhead for
turning off case sensitivity.

=back

=cut

sub new {
  my $class = shift;
  my %parms = @_;

  my $errs = 0;
  my @groups = ( );

  my $self           = {};
  $self->{cf}        = '';
  $self->{firstload} = 1;
  $self->{default}   = '';

  # Parse options
  my($k, $v);
  local $_;
  while (($k, $v) = each %parms) {
    if ($k eq '-file') {
      $self->{cf} = $v;
    }
    elsif ($k eq '-reloadsig') {
      $v =~ s/^SIG//;
      $self->{reloadsig} = uc($v);
    }
    elsif ($k eq '-default') {
      $self->{default} = $v;
    }
    elsif ($k eq '-nocase') {
      $self->{nocase} = $v ? 1 : 0;
    }
    elsif ($k eq '-reloadwarn') {
      $self->{reloadwarn} = $v ? 1 : 0;
    }
    else {
      carp "Unknown named parameter $k=>$v";
      $errs++;
    }
  }

  croak "must specify -file parameter for new $class" 
    unless $self->{cf};

  return undef if $errs;

  # Set up a signal handler if requested
  my($sig, $oldhandler, $newhandler);
  if ($sig = $self->{reloadsig}) {
    $oldhandler[$instnum] = $SIG{$sig};
    $newhandler = "${class}::SigHand_$instnum";
    my $toeval = <<"EOT";

	sub $newhandler {
	  \$SIG{$sig} = 'IGNORE';
	  \$${class}::instance[$instnum]->ReadConfig;
	  if (\$oldhandler[$instnum] && \$oldhandler[$instnum] ne 'IGNORE') {
	    eval '&$oldhandler[$instnum];';
	  }
	  \$SIG{$sig} = '$newhandler'
	}

EOT
    
    eval $toeval;
  }

  bless $self, $class;

  $instance[$instnum++] = $self;

  if ($self->ReadConfig) {
    $SIG{$sig} = $newhandler if $sig;
    return $self;
  } else {
    return undef;
  }
}

=head2 val ($section, $parameter)

Returns the value of the specified parameter in section $section.

=cut

sub val {
  my $self = shift;
  my $sect = shift;
  my $parm = shift;

  if ($self->{nocase}) {
    $sect = lc($sect);
    $parm = lc($parm);
  }
  my $val = defined($self->{v}{$sect}{$parm}) ?
	    $self->{v}{$sect}{$parm} :
	    $self->{v}{$self->{default}}{$parm};
  if (ref($val) eq 'ARRAY') {
    return wantarray ? @$val : join($/, @$val);
  } else {
    return $val;
  }
}

=head2 setval ($section, $parameter, $value, [ $value2, ... ])

Sets the value of parameter $section in section $section to $value (or
to a set of values).  See below for methods to write the new
configuration back out to a file.

You may not set a parameter that didn't exist in the original
configuration file.  B<setval> will return I<undef> if this is
attempted.  Otherwise, it returns 1.

=cut

sub setval {
  my $self = shift;
  my $sect = shift;
  my $parm = shift;
  my @val  = @_;

  if (defined($self->{v}{$sect}{$parm})) {
    if (@val > 1) {
      $self->{v}{$sect}{$parm} = \@val;
    } else {
      $self->{v}{$sect}{$parm} = shift @val;
    }
    return 1;
  } else {
    return undef;
  }
}

=head2 newval($setion, $parameter, $value [, $value2, ...])

Adds a new value to the configuration file.

=cut

sub newval {
  my $self = shift;
  my $sect = shift;
  my $parm = shift;
  my @val  = @_;

unless (defined($self->{v}{$sect}{$parm})) {
	push(@{$self->{parms}{$sect}}, $parm);
}
if (@val > 1) {
   	$self->{v}{$sect}{$parm} = \@val;
   	} else {
   	$self->{v}{$sect}{$parm} = shift @val;
   	}
   	return 1
}

=head2 delval($section, $parameter)

Deletes the specified value from the configuration file

=cut

sub delval {
  my $self = shift;
  my $sect = shift;
  my $parm = shift;

	@{$self->{parms}{$sect}} = grep !/^$parm$/, @{$self->{parms}{$sect}};
	delete $self->{v}{$sect}{$parm};
	return 1
}

=head2 ReadConfig

Forces the config file to be re-read.  Also see the I<-reloadsig>
option to the B<new> method for a way to connect this method to a
signal (such as SIGHUP).

=cut

sub ReadConfig {
  my $self = shift;

  local *CF;
  my($lineno, $sect);
  my($group, $groupmem);
  my($parm, $val);
  my @cmts;
  @errors = ( );

  # Initialize (and clear out) storage hashes
  $self->{sects}  = [];		# Sections
  $self->{groups} = {};		# Subsection lists
  $self->{v}      = {};		# Parameter values
  $self->{sCMT}   = {};		# Comments above section

  my $nocase = $self->{nocase};

  my ($ss, $mm, $hh, $DD, $MM, $YY) = (localtime(time))[0..5];
  printf STDERR
    "PID %d reloading config file %s at %d.%02d.%02d %02d:%02d:%02d\n",
    $$, $self->{cf}, $YY+1900, $MM+1, $DD, $hh, $mm, $ss
    unless $self->{firstload} || !$self->{reloadwarn};

  $self->{firstload} = 0;

  open(CF, $self->{cf}) || carp "open $self->{cf}: $!";
  local $_;
  while (<CF>) {
    chomp;
    $lineno++;

    if (/^\s*$/) {				# ignore blank lines
      next;
    }
    elsif (/^\s*[\#\;]/) {			# collect comments
      push(@cmts, $_);
      next;
    }
    elsif (/^\s*\[(.*)\]\s*$/) {		# New Section
      $sect = $1;
      $sect = lc($sect) if $nocase;
      push(@{$self->{sects}}, $sect);
      if ($sect =~ /(\S+)\s+(\S+)/) {		# New Group Member
	($group, $groupmem) = ($1, $2);
	if (!defined($self->{group}{$group})) {
	  $self->{group}{$group} = [];
	}
	push(@{$self->{group}{$group}}, $groupmem);
      }
      if (!defined($self->{v}{$sect})) {
	$self->{sCMT}{$sect} = [@cmts] if @cmts > 0;
	$self->{pCMT}{$sect} = {};		# Comments above parameters
	$self->{parms}{$sect} = [];
	@cmts = ( );
	$self->{v}{$sect} = {};
      }
    }
    elsif (($parm, $val) = /\s*([\S\s]+?)\s*=\s*(.*)/) {	# new parameter
      $parm = lc($parm) if $nocase;
      $self->{pCMT}{$sect}{$parm} = [@cmts];
      @cmts = ( );
      if ($val =~ /^<<(.*)/) {			# "here" value
	my $eotmark  = $1;
	my $foundeot = 0;
	my $startline = $lineno;
	my @val = ( );
	while (<CF>) {
	  chomp;
	  $lineno++;
	  if ($_ eq $eotmark) {
	    $foundeot = 1;
	    last;
	  } else {
	    push(@val, $_);
	  }
	}
	if ($foundeot) {
	  $self->{v}{$sect}{$parm} = \@val;
	  $self->{EOT}{$sect}{$parm} = $eotmark;
	} else {
	  push(@errors, sprintf('%d: %s', $startline, 
			      qq#no end marker ("$eotmark") found#));
	}
      } else {
	$self->{v}{$sect}{$parm} = $val;
      }
      push(@{$self->{parms}{$sect}}, $parm);
    }
    else {
      push(@errors, sprintf('%d: %s', $lineno, $_));
    }
  }
  close(CF);
  @errors ? undef : 1;
}

=head2 Sections

Returns an array containing section names in the configuration file.
If the I<nocase> option was turned on when the config object was
created, the section names will be returned in lowercase.

=cut

sub Sections {
  my $self = shift;
  @{$self->{sects}};
}

=head2 Parameters ($sectionname)

Returns an array containing the parameters contained in the specified
section.

=cut

sub Parameters {
  my $self = shift;
  my $sect = shift;
  @{$self->{parms}{$sect}};
}

=head2 GroupMembers ($group)

Returns an array containing the members of specified $group.  Groups
are specified in the config file as new sections of the form

  [GroupName MemberName]

This is useful for building up lists.  Note that parameters within a
"member" section are referenced normally (i.e., the section name is
still "Groupname Membername", including the space).

=cut

sub GroupMembers {
  my $self  = shift;
  my $group = shift;

  @{$self->{group}{$group}};
}

=head2 WriteConfig ($filename)

Writes out a new copy of the configuration file.  A temporary file
(ending in .new) is written out and then renamed to the specified
filename.  Also see B<BUGS> below.

=cut

sub WriteConfig {
  my $self = shift;
  my $file = shift;

  local(*F);
  open(F, "> $file.new") || do {
    carp "Unable to write temp config file $file: $!";
    return undef;
  };
  my $oldfh = select(F);
  $self->OutputConfig;
  close(F);
  select($oldfh);
  rename "$file.new", $file || do {
    carp "Unable to rename temp config file to $file: $!";
    return undef;
  };
  return 1;
}

=head2 RewriteConfig

Same as WriteConfig, but specifies that the original configuration
file should be rewritten.

=cut

sub RewriteConfig {
  my $self = shift;
  $self->WriteConfig($self->{cf});
}

sub OutputConfig {
  my $self = shift;

  my($sect, $parm, @cmts);
  my $notfirst = 0;
  local $_;
  foreach $sect (@{$self->{sects}}) {
    print "\n" if $notfirst;
    $notfirst = 1;
    if ((ref($self->{sCMT}{$sect}) eq 'ARRAY') &&
	(@cmts = @{$self->{sCMT}{$sect}})) {
      foreach (@cmts) {
	print "$_\n";
      }
    }
    print "[$sect]\n";

    foreach $parm (@{$self->{parms}{$sect}}) {
      if ((ref($self->{pCMT}{$sect}{$parm}) eq 'ARRAY') &&
	  (@cmts = @{$self->{pCMT}{$sect}{$parm}})) {
	foreach (@cmts) {
	  print "$_\n";
	}
      }
      my $val = $self->{v}{$sect}{$parm};
      if (ref($val) eq 'ARRAY') {
	my $eotmark = $self->{EOT}{$sect}{$parm};
	print "$parm= <<$eotmark\n";
	foreach (@{$val}) {
	  print "$_\n";
	}
	print "$eotmark\n";
      } else {
	print "$parm=", $self->{v}{$sect}{$parm}, "\n";
      }
    }
  }
}

1;

=head1 DIAGNOSTICS

=head2 @IniConf::errors

Contains a list of errors encountered while parsing the configuration
file.  If the I<new> method returns B<undef>, check the value of this
to find out what's wrong.  This value is reset each time a config file
is read.

=head1 BUGS

=over 3

=item *

IniConf won't know if you change the signal handler that it's using
for config reloads.

=item *

The signal handling stuff is almost guaranteed not to work on non-UNIX
systems.

=item *

The output from [Re]WriteConfig/OutputConfig might not be as pretty as
it can be.  Comments are tied to whatever was immediately below them.

=item *

No locking is done by [Re]WriteConfig.  When writing servers, take
care that only the parent ever calls this, and consider making your
own backup.

=item *

The Windows INI specification (if there is one) probably isn't
followed exactly.  First and foremost, IniConf is for making
easy-to-maintain (and read) configuration files.


=back

=head1 VERSION

Version 0.97

=head1 AUTHOR

  Scott Hutton
    E-Mail:        shutton@pobox.com
    WWW Home Page: http://www.pobox.com/~shutton/

  Later hacked on by Rich Bowen
	E-Mail:			rbowen@rcbowen.com
	URL: 			http://www.rcbowen.com/

  Patches contributed by Bernie Cosell, Alex Satrapa, Scott Dellinger,
  Steve Campbell, R. Bernsteid, and various other generous people. Thanks.

=head1 COPYRIGHT

Copyright (c) 1996,1997 Scott Hutton. All rights reserved. This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=head1 To do

In a soon-coming release, this code will move to the name C<Config::IniFiles>
This is because there are a lot of configuration modules that are 
floating around in various different name spaces. It would be nice if
namespaces meant something. I don't know when that will be, but hopefully
in the next few months.

=cut

