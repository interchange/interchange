
UserTag set-click Order name page action extra
UserTag set-click PosNumber 4
UserTag set-click Routine <<EOR
sub {
    my ($name, $page, $action, $extra) = @_;
    $page = $name unless $page;
    $action = 'return' unless $action;
    $extra = '' unless $extra;
    $Vend::Session->{scratch}{$name} = <<EOS; 
mv_todo=$action
mv_nextpage=$page
$extra
EOS
    return qq{<INPUT TYPE="hidden" NAME="mv_click_map" VALUE="$name">};
}
EOR

