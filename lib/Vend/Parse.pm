# Vend::Parse - Parse Interchange tags
# 
# $Id: Parse.pm,v 2.0.2.9 2002-11-26 03:21:10 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Parse;
require Vend::Parser;

use Safe;
use Vend::Util;
use Vend::Interpolate;
use Text::ParseWords;
use Vend::Data qw/product_field/;

require Exporter;

@ISA = qw(Exporter Vend::Parser);

$VERSION = substr(q$Revision: 2.0.2.9 $, 10);

@EXPORT = ();
@EXPORT_OK = qw(find_matching_end);

use strict;

use vars qw($VERSION);

my($CurrentSearch, $CurrentCode, $CurrentDB, $CurrentWith, $CurrentItem);
my(@SavedSearch, @SavedCode, @SavedDB, @SavedWith, @SavedItem);

my %PosNumber =	( qw!

				accessories      2
				and              1
				area             2
				assign           0
				attr_list        1
				banner           1
				bounce           2
				cart             1
				cgi              1
				charge           1
				checked          2
				control          2
				control_set      1
				counter          1
				currency         2
				data             3
				default          2
				description      2
				discount         1
				dump             1
				ecml             2
				either           0
				error            1
				warnings         1
				export           1
				field            2
				file             2
				filter           1
				flag             1
				fly_list         2
				fly_tax          1
				goto             2
				handling         1
				harness          0
				html_table       0
				if               1
				unless           1
				import           2
				include          2
				index            1
				input_filter     1
				label            1
				log              1
				loop             1
				mail             1
				msg				 1
				mvasp            1
				nitems           1
				onfly            2
				options          1
				or               1
				order            2
				page             2
				parse_locale     0
				perl             1
				price            1
				profile          1
				query            1
				record           0
				region           0
				row              1
				salestax         2
				scratch          1
				scratchd         1
				search_region    0
				selected         2
				set              1
				seti             1
				setlocale        2
				shipping         1
				shipping_desc    1
				soap			 3
				sql              2
				strip            0
				subtotal         2
				tag              2
				time             1
				timed_build      1
				tmp              1
				total_cost       2
				try              1
				userdb           1
				value            2
				value_extended   1

			! );

my %Order =	(

				accessories		=> [qw( code arg )],
				attr_list		=> [qw( hash )],
				area			=> [qw( href arg )],
				assign			=> [],
				banner          => [qw( category )],
				bounce			=> [qw( href if )],
				calc			=> [],
				cart			=> [qw( name  )],
				catch			=> [qw( label )],
				cgi				=> [qw( name  )],
				currency		=> [qw( convert noformat )],
				charge			=> [qw( route )],
				checked			=> [qw( name value )],
				counter			=> [qw( file )],
				data			=> [qw( table field key )],
				default			=> [qw( name default )],
				dump			=> [qw( key )],
				description		=> [qw( code base )],
				discount		=> [qw( code  )],
				ecml			=> [qw( name function )],
				either		    => [qw( )],
                error           => [qw( name )],
                warnings        => [qw( message )],
				export			=> [qw( table )],
				field			=> [qw( name code )],
				file			=> [qw( name type )],
				filter			=> [qw( op )],
				flag			=> [qw( type )],
				time			=> [qw( locale )],
				fly_tax			=> [qw( area )],
				fly_list		=> [qw( code )],
				goto			=> [qw( name if)],
				harness		    => [qw( )],
				html_table	    => [qw( )],
				if				=> [qw( type term op compare )],
				unless			=> [qw( type term op compare )],
				or				=> [qw( type term op compare )],
				and				=> [qw( type term op compare )],
				index			=> [qw( table )],
				import 			=> [qw( table type )],
				input_filter 	=> [qw( name )],
				include			=> [qw( file locale )],
				item_list		=> [qw( name )],
				label			=> [qw( name )],
				log				=> [qw( file )],
				loop			=> [qw( list )],
				nitems			=> [qw( name  )],
				onfly			=> [qw( code quantity )],
				order			=> [qw( code quantity )],
				page			=> [qw( href arg )],
				perl			=> [qw( tables )],
				mail			=> [qw( to )],
				msg				=> [qw( key )],
				mvasp			=> [qw( tables )],
				options			=> [qw( code )],
				parse_locale	=> [qw( )],			 
				price			=> [qw( code )],
				profile			=> [qw( name )],
				process      	=> [qw( target secure )],
				query			=> [qw( sql )],
				read_cookie		=> [qw( name )],
				row				=> [qw( width )],
				salestax		=> [qw( name noformat)],
				scratch			=> [qw( name  )],
				scratchd		=> [qw( name  )],
				search_region	=> [qw( arg   )],
				region			=> [qw( )],
				record			=> [qw( )],
				restrict		=> [qw( enable )],
				control			=> [qw( name default )],
				control_set		=> [qw( index )],
				selected		=> [qw( name value )],
				set_cookie		=> [qw( name value expire domain path )],
				setlocale		=> [qw( locale currency )],
				set				=> [qw( name )],
				seti			=> [qw( name )],
				tree			=> [qw( table master subordinate start )],
				tmp 			=> [qw( name )],
				shipping		=> [qw( mode )],
				handling		=> [qw( mode )],
				shipping_desc	=> [qw( mode )],
				soap			=> [qw( call uri proxy )],
# SQL
				sql				=> [qw( type query)],
# END SQL
				strip			=> [],
				subtotal		=> [qw( name noformat )],
				tag				=> [qw( op arg )],
				timed_build		=> [qw( file )],
				total_cost		=> [qw( name noformat )],
				try				=> [qw( label )],
				userdb          => [qw( function ) ],
				update          => [qw( function ) ],
				value			=> [qw( name )],
				value_extended  => [qw( name )],

			);

my %addAttr = (
				qw(
					accessories     1
					area            1
					assign          1
					banner          1
					catch           1
                    cgi             1
					charge          1
					checked         1
					counter         1
					control         1
					control_set     1
					data			1
					default			1
					ecml            1
					error           1
					warnings        1
					export          1
					flag            1
					fly_list		1
					harness         1
					html_table      1
					import          1
					index           1
					input_filter    1
					item_list       1
					loop			1
					onfly			1
					page            1
					mail            1
					msg				1
					mvasp           1
				    nitems			1
				    options			1
					order			1
					perl            1
					price			1
					profile			1
					process         1
					query			1
                    soap            1
                    sql             1
					selected        1
					setlocale       1
					restrict        1
                    record          1
                    region          1
                    search_region   1
					shipping        1
					handling        1
                    tag             1
                    log             1
					time			1
					timed_build     1
                    tree            1
                    try             1
					update          1
					userdb          1
					value           1
					value_extended  1
				)
			);

