UserTag survey-graph Order item_id
UserTag survey-graph addAttr
UserTag survey-graph Routine <<EOR
use GD::Graph;
use GD::Graph::pie;
use GD::Graph::bars;
use GD::Graph::Data;
use vars qw/$Tag/;
sub {
	my ($id, $opt) = @_;
	my $tab = $opt->{table} || 'survey';
	my $meta;
	my $survey;
	my $question;

	my $db = database_exists_ref($tab);
		
	if($id) {
		($survey, $question) = split /:+/, $id;
	}
	elsif($opt->{survey} and $opt->{question}) {
		$id = $opt->{survey} . '::' . $opt->{question};
	}

	my @meta_opts = qw/
		graph_enable
		graph_label
		graph_value_font
		graph_value_font_size
		graph_low_water
		graph_title
		graph_type
		graph_height		
		graph_width
		graph_label_length
	/;

	my @possible_gd = qw/
                accent_threshold accentclr axis_space axislabelclr
                b_margin bar_spacing bar_width bgclr borderclrs box_axis
                boxclr correct_width cumulate cycle_clrs dclrs fgclr
                interlaced l_margin labelclr legendclr line_type_scale
                line_types line_width logo logo_position logo_resize
                long_ticks marker_size markers overwrite r_margin
                shadow_depth shadowclr show_values skip_undef t_margin
                text_space textclr tick_length transparent two_axes
                types values_format values_space values_vertical
                valuesclr x_all_ticks x_label x_label_position
                x_label_skip x_label_skip x_label_skip x_labels_vertical
                x_max_value x_min_value x_number_format x_plot_values
                x_tick_number x_tick_offset x_ticks y_label
                y_label_position y_label_skip y_label_skip y_max_value
                y_min_value y_number_format y_plot_values y_tick_number
                zero_axis zero_axis_only
		/;

	my %meta_opts;
	@meta_opts{@meta_opts} = @meta_opts;

	my %gd_opts;

	for(@possible_gd) {
		next unless defined $opt->{$_} or length $meta->{"graph_$_"};
		$gd_opts{$_} = defined $opt->{$_} ? $opt->{$_} : $meta->{"graph_$_"};
	}

	if($id) {
		$meta = $Tag->meta_record($id, undef, $tab);
	}
	$meta ||= {};

	for(@meta_opts) {
		$meta->{$_} = $opt->{$_} if defined $opt->{$_};
	}

	$meta->{graph_width} ||= 400;
	$meta->{graph_height} ||= 300;
	$meta->{graph_label_length} ||= 20;

	# If we ever support multiple types
	$meta->{graph_type} ||= 'pie';

	my %label;

	$gd_opts{title} = $meta->{graph_title} || $meta->{label};
	$gd_opts{title} = '' if $opt->{notitle};
	my $str;
	if($str = $meta->{graph_label}) {
		$str =~ s/\s+$//;
		$str =~ s/^\s+//;
		$str =~ s/[\r\n]+/\n/g;
		my @things = split /\n/, $str;
		for(@things) {
			s/^\s+//;
			s/\s+$//;
			my ($k, $v) = split /\s*=\s*/, $_, 2;
			$label{$k} = $v;
		}
	}
	elsif($str = $meta->{options}) {
		$str =~ s/\s+$//;
		$str =~ s/^\s+//;
		HTML::Entities::decode_entities($str);
		$str =~ s/[\r\n]+/\n/g;
		my @things = split /\s*,\s*/, $str;
		for(@things) {
			s/^\s+//;
			s/\s+$//;
			my ($k, $v) = split /\s*=\s*/, $_, 2;
			next unless length($k);
			$label{$k} = $v;
		}
	}

	my $ary;
	my %answer;

	if(! $opt->{file}) {
		$opt->{file} = "logs/survey/$survey.txt";
	}

	if($opt->{search}) {
		my $c = {};
		Vend::Scan::find_search_params($c, $opt->{search});
		my $so = new Vend::TextSearch;
		my $q = $so->array($c);
		$ary = $q->{mv_results};
	}
	elsif ($opt->{query}) {
		unless($db) {
			die errmsg("survey-graph: No database table base for query!\n");
		}
		$ary = $db->query($opt->{query});
	}

	my $tot_ans = 0;

	if(! $ary) {
		my $file = $Tag->filter('filesafe', $opt->{file});
		open INP, "< $file"
			or die errmsg("survey-graph: Unknown survey file %s.\n", $file);
		my $hdr = <INP>;
		chomp($hdr);
		my @f = split /\t/, $hdr;
		my $idx = 0;
		for(@f) {
			last if $_ eq $question;
			$idx++;
		}
		if($f[$idx] ne $question) {
			die errmsg("survey-graph: Unknown question %s.\n", $question);
		}
		while(<INP>) {
			chomp;
			$tot_ans++;
			@f = split /\t/, $_;
			$answer{$f[$idx]}++;
		}
		close INP;
	}
	else {
		for(@$ary) {
			$tot_ans++;
			$answer{$_->[0]}++;
		}
	}

	my @keys = keys %answer;

	@keys = sort { $answer{$b} <=> $answer{$a} } @keys;

	die "No answers!" unless $tot_ans > 0;

	my @labs;
	my @data;
	my $stop;
	if($#keys > 7) {
		$stop = 6;
	}
	else {
		$stop = $#keys;
	}

	for(my $i = 0; $i <= $stop; $i++) {
		my $val = $keys[$i];
		my $lab = $label{$val} || $val;
		$lab = $Tag->filter("$meta->{graph_label_length}.", $lab) 
			if length($lab) > $meta->{graph_label_length};
		if($opt->{show_percent}) {
			my $pct = $answer{$val} / $tot_ans * 100;
			my $num = $opt->{show_num} ? "$answer{$val}, " : '';
			$lab .= sprintf " (%s%.1f%%)", $num, $pct;
		}
		elsif ($opt->{show_num}) {
			$lab .= " ($answer{$val})";
		}
		push @labs, $lab;
		push @data, $answer{$val};
	}

	$stop++;
	my $other = 0;
	for(my $i = $stop; $i <= $#keys; $i++) {
		$other += $answer{$keys[$i]};
	}

	if($other > 0) {
		my $lab = errmsg('Other');
		$lab = $Tag->filter("$meta->{graph_label_length}.", $lab) 
			if length($lab) > $meta->{graph_label_length};
		if($opt->{show_percent}) {
			my $pct = $other / $tot_ans * 100;
			my $num = $opt->{show_num} ? "$other, " : '';
			$lab .= sprintf " (%s%.1f%%)", $num, $pct;
		}
		elsif ($opt->{show_num}) {
			$lab .= " ($other)";
		}
		push @labs, $lab;
		push @data, $other;
	}
#::logDebug("labels=" . ::uneval(\@labs));
#::logDebug("data=" . ::uneval(\@data));
	my $graph;
	my $font;
	if($meta->{graph_type} eq 'bars') {
		$graph = GD::Graph::bars->new($meta->{graph_width}, $meta->{graph_height});
	}
	else {
		$graph = GD::Graph::pie->new($meta->{graph_width}, $meta->{graph_height});
		if($font = $meta->{graph_value_font}) {
			if($font eq 'small') {
				$font = GD::gdSmallFont();
			}
			elsif($font eq 'medium') {
				$font = GD::gdMediumBoldFont();
			}
			elsif ($font eq 'large') {
				$font = GD::gdLargeFont();
			}
			elsif ($font eq 'giant') {
				$font = GD::gdGiantFont();
			}
			$gd_opts{label_font} = $font;
		}
		$graph->set_value_font($font, $meta->{graph_value_font_size});
#::logDebug("GD font set error: " . GD::Text->error());
	}
	$graph->set(%gd_opts);
	my $gd = $graph->plot([ \@labs, \@data ]);
	$Tag->deliver( { type => 'image/png', body => $gd->png });
	return;
}
EOR
