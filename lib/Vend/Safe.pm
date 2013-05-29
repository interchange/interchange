# Vend::Safe - utility methods for handling character encoding
#
# Copyright (C) 2009 Interchange Development Group
# Copyright (C) 2009 David Christensen <david@endpoint.com>
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

# 2013 update by Peter Motschmann <pnm3@optonline.com>:
# Integrated old version of Safe (2.07) directly into Vend::Safe because
# new versions of Safe do not play nice with Interchange. Now we can go to any
# version of perl without fear of Safe upgrades wrecking the site.

package Vend::Safe;
use 5.003_11;

use strict;
use warnings;

our $VERSION = "2.07";

use Vend::CharSet;
use Carp;

use Opcode 1.01, qw(
    opset opset_to_ops opmask_add
    empty_opset full_opset invert_opset verify_opset
    opdesc opcodes opmask define_optag opset_to_hex
);

my $default_root  = 0;
my $default_share = ['*_']; #, '*main::'];

sub new {
    my($class, $root, $mask) = @_;
    my $obj = {};
    bless $obj, $class;

    if (defined($root)) {
        croak "Can't use \"$root\" as root name"
            if $root =~ /^main\b/ or $root !~ /^\w[:\w]*$/;
        $obj->{Root}  = $root;
        $obj->{Erase} = 0;
    }
    else {
        $obj->{Root}  = "Safe::Root".$default_root++;
        $obj->{Erase} = 1;
    }

    # use permit/deny methods instead till interface issues resolved
    # XXX perhaps new Safe 'Root', mask => $mask, foo => bar, ...;
    croak "Mask parameter to new no longer supported" if defined $mask;
    $obj->permit_only(':default');

    # We must share $_ and @_ with the compartment or else ops such
    # as split, length and so on won't default to $_ properly, nor
    # will passing argument to subroutines work (via @_). In fact,
    # for reasons I don't completely understand, we need to share
    # the whole glob *_ rather than $_ and @_ separately, otherwise
    # @_ in non default packages within the compartment don't work.
    $obj->share_from('main', $default_share);
    Opcode::_safe_pkg_prep($obj->{Root});

    $class->initialize_safe_compartment($obj);

    return $obj;
}

sub initialize_safe_compartment {
    my ($class, $compartment) = @_;

    # force load of the unicode libraries in global perl
    qr{\x{0100}i};

    my $mask = $compartment->mask;
    $compartment->deny_only(); # permit everything

    # add custom shared variables for unicode support
    $compartment->share_from('main', ['&utf8::SWASHNEW', '&utf8::SWASHGET']);

    # preload utf-8 stuff in compartment
    $compartment->reval('qr{\x{0100}}i');
    $@ and ::logError("Failed activating implicit UTF-8 in Safe container: %s", $@);

    # revive original opmask
    $compartment->mask($mask);

    # check and see if it worked, if not, then we might have problems later
    $compartment->reval('qr{\x{0100}}i');

    $@ and ::logError("Failed compiling UTF-8 regular expressions in a Safe compartment with restricted opcode mask.  This may affect code in perl or calc blocks in your pages if you are processing UTF-8 strings in them.  Error: %s", $@);
}

sub DESTROY {
    my $obj = shift;
    $obj->erase('DESTROY') if $obj->{Erase};
}

sub erase {
    my ($obj, $action) = @_;
    my $pkg = $obj->root();
    my ($stem, $leaf);

    no strict 'refs';
    $pkg = "main::$pkg\::";
    ($stem, $leaf) = $pkg =~ m/(.*::)(\w+::)$/;

    my $stem_symtab = *{$stem}{HASH};

    my $leaf_glob   = $stem_symtab->{$leaf};
    my $leaf_symtab = *{$leaf_glob}{HASH};
    %$leaf_symtab = ();

    if ($action and $action eq 'DESTROY') {
        delete $stem_symtab->{$leaf};
    }
    else {
        $obj->share_from('main', $default_share);
    }
    1;
}

sub reinit {
    my $obj= shift;
    $obj->erase;
    $obj->share_redo;
}