my %hasEndTag = (

				qw(
						catch           1
						control_set     1
						either          1
						harness         1
                        attr_list       1
                        calc            1
                        currency        1
                        discount        1
                        filter	        1
                        fly_list        1
                        html_table      1
                        if              1
                        import          1
                        input_filter    1
                        item_list       1
                        log             1
                        loop            1
                        mail            1
						msg				1
                        mvasp           1
                        perl            1
                        parse_locale    1
                        query           1
                        region          1
                        restrict        1
                        row             1
                        search_region   1
                        set             1
                        set             1
                        seti            1
                        sql             1
                        strip           1
                        tag             1
                        time			1
                        timed_build     1
                        tmp             1
                        tree            1
                        try             1
                        unless          1

				)
			);


my %InvalidateCache = (

			qw(
				cgi			1
				cart		1
				charge		1
				checked		1
				counter		1
				default		1
				discount	1
				export  	1
				flag        1
				item_list	1
				import		1
				index		1
				input_filter		1
				if          1
				unless      1
				mail		1
				mvasp		1
				nitems		1
				perl		1
				profile		1
				salestax	1
				scratch		1
				scratchd	1
				selected	1
				read_cookie 1
				set_cookie  1
				set			1
				soap		1
				tmp			1
				seti		1
				shipping	1
				handling	1
				sql			1
				subtotal	1
				total_cost	1
				userdb		1
				update	    1
				value		1
				value_extended 1

			   )
			);

my %Implicit = (

			data =>		{ qw( increment increment ) },
			checked =>	{ qw( multiple	multiple default	default ) },
			page    =>	{ qw( secure	secure ) },
			area    =>	{ qw( secure	secure ) },

			unless =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},
			if =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},

			and =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},

			or =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},

			);

my %PosRoutine = (
				or			=> sub { return &Vend::Interpolate::tag_if(@_, 1) },
				and			=> sub { return &Vend::Interpolate::tag_if(@_, 1) },
				if			=> \&Vend::Interpolate::tag_if,
				unless		=> \&Vend::Interpolate::tag_unless,
			);

my %Routine = (

				accessories		=> \&Vend::Interpolate::tag_accessories,
				attr_list		=> \&Vend::Interpolate::tag_attr_list,
				area			=> \&Vend::Interpolate::tag_area,
				assign			=> \&Vend::Interpolate::tag_assign,
				banner			=> \&Vend::Interpolate::tag_banner,
				bounce          => sub { return '' },
				calc			=> \&Vend::Interpolate::tag_calc,
				cart			=> \&Vend::Interpolate::tag_cart,
				catch			=> \&Vend::Interpolate::catch,
				cgi				=> \&Vend::Interpolate::tag_cgi,
				charge			=> \&Vend::Payment::charge,
				checked			=> \&Vend::Interpolate::tag_checked,
				control			=> \&Vend::Interpolate::tag_control,
				control_set		=> \&Vend::Interpolate::tag_control_set,
				counter			=> \&Vend::Interpolate::tag_counter,
				currency		=> sub {
										my($convert,$noformat,$amount) = @_;
										return &Vend::Util::currency(
														$amount,
														$noformat,
														$convert);
									},
				data			=> \&Vend::Interpolate::tag_data,
				default			=> \&Vend::Interpolate::tag_default,
				dump			=> \&::full_dump,
				description		=> \&Vend::Data::product_description,
				discount		=> \&Vend::Interpolate::tag_discount,
				ecml			=> sub {
											require Vend::ECML;
											return Vend::ECML::ecml(@_);
										},
				either			=> sub {
											my @ary = split /\[or\]/, shift;
											my $result;
											while(@ary) {
												$result = interpolate_html(shift @ary);
												$result =~ s/^\s+//;
												$result =~ s/\s+$//;
												return $result if $result;
											}
											return;
										},
				error			=> \&Vend::Interpolate::tag_error,
				warnings		=> \&Vend::Interpolate::tag_warnings,
				export			=> \&Vend::Interpolate::export,
				field			=> \&Vend::Data::product_field,
				file			=> \&Vend::Interpolate::tag_file,
				filter			=> \&Vend::Interpolate::filter_value,
				flag			=> \&Vend::Interpolate::flag,
				fly_tax			=> \&Vend::Interpolate::fly_tax,
				fly_list		=> \&Vend::Interpolate::fly_page,
				harness			=> \&harness,
				html_table		=> \&Vend::Interpolate::html_table,
				index			=> \&Vend::Data::index_database,
				import 			=> \&Vend::Data::import_text,
				include			=> sub {
									&Vend::Interpolate::interpolate_html(
										&Vend::Util::readfile
											($_[0], $Global::NoAbsolute, $_[1])
										  );
									},
				input_filter	=> \&Vend::Interpolate::input_filter,
				item_list		=> \&Vend::Interpolate::tag_item_list,
				if				=> \&Vend::Interpolate::tag_self_contained_if,
				unless			=> \&Vend::Interpolate::tag_unless,
				or				=> sub { return &Vend::Interpolate::tag_self_contained_if(@_, 1) },
				and				=> sub { return &Vend::Interpolate::tag_self_contained_if(@_, 1) },
				goto			=> sub { return '' },
				label			=> sub { return '' },
				log				=> \&Vend::Interpolate::log,
				loop			=> \&Vend::Interpolate::tag_loop_list,
				nitems			=> \&Vend::Util::tag_nitems,
				onfly			=> \&Vend::Order::onfly,
				options			=> \&Vend::Interpolate::tag_options,
				order			=> \&Vend::Interpolate::tag_order,
				page			=> \&Vend::Interpolate::tag_page,
				perl			=> \&Vend::Interpolate::tag_perl,
				mail			=> \&Vend::Interpolate::tag_mail,
				msg				=> \&Vend::Interpolate::tag_msg,
# MVASP
				mvasp			=> \&Vend::Interpolate::mvasp,
# END MVASP
				parse_locale    => \&Vend::Util::parse_locale,
				price        	=> \&Vend::Interpolate::tag_price,
				process      	=> \&Vend::Interpolate::tag_process,
				profile      	=> \&Vend::Interpolate::tag_profile,
				query			=> \&Vend::Interpolate::query,
				read_cookie     => \&Vend::Util::read_cookie,

				row				=> \&Vend::Interpolate::tag_row,
				salestax		=> \&Vend::Interpolate::tag_salestax,
				scratch			=> \&Vend::Interpolate::tag_scratch,
				scratchd		=> \&Vend::Interpolate::tag_scratchd,
				record			=> \&Vend::Interpolate::tag_record,
				region			=> \&Vend::Interpolate::region,
				search_region	=> \&Vend::Interpolate::tag_search_region,
				selected		=> \&Vend::Interpolate::tag_selected,
				setlocale		=> \&Vend::Util::setlocale,
				set_cookie		=> \&Vend::Util::set_cookie,
				set				=> \&Vend::Interpolate::set_scratch,
				seti			=> \&Vend::Interpolate::set_scratch,
				shipping		=> \&Vend::Interpolate::tag_shipping,
				handling		=> \&Vend::Interpolate::tag_handling,
				shipping_desc	=> \&Vend::Interpolate::tag_shipping_desc,
				sql				=> \&Vend::Data::sql_query,
				soap			=> \&Vend::SOAP::tag_soap,
				subtotal		=> \&Vend::Interpolate::tag_subtotal,
				strip			=> sub {
										local($_) = shift;
										s/^\s+//;
										s/\s+$//;
										return $_;
									},
				tag				=> \&Vend::Interpolate::do_tag,
				tmp				=> \&Vend::Interpolate::set_tmp,
				tree			=> \&Vend::Interpolate::tag_tree,
				try				=> \&Vend::Interpolate::try,
				time			=> \&Vend::Interpolate::mvtime,
				timed_build		=> \&Vend::Interpolate::timed_build,
				total_cost		=> \&Vend::Interpolate::tag_total_cost,
				userdb			=> \&Vend::UserDB::userdb,
				update			=> \&Vend::Interpolate::update,
				value			=> \&Vend::Interpolate::tag_value,
				value_extended	=> \&Vend::Interpolate::tag_value_extended,

			);

