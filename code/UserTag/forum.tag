# Copyright 2002-2010 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.

UserTag forum-userlink PosNumber 0
UserTag forum-userlink addAttr
UserTag forum-userlink Version   1.7
UserTag forum-userlink Routine   <<EOR
sub {
	my ($row) = @_;
	return $row->{name} || $Variable->{FORUM_ANON_NAME} || 'Anonymous Coward'
		if $row->{anon} or ! $row->{username};
	my $realname = tag_data('userdb', 'handle', $row->{username})
				 || tag_data('userdb', 'fname', $row->{username});
	return $realname || $row->{username};
}
EOR

UserTag forum Order     top
UserTag forum addAttr 
UserTag forum hasEndTag 
UserTag forum NoReparse 1
UserTag forum Version   1.7
UserTag forum Routine   <<EOR
my @uls;
my $lastlevel;

sub {
	my ($id, $opt, $tpl) = @_;

	if(! $id) {
	  $id = '0';
	}

	my $forum_header;
	my $forum_footer;
	my $forum_link;
	my $forum_scrub;

	$tpl ||= '';
	$tpl =~ s{\[forum[-_]header\](.*)\[/forum[-_]header\]}{}is
		and $forum_header = $1;
	$tpl =~ s{\[forum[-_]footer\](.*)\[/forum[-_]footer\]}{}is
		and $forum_footer = $1;
	$tpl =~ s{\[forum[-_]link\](.*)\[/forum[-_]link\]}{}is
		and $forum_link = $1;
	$tpl =~ s{\[forum[-_]scrub\](.*)\[/forum[-_]scrub\]}{}is
		and $forum_scrub = $1;

	$forum_header ||= $opt->{header_template} || <<EOF;
<table>
  <tr>
	<td class=contentbar1>
	  <b>{SUBJECT}</b>
	  by <b>{USERINFO}</b>
	  on {DATE}
	</td>
  </tr>
  <tr>
	<td>
		{COMMENT}
	</td>
  </tr>
{ADDITIONAL?}
  <tr>
	<td>
		{ADDITIONAL}
	</td>
  </tr>
{/ADDITIONAL?}
	<tr>
	  <td>
		 &#91; 
		  {TOP_URL?}<A HREF="{TOP_URL}">Top</A> |{/TOP_URL?}
		  {PARENT_URL?}<A HREF="{PARENT_URL}">Parent</A> |{/PARENT_URL?}
		  <A HREF="{REPLY_URL}">Reply</A>
		 &#93; 
	  </td>
	</tr>
	</table>
<hr>
EOF

	 $forum_link ||= $opt->{link_template} || <<EOF;
<A HREF="{DISPLAY_URL}">{SUBJECT}</a> by {USERINFO} on {DATE}
EOF

	 $opt->{threshold_message} ||= errmsg("Message below your threshold");
	 $forum_scrub ||= $opt->{scrub_template} || <<EOF;
<A HREF="{DISPLAY_URL}">$opt->{threshold_message}</a>
EOF

	$tpl ||= $opt->{template} || <<EOF;
<table cellspacing=0 cellpadding=2>
  <tr>
	<td class=contentbar1>
		<A HREF="{DISPLAY_URL}"><b>{SUBJECT}</b></A>
		by <b>{USERINFO}</b>
		on {DATE}
	</td>
	<td class=contentbar1 align=right>
		<small>&#91; <A HREF="{REPLY_URL}"><b>Reply</b></A> &#93;</font></small>
	</td>
  </tr>
  <tr>
	<td colspan=2>
	{COMMENT}
	<!--
		prior to UL: {MSG1}
		prior to /UL: {MSG2}
		prior to END: {MSG3}
	-->
	</td>
  </tr>
</table>
EOF

	$forum_footer ||= <<EOF;
<!-- end of forum -->
EOF

	my $lastlevel = 0;
	my @uls;

	my $Tag = new Vend::Tags;
	my $row = shift;

	$opt->{reply_page} ||= 'forum/reply';
	$opt->{submit_page} ||= 'forum/submit';
	$opt->{display_page} ||= $Global::Variable->{MV_PAGE};
	$opt->{date_format} ||= '%B %e, %Y @%H:%M';
	my $menu_row = sub {
	  shift;
	  my $row = shift;
	  $row->{reply_url} = $Tag->area({
	  								href => $opt->{reply_page},
	  								arg => $row->{code},
									});
	  if($row->{code} ne $row->{artid}) {
		  $row->{top_url} = $Tag->area( {
										href => $opt->{display_page},
										arg => $row->{artid},
									});
	  }
	  if($row->{parent}) {
		  $row->{parent_url} = $Tag->area( {
										href => $opt->{display_page},
										arg => $row->{parent},
									});
	  }
	  $row->{display_url} = $Tag->area({
									href => $opt->{display_page},
									arg => $row->{code},
									});
	  $row->{userinfo} = $Tag->forum_userlink($row);
	  $row->{date} = $Tag->convert_date({
									  fmt => $opt->{date_format},
									  body => $row->{created},
								  });
	  my $lev = $row->{mv_level};
	  my $children = $row->{mv_children};
	  my $last = $row->{mv_last};
	  my $pre = '';
	  my $post = '';
	  my $num_uls = scalar(@uls);
	  $row->{msg1} = "lastlevel=$lastlevel lev=$lev children=$children uls=$num_uls";
	  if(! $lev) {
		  $pre .= join "", splice (@uls);
	  }
	  elsif ($lastlevel < $lev) {
		  $lastlevel = $lev;
	  }
	  elsif ($lastlevel > $lev) {
		  $lastlevel = $lev;
		  $pre .= join "", splice (@uls,$lev);
	  }
	  if($children) {
		  push @uls, '</ul>';
	  }
	  $num_uls = scalar(@uls);
	  $row->{msg2} = "lastlevel=$lastlevel lev=$lev children=$children uls=$num_uls";
	  if($children) {
		  $post .= '<ul>';
	  }
	  elsif($last) {
		  $post .= join "", splice (@uls, $lev);
	  }
	  $num_uls = scalar(@uls);
	  $row->{msg3} = "lastlevel=$lastlevel lev=$lev children=$children uls=$num_uls";
	  $row->{forum_prepend} = $pre;
	  $row->{forum_append} = $post;
	  return $row;
	};

	my $fdb = database_exists_ref('forum')
		or die "No forum DB!";

	my $record = $fdb->row_hash($id);
	return undef unless $record;

	$menu_row->(undef, $record);
	my @out;

	$opt->{full} = 1 if ! defined $opt->{full};

	push @out, $Tag->uc_attr_list($record, $forum_header);

	my %o = (
	  table			=> 'forum',
	  start			=> $id,
	  master		=> 'parent',
	  subordinate	=> 'code',
	  full			=> $opt->{full},
	  sort			=> 'code',
	  spacer		=> "&nbsp;",
	  autodetect	=> 1,
	  iterator		=> $menu_row,
	  spacing		=> 4,
	);

	$Tag->tree(\%o);

	my $rows = $o{object}{mv_results};
	$opt->{scrub_score} ||= 0;
	$opt->{show_score} ||= 1;
	if(! defined $opt->{show_level}) {
		if($record->{code} == $record->{artid}) {
			$opt->{show_level} = 0;
		}
		else {
			$opt->{show_level} = 2;
		}
	}

	for(\$tpl, \$forum_link, \$forum_scrub) {
		$$_ = "{FORUM_PREPEND}$$_" unless $$_ =~ /\{FORUM_PREPEND\}/;
		$$_ .= '{FORUM_APPEND}' unless $$_ =~ /\{FORUM_APPEND\}/;
	}

	for my $record (@$rows) {

		my $this_tpl;
		if($record->{score} <= $opt->{scrub_score}) {
			$this_tpl = $forum_scrub;
		}
		elsif($record->{score} >= $opt->{show_score}) {
			$this_tpl = $tpl;
		}
		elsif($record->{mv_level} <= $opt->{show_level}) {
			$this_tpl = $tpl;
		}
		else {
			$this_tpl = $forum_link;
		}
		push @out, $Tag->uc_attr_list($record, $this_tpl);
	}
	push @out, join "", @uls;
	push @out, $Tag->uc_attr_list($opt, $forum_footer);
	return join "\n", @out;
}
EOR
