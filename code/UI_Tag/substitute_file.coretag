UserTag substitute_file Order file
UserTag substitute_file addAttr
UserTag substitute_file hasEndTag
UserTag substitute_file Routine <<EOR
## This is a stupid thing to make 5.6.1 and File::Copy
## compatible with Safe
require File::Copy;
package File::Copy;
require File::Basename;
import File::Basename 'basename';
package Vend::Interpolate;
sub {
	my ($file, $opt, $replace) = @_;
	my $die = sub {
		my @args = @_;
		$::Scratch->{ui_failure} = errmsg(@args);
		return undef;
	};

	return $die->("substitute_file - %s: file does not exist", $file)
		if ! -f $file;
	return $die->("substitute_file - %s: file not writeable", $file)
		if ! -w $file;

	if($opt->{content}) {
		$opt->{begin} = '<!--+\s*begin\s+content\s*--+>';
		$opt->{end} = '<!--+\s*end\s+content\s*--+>';
		$opt->{newline} = 1 if ! defined $opt->{newline};
	}

	if($opt->{scratch}) {
		$opt->{begin} = '\[(?:tmp|seti?)\s*' . $opt->{scratch} . '\]';
		$opt->{end} = '\[/(?:tmp|seti?)\]';
		$opt->{greedy} = 0 if ! defined $opt->{greedy};
		$opt->{newline} = 1 if ! defined $opt->{newline};
	}

	if (! length($opt->{begin}) or ! length($opt->{end})) {
		return $die->("missing begin or end marker");
	}

	my $bak = POSIX::tmpnam();
	File::Copy::copy($file, $bak)
		or return $die->(
					"substitute_file - %s: unable to backup to %s",
					$file, $bak,
					);
	my $data = Vend::Util::readfile($file);
	return $die->("substitute_file - %s: file has no data", $file)
		unless length $data;

	my $exist;
	if(defined $opt->{greedy} and ! Vend::Util::is_yes($opt->{greedy}) ) {
		$exist = $opt->{newline} ? '[\s\S]*?' : '.*?';
	}
	else {
		$exist = $opt->{newline} ? '[\s\S]*' : '.*';
	}
	
	my $begin = $opt->{begin};
	my $end = $opt->{end};
	my $subbed;

	my $sub = sub {
			my ($begin, $replace, $end) = @_;
			return $replace if $opt->{replace};
			return $begin . $replace . $end;
	};

	if($opt->{case} and $opt->{global}) {
		$subbed = $data =~ s{($begin)$exist($end)}{$sub->($1, $replace, $2)}ge;
	}
	elsif($opt->{global}) {
		$subbed = $data =~ s{($begin)$exist($end)}{$sub->($1, $replace, $2)}ige;
	}
	elsif($opt->{case}) {
		$subbed = $data =~ s{($begin)$exist($end)}{$sub->($1, $replace, $2)}e;
	}
	else {
		$subbed = $data =~ s{($begin)$exist($end)}{$sub->($1, $replace, $2)}ie;
	}

	if( $subbed ) {
		open(SUBFILE, ">$file")
			or return $die->(
						"substitute_file: cannot write %s, backup in %s",
						$file, $bak,
						);
		print SUBFILE $data
			or return $die->(
						"substitute_file: error writing %s, backup in %s",
						$file, $bak,
						);
		close SUBFILE
			or return $die->(
						"substitute_file: error closing %s, backup in %s",
						$file, $bak,
						);
		unlink $bak;
	}
	else {
		unlink $bak;
		return 0;
	}
}
EOR