## Put here because we need to call keys %Routine
## Restricts execution of tags by tagname
$Routine{restrict} = sub {
	my ($enable, $opt, $body) = @_;
	my $save = $Vend::Cfg->{AdminSub};

	my $save_restrict = $Vend::restricted;

	my $default;
	if("\L$opt->{policy}" eq 'allow') {
		# Accept all, deny only ones defined in disable
		$default = undef;
		$opt->{policy} = 'allow';
	}
	else {
		# This is default, deny all except enabled
		$default = 1;
		$opt->{policy} = 'deny';
	}
	my @enable  = split /[\s,\0]+/, $enable;
	my @disable = split /[\s,\0]+/, $opt->{disable};

	for(@enable, @disable) {
		$_ = lc $_;
		tr/-/_/;
	}


	my %restrict;
	for(keys %Routine) {
		$restrict{$_} = $default;
	}

	$restrict{$_} = undef for @enable;
	$restrict{$_} = 1     for @disable;
	$restrict{$_} = 1     for keys %$save;

	$Vend::Cfg->{AdminSub} = \%restrict;
	$Vend::restricted = join " ",
			'default=', $opt->{policy},
			'enable=', join(",", @enable),
			'disable=', join(",", @disable),
			;
	my $out;
	eval {
		$out = Vend::Interpolate::interpolate_html($body);
	};
	$Vend::restricted = $save_restrict;
	$Vend::Cfg->{AdminSub} = $save;
	return $out;
};