sub root {
    my $obj = shift;
    croak("Safe root method now read-only") if @_;
    return $obj->{Root};
}

sub mask {
    my $obj = shift;
    return $obj->{Mask} unless @_;
    $obj->deny_only(@_);
}

# v1 compatibility methods
sub trap   { shift->deny(@_)   }
sub untrap { shift->permit(@_) }

sub deny {
    my $obj = shift;
    $obj->{Mask} |= opset(@_);
}
sub deny_only {
    my $obj = shift;
    $obj->{Mask} = opset(@_);
}

sub permit {
    my $obj = shift;
    # XXX needs testing
    $obj->{Mask} &= invert_opset opset(@_);
}
sub permit_only {
    my $obj = shift;
    $obj->{Mask} = invert_opset opset(@_);
}

sub dump_mask {
    my $obj = shift;
    print opset_to_hex($obj->{Mask}),"\n";
}

sub share {
    my($obj, @vars) = @_;
    $obj->share_from(scalar(caller), \@vars);
}

sub share_from {
    my $obj = shift;
    my $pkg = shift;
    my $vars = shift;
    my $no_record = shift || 0;
    my $root = $obj->root();
    croak("vars not an array ref") unless ref $vars eq 'ARRAY';
    no strict 'refs';
    # Check that 'from' package actually exists
    croak("Package \"$pkg\" does not exist")
        unless keys %{"$pkg\::"};
    my $arg;
    foreach $arg (@$vars) {
    # catch some $safe->share($var) errors:
    croak("'$arg' not a valid symbol table name")
        unless $arg =~ /^[\$\@%*&]?\w[\w:]*$/
            or $arg =~ /^\$\W$/;
    my ($var, $type);
    $type = $1 if ($var = $arg) =~ s/^(\W)//;
    # warn "share_from $pkg $type $var";
    *{$root."::$var"} = (!$type)       ? \&{$pkg."::$var"}
              : ($type eq '&') ? \&{$pkg."::$var"}
              : ($type eq '$') ? \${$pkg."::$var"}
              : ($type eq '@') ? \@{$pkg."::$var"}
              : ($type eq '%') ? \%{$pkg."::$var"}
              : ($type eq '*') ?  *{$pkg."::$var"}
              : croak(qq(Can't share "$type$var" of unknown type));
    }
    $obj->share_record($pkg, $vars) unless $no_record or !$vars;
}

sub share_record {
    my $obj = shift;
    my $pkg = shift;
    my $vars = shift;
    my $shares = \%{$obj->{Shares} ||= {}};
    # Record shares using keys of $obj->{Shares}. See reinit.
    @{$shares}{@$vars} = ($pkg) x @$vars if @$vars;
}

sub share_redo {
    my $obj = shift;
    my $shares = \%{$obj->{Shares} ||= {}};
    my($var, $pkg);
    while(($var, $pkg) = each %$shares) {
        # warn "share_redo $pkg\:: $var";
        $obj->share_from($pkg,  [ $var ], 1);
    }
}

sub share_forget {
    delete shift->{Shares};
}

sub varglob {
    my ($obj, $var) = @_;
    no strict 'refs';
    return *{$obj->root()."::$var"};
}

sub reval {
    my ($obj, $expr, $strict) = @_;
    my $root = $obj->{Root};

    # Create anon sub ref in root of compartment.
    # Uses a closure (on $expr) to pass in the code to be executed.
    # (eval on one line to keep line numbers as expected by caller)
    my $evalcode = sprintf('package %s; sub { eval $expr; }', $root);
    my $evalsub;

    if ($strict) { use strict; $evalsub = eval $evalcode; }
    else         {  no strict; $evalsub = eval $evalcode; }

    return Opcode::_safe_call_sv($root, $obj->{Mask}, $evalsub);
}

sub rdo {
    my ($obj, $file) = @_;
    my $root = $obj->{Root};

    my $evalsub = eval
        sprintf('package %s; sub { do $file }', $root);
    return Opcode::_safe_call_sv($root, $obj->{Mask}, $evalsub);
}

1;
__END__
