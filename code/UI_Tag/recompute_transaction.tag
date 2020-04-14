UserTag recompute-transaction Interpolate 0
UserTag recompute-transaction Routine <<EOR
sub {
    my $order_number = $CGI->{order_number}
        or die "No transaction number.\n";

    my $tdb = $Db{transactions}
        or die "Cannot find transaction database.\n";
    my $odb = $Db{orderline}
        or die "Cannot find orderline database.\n";
    my $udb = $Db{userdb}
        or die "Cannot find user database.\n";

    my $trec = $tdb->row_hash($order_number)
        or die errmsg("Invalid transaction number: %s", $order_number);

    my $date = $Tag->time({ body => '%c' });

    my $otab = $odb->name();
    my $on_quoted = $odb->quote($order_number, 'order_number');

    my $q = "select * from $otab where order_number = $on_quoted";

    my $oary = $odb->query({ sql => $q, hashref => 1})
        or die errmsg(
                "Problem with orderline query for order number: %s",
                $order_number);

    # In case you want to recompute shipping
    my $smode = $trec->{shipmode};
    $smode =~ s/\s+.*//;

    my @updates;
    @$Items = ();
    my $nitems = 0;
    my $subt = 0;
    my $mv_ip = 0;
    my @ol_flds;
    for my $orec (@$oary) {
        @ol_flds or
            @ol_flds = grep { $_ ne 'code' } keys %$orec;
        my $nsub = $orec->{quantity} * $orec->{price};
        if($nsub != $orec->{subtotal}) {
            push @updates, [ $orec->{code}, { subtotal => $nsub } ];
        }
        $nitems += $orec->{quantity};
        $subt += $nsub;
        $orec->{_ol_pk} = $orec->{code};
        $orec->{code} = delete $orec->{sku};
        $orec->{mv_price} = ">>$orec->{price}";
        $orec->{subtotal} = $nsub;
        $orec->{nontaxable} = !$orec->{taxable}
            if exists $orec->{taxable};
        $orec->{mv_ip} = $mv_ip++;
        push @$Items, $orec;
    }

    if($CGI->{recompute_tax}) {
#Debug("tax prior to recompute: $trec->{salestax}");
        my $before_tax = $trec->{salestax};
        my @vf = keys %$trec;
        my %tmp;
        @tmp{@vf} = @$Values{@vf};
        @$Values{@vf} = @$trec{@vf};
        local $::Scratch->{tag_tax_lookup_estimate_mode};
        $Tag->assign({ shipping => $trec->{shipping}, });
        my $stax = $Tag->salestax( { noformat => 1 });
        $Tag->assign({ clear => 1, });
        $trec->{salestax} = $stax;
#Debug("tax after recompute: $trec->{salestax}");
        for my $item (@$Items) {
            $item->{sku} = $item->{code};
            my $code = $item->{_ol_pk};
            my %row;
            @row{@ol_flds} = @$item{@ol_flds};
            $odb->set_slice($code, \%row);
        }
        @$Values{@vf} = @tmp{@vf};
    }
    else {
        for(@updates) {
            $odb->set_slice(@$_);
        }
    }

    @$Items = ();

    $trec->{subtotal} = $subt;
    $trec->{nitems} = $nitems;
    $trec->{total_cost} = 0;
    for(qw/subtotal salestax shipping handling/) {
        $trec->{total_cost} += $trec->{$_};
    }

    my $code = delete $trec->{code};
    $tdb->set_slice($code, $trec);
    $CGI->{mv_data_table} = 'transactions';
    $Tag->warnings("Recomputed transaction $order_number");
}
EOR