my %attrAlias = (
	 counter        => { 'name' => 'file' },
	 query          => { 'query' => 'sql' },
	 tree          	=> { 'sub' => 'subordinate' },
	 perl          	=> { 'table' => 'tables' },
	 mvasp         	=> { 'table' => 'tables' },
	 price         	=> { 'base' => 'mv_ib' },
	 query 			=> { 'base' => 'table' },
	 page          	=> {
	 						'base' => 'arg',
						},
	 record          	=> { 
	 						'column' => 'col',
	 						'code' => 'key',
	 						'field' => 'col',
						},
	 flag          	=> { 
	 						'flag' => 'type',
	 						'name' => 'type',
	 						'tables' => 'table',
						},
	 field          	=> { 
	 						'field' => 'name',
	 						'column' => 'name',
	 						'col' => 'name',
	 						'key' => 'code',
	 						'row' => 'code',
						},
	 'index'          	=> { 
	 						'database' => 'table',
	 						'base' => 'table',
						},
	 import          	=> { 
	 						'database' => 'table',
	 						'base' => 'table',
						},
	 input_filter          	=> { 
	 						'ops' => 'op',
	 						'var' => 'name',
	 						'variable' => 'name',
						},
	 accessories    => { 
	 						'database' => 'table',
	 						'db' => 'table',
	 						'base' => 'table',
	 						'field' => 'column',
	 						'col' => 'column',
	 						'key' => 'code',
	 						'row' => 'code',
						},
	 export          	=> { 
	 						'database' => 'table',
	 						'base' => 'table',
						},
	 data          	=> { 
	 						'database' => 'table',
	 						'base' => 'table',
	 						'name' => 'field',
	 						'column' => 'field',
	 						'col' => 'field',
	 						'code' => 'key',
	 						'row' => 'key',
						},
	 'or'			=> { 
	 						'comp' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 'and'			=> { 
	 						'comp' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 'userdb'		=> {
	 						'table' => 'db',
	 						'name' => 'nickname',
						},
	 'shipping'			=> {
	 							'name' => 'mode',
	 							'tables' => 'table',
	 							'modes' => 'mode',
	 							'carts' => 'cart',
							},
	 'handling'			=> {	
	 							'name' => 'mode',
	 							'tables' => 'table',
	 							'modes' => 'mode',
	 							'carts' => 'cart',
							},
	 'salestax'			=> { 'cart' => 'name', },
	 'subtotal'			=> { 'cart' => 'name', },
	 'total_cost'		=> { 'cart' => 'name', },
	 'unless'			=> { 
	 						'comp' => 'compare',
	 						'condition' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 'if'			=> { 
	 						'comp' => 'compare',
	 						'condition' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 search_region		=> { search => 'arg',
	 						 params => 'arg',
	 						 args => 'arg', },
	 region			   	=> { search => 'arg',
	 						 params => 'arg',
	 						 args => 'arg', },
	 loop	          	=> { args => 'list',
	 						 arg => 'list', },
	 item_list	       	=> { cart => 'name', },
	 tag		       	=> { description => 'arg', },
	 log		       	=> { arg => 'file', },
	 msg				=> { lc => 'inline', },
);

my %Alias = (

				qw(
						url				urldecode
						urld			urldecode
						href			area
						warning			warnings
						shipping_description	shipping_desc
						process_target	process
				),
					getlocale		=> 'setlocale get=1',
					process_search		=> 'area href=search',
					process_order		=> 'process order=1',
					buzzard		=> 'data table=products column=artist key=',
			);

my %replaceHTML = (
				qw(
					del .*
					pre .*
					xmp .*
					script .*
				)
			);

my %replaceAttr = (
					area			=> { qw/ a 	href form action/},
					process			=> { qw/ form action		/},
					checked			=> { qw/ input checked		/},
					selected		=> { qw/ option selected	/},
			);

my %insertHTML = (
				qw(

				form	process|area
				a 		area
				input	checked
				option  selected
				)
			);

my %lookaheadHTML = (
				qw(

				if 		then|elsif|else
				unless 	then|elsif|else
				)
			);

my %rowfixHTML = (	qw/
						td	item_list|loop|sql_list
					/	 );
# Only for containers
my %insideHTML = (
				qw(
					select	loop|item_list|tag
				)

				);

# Only for containers
my %endHTML = (
				qw(

				tr 		.*
				td 		.*
				th 		.*
				del 	.*
				script 	.*
				table 	if
				object 	perl
				param 	perl
				font 	if
				a 		if
				)
			);

my %Interpolate = (

				qw(
						calc		1
						currency	1
						import		1
						msg			1
						row			1
						seti		1
						tmp			1
				)
			);

my %NoReparse = ( qw/
					mvasp			1
					restrict		1
				/ );

my %Gobble = ( qw/
					timed_build		1
					mvasp			1
				/ );

my $Initialized = 0;

my $Test = 'test001';
sub harness {
	my ($opt, $input) = @_;
	my $not;
	my $expected =  $opt->{expected} || 'OK';
	$input =~ s:^\s+::;
	$input =~ s:\s+$::;
	$input =~ s:\s*\[expected\](.*)\[/expected\]\s*::s
		and $expected = $1;
	$input =~ s:\[not\](.*)\[/not\]::s
		and $not = $1;
	my $name = $Test++;
	$name = $opt->{name}
		if defined $opt->{name};
	my $result;
	eval {
		$result = Vend::Interpolate::interpolate_html($input);
	};
	if($@) {
		my $msg = "DIED in test $name. \$\@: $@";
#::logDebug($msg);
		return $msg;
	}
	if($expected) {
		return "NOT OK $name: $result!=$expected" unless $result =~ /$expected/;
	}
	if($not) {
		return "NOT OK $name: $result==$not" unless $result !~ /$not/;
	}
	return "OK $name";
}

sub global_init {
		add_tags($Global::UserTag);
		my $tag;
		foreach $tag (keys %Routine) {
			$Order{$tag} = []
				if ! defined $Order{$tag};
			next if defined $PosNumber{$tag};
			$PosNumber{$tag} = scalar @{$Order{$tag}};
		}
}

sub new {
    my $class = shift;
    my $self = new Vend::Parser;
	$self->{INVALID} = 0;

	add_tags($Vend::Cfg->{UserTag})
		unless $Vend::Tags_added++;

	$self->{TOPLEVEL} = 1 if ! $Initialized;

	$self->{OUT} = '';
    bless $self, $class;
	$Initialized = $self;
}

my %Documentation;
use vars '%myRefs';

%myRefs = (
     Alias           => \%Alias,
     addAttr         => \%addAttr,
     attrAlias       => \%attrAlias,
	 Documentation   => \%Documentation,
	 endHTML         => \%endHTML,
	 hasEndTag       => \%hasEndTag,
	 Implicit        => \%Implicit,
	 insertHTML	     => \%insertHTML,
	 insideHTML	     => \%insideHTML,
	 Interpolate     => \%Interpolate,
	 InvalidateCache => \%InvalidateCache,
	 lookaheadHTML   => \%lookaheadHTML,
	 Order           => \%Order,
	 PosNumber       => \%PosNumber,
	 PosRoutine      => \%PosRoutine,
	 replaceAttr     => \%replaceAttr,
	 replaceHTML     => \%replaceHTML,
	 Routine         => \%Routine,
);

sub do_tag {
	my $tag = shift;
#::logDebug("Parse-do_tag: tag=$tag caller=" . caller() . " args=" . ::uneval_it(\@_) );
	if (defined $Vend::Cfg->{AdminSub}{$tag}) { 
	
		if($Vend::restricted) {
			die errmsg(
					"Tag '%s' in execution-restricted area: %s",
					$tag,
					$Vend::restricted,
				);
		}
		elsif (! $Vend::admin) {
			die errmsg("Unauthorized for admin tag %s", $tag)
		}

	}

	die errmsg("Unauthorized for admin tag %s", $tag)
		if defined $Vend::Cfg->{AdminSub}{$tag} and
			($Vend::restricted or ! $Vend::admin);
	
	if (! defined $Routine{$tag}) {
        if (! $Alias{$tag}) {
            ::logError("Tag '$tag' not defined.");
            return undef;
        }
        $tag = $Alias{$tag};
	};
	if(
		( ref($_[-1]) && scalar @{$Order{$tag}} > scalar @_ ) 
	)
	{
		my $text;
		my $ref = pop(@_);
		$text = shift if $hasEndTag{$tag};
		my @args = @$ref{ @{$Order{$tag}} };
		push @args, $ref if $addAttr{$tag};
#::logDebug("Parse-do_tag: args now=" . ::uneval_it(\@args) );
		return &{$Routine{$tag}}(@args, $text || undef);
	}
	else {
		return &{$Routine{$tag}}(@_);
	}
}

sub resolve_args {
	my $tag = shift;
#::logDebug("resolving args for $tag, attrAlias = $attrAlias{$tag}");
	return @_ unless defined $Routine{$tag};
	my $ref = shift;
	my @list;
	if(defined $attrAlias{$tag}) {
		my ($k, $v);
		while (($k, $v) = each %{$attrAlias{$tag}} ) {
#::logDebug("checking alias $k -> $v");
			next unless defined $ref->{$k};
			$ref->{$v} = $ref->{$k};
		}
	}
	@list = @{$ref}{@{$Order{$tag}}};
	push @list, $ref if defined $addAttr{$tag};
	push @list, (shift || $ref->{body} || '') if $hasEndTag{$tag};
	return @list;
}

sub add_tags {
	return unless @_;
	my $ref = shift;
	my $area;
	no strict 'refs';
	foreach $area (keys %myRefs) {
		next unless $ref->{$area};
		if($area eq 'Routine') {
			for (keys %{$ref->{$area}}) {
				$myRefs{$area}->{$_} = $ref->{$area}->{$_};
			}
			next;
		}
		elsif ($area =~ /HTML$/) {
			for (keys %{$ref->{$area}}) {
				$myRefs{$area}->{$_} =
					defined $myRefs{$area}->{$_}
					? $ref->{$area}->{$_} .'|'. $myRefs{$area}->{$_}
					: $ref->{$area}->{$_};
			}
		}
		else {
			Vend::Util::copyref $ref->{$area}, $myRefs{$area};
		}
	}
	for (keys %{$ref->{Routine}}) {
		$Order{$_} = [] if ! $Order{$_};
		next if defined $PosNumber{$_};
		$PosNumber{$_} = scalar @{$Order{$_}};
	}
}

sub eof {
    shift->parse(undef);
}

sub text {
    my($self, $text) = @_;
	$self->{OUT} .= $text;
}

my %Monitor = ( qw( tag_ary 1 ) );

sub build_html_tag {
	my ($orig, $attr, $attrseq) = @_;
	$orig =~ s/\s+.*//s;
	for (@$attrseq) {
		$orig .= qq{ \U$_="} ; # syntax color "
		$attr->{$_} =~ s/"/\\"/g;
		$orig .= $attr->{$_};
		$orig .= '"';
	}
	$orig .= ">";
}

my %implicitHTML = (qw/checked CHECKED selected SELECTED/);

sub format_html_attribute {
	my($attr, $val) = @_;
	if(defined $implicitHTML{$attr}) {
		return $implicitHTML{$attr};
	}
	$val =~ s/"/&quot;/g;
	return qq{$attr="$val"};
}

sub resolve_if_unless {
	my $attr = shift;
	if(defined $attr->{'unless'}) {
		return '' if $attr->{'unless'} =~ /^\s*0?\s*$/;
		return '' if ! $attr->{'unless'};
		return 1;
	}
	elsif (defined $attr->{'if'}) {
		return '' if
			($attr->{'if'} and $attr->{'if'} !~ /^\s*0?\s*$/);
		return 1;
	}
	return '';
}

sub goto_buf {
	my ($name, $buf) = @_;
	if(! $name) {
		$$buf = '';
		return;
	}
	while($$buf =~ s!  .+?
							(
								(?:
								\[ label \s+ (?:name \s* = \s* ["']?)?	|
								<[^>]+? \s+ mv.label \s*=\s*["']?		|
								<[^>]+? \s+
									mv \s*=\s*["']? label
									[^>]*? \s+ mv.name\s*=\s*["']?		|
								<[^>]+? \s+ mv \s*=\s*["']? label  \s+  |
								)
								(\w+)
							|
								</body\s*>
							)
					!$1!ixs )
	{
			last if $name eq $2;
	}
	return;
	# syntax color "'
}

sub html_start {
    my($self, $tag, $attr, $attrseq, $origtext, $end_tag) = @_;
#::logDebug("HTML tag=$tag Interp='$Interpolate{$tag}' origtext=$origtext attributes:\n" . ::uneval($attr));
	$tag =~ tr/-/_/;   # canonical

	my $buf = \$self->{_buf};

	if (defined $Vend::Cfg->{AdminSub}{$tag}) { 
	
		if($Vend::restricted) {
			::logError(
				"Restricted tag (%s) attempted during restriction '%s'",
				$origtext,
				$Vend::restricted,
				);
			$self->{OUT} .= $origtext;
			return 1;
		}
		elsif (! $Vend::admin) {
			::response(
						get_locale_message (
							403,
							"Unauthorized for admin tag %s",
							$tag,
							)
						);
			return ($self->{ABORT} = 1);
		}

	}

	$end_tag = lc $end_tag;
#::logDebug("tag=$tag end_tag=$end_tag buf length " . length($$buf)) if $Monitor{$tag};
#::logDebug("attributes: ", %{$attr}) if $Monitor{$tag};
	my($tmpbuf);
    # $attr is reference to a HASH, $attrseq is reference to an ARRAY
	my($return_html);

	unless (defined $Routine{$tag}) {
		if(defined $Alias{$tag}) {
#::logDebug("origtext: $origtext");
			my $alias = $Alias{$tag};
			$tag =~ s/_/[-_]/g;
			$origtext =~ s/$tag/$alias/i
				or return 0;
			$$buf = $origtext . $$buf;
			return 1;
		}
		elsif ($tag eq 'urldecode') {
			$attr->{urldecode} = 1;
			$return_html = $origtext;
			$return_html =~ s/\s+.*//s;
		}
		else {
			$self->{OUT} .= $origtext;
			return 1;
		}
	}

	if(defined $InvalidateCache{$tag} and !$attr->{cache}) {
		$self->{INVALID} = 1;
	}

	my $trib;
	foreach $trib (@$attrseq) {
		# Attribute aliases
		if(defined $attrAlias{$tag} and $attrAlias{$tag}{$trib}) {
			my $new = $attrAlias{$tag}{$trib} ;
			$attr->{$new} = delete $attr->{$trib};
			$trib = $new;
		}
		elsif (0 and defined $Alias{$trib}) {
			my $new = $Alias{$trib} ;
			$attr->{$new} = delete $attr->{$trib};
			$trib = $new;
		}
		# Parse tags within tags, only works if the [ is the
		# first character.
		$attr->{$trib} =~ s/%([A-Fa-f0-9]{2})/chr(hex($1))/eg if $attr->{urldecode};
		next unless $attr->{$trib} =~ /\[\w+[-\w]*\s*[\000-\377]*\]/;

		my $p = new Vend::Parse;
		$p->parse($attr->{$trib});
		$attr->{$trib} = $p->{OUT};
		$self->{INVALID} += $p->{INVALID};
	}

	if($tag eq 'urldecode') {
		$self->{OUT} .= build_html_tag($return_html, $attr, $attrseq);
		return 1;
	}

	$attr->{enable_html} = 1 if $Vend::Cfg->{Promiscuous};
	$attr->{'decode'} = 1 unless defined $attr->{'decode'};
	$attr->{'reparse'} = 1 unless	defined $NoReparse{$tag}
								||	defined $attr->{'reparse'};
	$attr->{'undef'} = undef;

	my ($routine,@args);

	if ($attr->{OLD}) {
	# HTML old-style tag
		$attr->{interpolate} = 1 if defined $Interpolate{$tag};
		if(defined $PosNumber{$tag}) {
			if($PosNumber{$tag} > 1) {
				@args = split /\s+/, $attr->{OLD}, $PosNumber{$tag};
				push(@args, undef) while @args < $PosNumber{$tag};
			}
			elsif ($PosNumber{$tag}) {
				@args = $attr->{OLD};
			}
		}
		@{$attr}{ @{ $Order{$tag} } } = @args;
		$routine =  $PosRoutine{$tag} || $Routine{$tag};
	}
	else {
	# New style tag, HTML or otherwise
		$routine = $Routine{$tag};
		$attr->{interpolate} = 1
			if defined $Interpolate{$tag} and ! defined $attr->{interpolate};
		@args = @{$attr}{ @{ $Order{$tag} } };
	}
	$args[scalar @{$Order{$tag}}] = $attr if $addAttr{$tag};

	if($tag =~ /^[gb]o/) {
		if($tag eq 'goto') {
			return 1 if resolve_if_unless($attr);
			if(! $args[0]) {
				$$buf = '';
				$Initialized->{_buf} = '';
				$self->{ABORT} = 1
					if $attr->{abort};
				return ($self->{SEND} = 1);
			}
			goto_buf($args[0], \$Initialized->{_buf});
			$self->{ABORT} = 1;
			return 1;
		}
		elsif($tag eq 'bounce') {
			return 1 if resolve_if_unless($attr);
			if(! $attr->{href} and $attr->{page}) {
				$attr->{href} = Vend::Interpolate::tag_area($attr->{page});
			}
			$Vend::StatusLine = '' if ! $Vend::StatusLine;
			$Vend::StatusLine .= <<EOF if $attr->{target};
Window-Target: $attr->{target}
EOF
			$Vend::StatusLine .= <<EOF;
Status: 302 moved
Location: $attr->{href}
EOF
			$$buf = '';
			$Initialized->{_buf} = '';
			return ($self->{SEND} = 1);
		}
	}

#::logDebug("tag=$tag end_tag=$end_tag attributes:\n" . Vend::Util::uneval($attr)) if$Monitor{$tag};

	my $prefix = '';
	my $midfix = '';
	my $postfix = '';
	my @out;

	if($insertHTML{$end_tag}
		and ! $attr->{noinsert}
		and $tag =~ /^($insertHTML{$end_tag})$/) {
		$origtext =~ s/>\s*$//;
		@out = Text::ParseWords::shellwords($origtext);
		shift @out;
		@out = grep $_ !~ /^[Mm][Vv][=.]/, @out
			unless $attr->{showmv};
		if (defined $replaceAttr{$tag}
			and $replaceAttr{$tag}->{$end_tag}
			and	! $attr->{noreplace})
		{
			my $t = $replaceAttr{$tag}->{$end_tag};
			@out = grep $_ !~ /^($t)\b/i, @out;
			unless(defined $implicitHTML{$t}) {
				$out[0] .= qq{ \U$t="};
				$out[1] = defined $out[1] ? qq{" } . $out[1] : '"';
			}
			else { $midfix = ' ' }
		}
		else {
			$out[0] = " " . $out[0] . " "
				if $out[0];
		}
		if (@out) {
			$out[$#out] .= '>';
		}
		else {
			@out = '>';
		}
#::logDebug("inserted " . join "|", @out);
	}

	if($hasEndTag{$tag}) {
		my $rowfix;
		# Handle embedded tags, but only if interpolate is 
		# defined (always if using old tags)
		if (defined $replaceHTML{$end_tag}
			and $tag =~ /^($replaceHTML{$end_tag})$/
			and ! $attr->{noreplace} )
		{
			$origtext = '';
			$tmpbuf = find_html_end($end_tag, $buf);
			$tmpbuf =~ s:</$end_tag\s*>::;
			HTML::Entities::decode($tmpbuf) if $attr->{decode};
			$tmpbuf =~ tr/\240/ /;
		}
		else {
			@out = Text::ParseWords::shellwords($origtext);
			($attr->{showmv} and
					@out = map {s/^[Mm][Vv]\./mv-/} @out)
				or @out = grep ! /^[Mm][Vv][=.]/, @out;
			$out[$#out] =~ s/([^>\s])\s*$/$1>/;
			$origtext = join " ", @out;

			if (defined $lookaheadHTML{$tag} and ! $attr->{nolook}) {
				$tmpbuf = $origtext . find_html_end($end_tag, $buf);
				while($$buf =~ s~^\s*(<([A-Za-z][-A-Z.a-z0-9]*)[^>]*)\s+
								[Mm][Vv]\s*=\s*
								(['"]) \[?
									($lookaheadHTML{$tag})\b(.*?)
								\]?\3~~ix ) 
				{
					my $orig = $1;
					my $enclose = $4;
					my $adder = $5;
					my $end = lc $2;
					$tmpbuf .= "[$enclose$adder]"	.  $orig	.
								find_html_end($end, $buf)	.
								"[/$enclose]";
				}
			}
			# Syntax color '" 
			# GACK!!! No table row attributes in some editors????
			elsif (defined $rowfixHTML{$end_tag}
				and $tag =~ /^($rowfixHTML{$end_tag})$/
				and $attr->{rowfix} )
			{
				$rowfix = 1;
				$tmpbuf = '<tr>' . $origtext . find_html_end('tr', $buf);
#::logDebug("Tmpbuf: $tmpbuf");
			}
			elsif (defined $insideHTML{$end_tag}
					and ! $attr->{noinside}
					and $tag =~ /^($insideHTML{$end_tag})$/i) {
				$prefix = $origtext;
				$tmpbuf = find_html_end($end_tag, $buf);
				$tmpbuf =~ s:</$end_tag\s*>::;
				$postfix = "</$end_tag>";
				HTML::Entities::decode($tmpbuf) if $attr->{'decode'};
				$tmpbuf =~ tr/\240/ / if $attr->{'decode'};
			}
			else {
				$tmpbuf = $origtext . find_html_end($end_tag, $buf);
			}
		}

		$tmpbuf =~ s/%([A-Fa-f0-9]{2})/chr(hex($1))/eg if $attr->{urldecode};

		if ($attr->{interpolate}) {
			my $p = new Vend::Parse;
			$p->parse($tmpbuf);
			$tmpbuf =  $p->{OUT};
		}

		$tmpbuf =  $attr->{prepend} . $tmpbuf if defined $attr->{prepend};
		$tmpbuf .= $attr->{append}            if defined $attr->{append};

		if (! $attr->{reparse}) {
			$self->{OUT} .= $prefix . &{$routine}(@args,$tmpbuf) . $postfix;
		}
		elsif (! defined $rowfix) {
			$$buf = $prefix . &{$routine}(@args,$tmpbuf) . $postfix . $$buf
		}
		else {
			$tmpbuf = &{$routine}(@args,$tmpbuf);
			$tmpbuf =~ s|<tr>||i;
			$$buf = $prefix . $tmpbuf . $postfix . $$buf;
		}


	}
	else {
		if(! @out and $attr->{prepend} or $attr->{append}) {
			my @tmp;
			@tmp = Text::ParseWords::shellwords($origtext);
			shift @tmp;
			@tmp = grep $_ !~ /^[Mm][Vv][=.]/, @tmp
				unless $attr->{showmv};
			$postfix = $attr->{prepend} ? "<\U$end_tag " . join(" ", @tmp) : '';
			$prefix = $attr->{append} ? "<\U$end_tag " . join(" ", @tmp) : '';
		}
		if(! $attr->{interpolate}) {
			if(@out) {
				$self->{OUT} .= "<\U$end_tag ";
				if 		($out[0] =~ / > \s*$ /x ) { }   # End of tag, do nothing
				elsif	($out[0] =~ / ^[^"]*"$/x ) {     # End of tag
					$self->{OUT} .= shift(@out);
				}
				else {
					unshift(@out, '');
				}
			}
			$self->{OUT} .= $prefix . &$routine( @args ) . $midfix;
			$self->{OUT} .= join(" ", @out) . $postfix;
		}
		else {
			if(@out) {
				$$buf = "<\U$end_tag " . &$routine( @args ) . $midfix . join(" ", @out) . $$buf;
			}
			else {
				$$buf = $prefix . &$routine( @args ) . $postfix . $$buf;
			}
		}
	}

	$self->{SEND} = $attr->{'send'} || undef;
#::logDebug("Returning from $tag");
	return 1;

}

# syntax color '"

sub start {
	return html_start(@_) if $_[0]->{HTML};
    my($self, $tag, $attr, $attrseq, $origtext) = @_;
	$tag =~ tr/-/_/;   # canonical
	$tag = lc $tag;
	my $buf = \$self->{_buf};

	my($tmpbuf);
	if (defined $Vend::Cfg->{AdminSub}{$tag}) { 
	
		if($Vend::restricted) {
			::logError(
				"Restricted tag (%s) attempted during restriction '%s'",
				$origtext,
				$Vend::restricted,
				);
			$self->{OUT} .= $origtext;
			return 1;
		}
		elsif (! $Vend::admin) {
			::response(
						get_locale_message (
							403,
							"Unauthorized for admin tag %s",
							$tag,
							)
						);
			return ($self->{ABORT} = 1);
		}

	}

    # $attr is reference to a HASH, $attrseq is reference to an ARRAY
	unless (defined $Routine{$tag}) {
		if(defined $Alias{$tag}) {
			my $alias = $Alias{$tag};
			$tag =~ s/_/[-_]/g;
#::logDebug("origtext: $origtext tag=$tag alias=$alias");
			$origtext =~ s/$tag/$alias/i
				or return 0;
			$$buf = $origtext . $$buf;
			return 1;
		}
		else {
			$self->{OUT} .= $origtext;
			return 1;
		}
	}

	if(defined $InvalidateCache{$tag} and !$attr->{cache}) {
		$self->{INVALID} = 1;
	}

	my $trib;
	foreach $trib (@$attrseq) {
		# Attribute aliases
		if(defined $attrAlias{$tag} and $attrAlias{$tag}{$trib}) {
			my $new = $attrAlias{$tag}{$trib} ;
			$attr->{$new} = delete $attr->{$trib};
			$trib = $new;
		}
		# Parse tags within tags, only works if the [ is the
		# first character.
		next unless $attr->{$trib} =~ /\[\w+[-\w]*\s*[\000-\377]*\]/;

		my $p = new Vend::Parse;
		$p->parse($attr->{$trib});
		$attr->{$trib} = $p->{OUT};
		$self->{INVALID} += $p->{INVALID};
	}

	$attr->{enable_html} = 1 if $Vend::Cfg->{Promiscuous};
	$attr->{'reparse'} = 1
		unless (defined $NoReparse{$tag} || defined $attr->{'reparse'});

	my ($routine,@args);

	# Check for old-style positional tag
	if(!@$attrseq and $origtext =~ s/\[[-\w]+\s+//i) {
			$origtext =~ s/\]$//;
			$attr->{interpolate} = 1 if defined $Interpolate{$tag};
			if(defined $PosNumber{$tag}) {
				if($PosNumber{$tag} > 1) {
					@args = split /\s+/, $origtext, $PosNumber{$tag};
					push(@args, undef) while @args < $PosNumber{$tag};
				}
				elsif ($PosNumber{$tag}) {
					@args = $origtext;
				}
			}
			@{$attr}{ @{ $Order{$tag} } } = @args;
			$routine =  $PosRoutine{$tag} || $Routine{$tag};
	}
	else {
		$routine = $Routine{$tag};
		$attr->{interpolate} = 1
			if  defined $Interpolate{$tag} && ! defined $attr->{interpolate};
		@args = @{$attr}{ @{ $Order{$tag} } };
	}
	$args[scalar @{$Order{$tag}}] = $attr if $addAttr{$tag};

#::logDebug("Interpolate value now='$attr->{interpolate}'") if$Monitor{$tag};


#::logDebug(<<EOF) if $Monitor{$tag};
#tag=$tag
#routine=$routine
#has_end=$hasEndTag{$tag}
#attributes=@args
#interpolate=$attr->{interpolate}
#EOF

	if($tag =~ /^[gb]o/) {
		if($tag eq 'goto') {
			return 1 if resolve_if_unless($attr);
			if(! $args[0]) {
				$$buf = '';
				$Initialized->{_buf} = '';
				$self->{ABORT} = 1
					if $attr->{abort};
				return ($self->{SEND} = 1);
			}
			goto_buf($args[0], \$Initialized->{_buf});
			$self->{ABORT} = 1;
			$self->{SEND} = 1 if ! $Initialized->{_buf};
			return 1;
		}
		elsif($tag eq 'bounce') {
			return 1 if resolve_if_unless($attr);
			if(! $attr->{href} and $attr->{page}) {
				$attr->{href} = Vend::Interpolate::tag_area($attr->{page});
			}
			$Vend::StatusLine = '' if ! $Vend::StatusLine;
			$Vend::StatusLine .= "\n" if $Vend::StatusLine !~ /\n$/;
			$Vend::StatusLine .= <<EOF if $attr->{target};
Window-Target: $attr->{target}
EOF
			$Vend::StatusLine .= <<EOF;
Status: 302 moved
Location: $attr->{href}
EOF
			$$buf = '';
			$Initialized->{_buf} = '';
			$self->{SEND} = 1;
			return 1;
		}
	}

	if($hasEndTag{$tag}) {
		# Handle embedded tags, but only if interpolate is 
		# defined (always if using old tags)
#::logDebug("look end for $tag, buf=" . length($$buf) );
		$tmpbuf = find_matching_end($tag, $buf);
#::logDebug("FOUND end for $tag\nBuf " . length($$buf) . ":\n" . $$buf . "\nTmpbuf:\n$tmpbuf\n");
		if ($attr->{interpolate}) {
			my $p = new Vend::Parse;
			$p->parse($tmpbuf);
			$tmpbuf = $p->{ABORT} ? '' : $p->{OUT};
		}
		if($attr->{reparse} ) {
			$$buf = ($routine->(@args,$tmpbuf) || '') . $$buf;
		}
		else {
			$self->{OUT} .= &{$routine}(@args,$tmpbuf);
		}
	}
	elsif(! $attr->{interpolate}) {
		$self->{OUT} .= &$routine( @args );
	}
	else {
		$$buf = &$routine( @args ) . $$buf;
	}

	$self->{SEND} = $attr->{'send'} || undef;
#::logDebug("Returning from $tag");
	return 1;
}

sub end {
    my($self, $tag) = @_;
	my $save = $tag;
	$tag =~ tr/-/_/;   # canonical
	$self->{OUT} .= "[/$save]";
}

sub find_html_end {
    my($tag, $buf) = @_;
    my $out;
	my $canon;

    my $open  = "<$tag ";
    my $close = "</$tag>";
	($canon = $tag) =~ s/_/[-_]/g;

    $$buf =~ s!<$canon\s!<$tag !ig;
    $$buf =~ s!</$canon\s*>!</$tag>!ig;
    my $first = index($$buf, $close);
    return undef if $first < 0;
    my $int = index($$buf, $open);
    my $pos = 0;
#::logDebug("find_html_end: tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
    while( $int > -1 and $int < $first) {
        $pos   = $int + 1;
        $first = index($$buf, $close, $first + 1);
        $int   = index($$buf, $open, $pos);
#::logDebug("find_html_end: tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
    }
#::logDebug("find_html_end: tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
	return undef if $first < 0;
    $first += length($close);
#::logDebug("find_html_end (add close): tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
    $out = substr($$buf, 0, $first);
    substr($$buf, 0, $first) = '';
    return $out;
}

sub find_matching_end {
    my($tag, $buf) = @_;
    my $out;
	my $canon;

    my $open  = "[$tag ";
    my $close = "[/$tag]";
	($canon = $tag) =~ s/_/[-_]/g;

    $$buf =~ s!\[$canon\s![$tag !ig;
	# Syntax color ]
    $$buf =~ s!\[/$canon\]![/$tag]!ig;
    my $first = index($$buf, $close);
    if ($first < 0) {
		if($Gobble{$tag}) {
			$out = $$buf;
			$$buf = '';
			return $out;
		}
		return undef;
	}
    my $int = index($$buf, $open);
    my $pos = 0;
    while( $int > -1 and $int < $first) {
        $pos   = $int + 1;
        $first = index($$buf, $close, $first + 1);
        $int   = index($$buf, $open, $pos);
    }
    $out = substr($$buf, 0, $first);
    $first = $first < 0 ? $first : $first + length($close);
    substr($$buf, 0, $first) = '';
    return $out;
}

# Passed some string that might be HTML-style attributes
# or might be positional parameters, does the right thing
sub _find_tag {
	my ($buf, $attrhash, $attrseq) = (@_);
	return '' if ! $$buf;
	my $old = 0;
	my $eaten = '';
	my %attr;
	my @attrseq;
	while ($$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)\s*)||) {
		$eaten .= $1;
		my $attr = lc $2;
		$attr =~ tr/-/_/;
		my $val;
		$old = 0;
		# The attribute might take an optional value (first we
		# check for an unquoted value)
		if ($$buf =~ s|(^=\s*([^\"\'\]\s][^\]\s]*)\s*)||) {
			$eaten .= $1;
			$val = $2;
			HTML::Entities::decode($val);
		# or quoted by " or ' 
		} elsif ($$buf =~ s~(^=\s*([\"\'\`\|])(.*?)\2\s*)~~s) {
			$eaten .= $1;
			my $q = $2;
			$val = $3;
			HTML::Entities::decode($val);
			if ($q eq "`") {
				$val = Vend::Interpolate::tag_calc($val);
			}
			else {
				$q eq '|'
			    	and do {
						$val =~ s/^\s+//;
						$val =~ s/\s+$//;
					};
				$val =~ /__[A-Z]\w*[A-Za-z]__|\[.*\]/s
					and do {
						my $p = new Vend::Parse;
						$p->parse($val);
						$val = $p->{OUT};
					};
			}
		# truncated just after the '=' or inside the attribute
		} elsif ($$buf =~ m|^(=\s*)$| or
				 $$buf =~ m|^(=\s*[\"\'].*)|s) {
			$eaten = "$eaten$1";
			last;
		} else {
			# assume attribute with implicit value, which 
			# means in Interchange no value is set and the
			# eaten value is grown. Note that you should
			# never use an implicit tag when setting up an Alias.
			$old = 1;
		}
		next if $old;
		$attrhash->{$attr} = $val;
		push(@attrseq, $attr);
	}
	unshift(@$attrseq, @attrseq);
	return ($eaten);
}

# checks for implicit tags
# INT is special in that it doesn't get pushed on @attrseq
sub implicit {
	my($self, $tag, $attr) = @_;
	return ('interpolate', 1, 1) if $attr eq 'int';
	return ($attr, undef) unless defined $Implicit{$tag} and $Implicit{$tag}{$attr};
	my $imp = $Implicit{$tag}{$attr};
	return ($attr, $imp) if $imp =~ s/^$attr=//i;
	return ( $Implicit{$tag}{$attr}, $attr );
}

1;
__END__
