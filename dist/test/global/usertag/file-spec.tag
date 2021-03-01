UserTag test-file-spec Routine <<EOR
sub {
    use Vend::File qw( catfile file_name_is_absolute );

    my $get_path = sub {
        local $ENV{PATH} = $_[0];
        join '|', Vend::File::path()
    };

    join "\n",
        "catfile a b c --> " . catfile('a', 'b', 'c'),
        "catdir a b c --> " . Vend::File::catdir('a', 'b', 'c'),
        "canonpath a/b//../../c --> " . Vend::File::canonpath('a/b//../../c'),
        "file_name_is_absolute a/b/c --> " . file_name_is_absolute('a/b/c'),
        "file_name_is_absolute a:b/c --> " . file_name_is_absolute('a:b/c'),
        "file_name_is_absolute /a/b/c --> " . file_name_is_absolute('/a/b/c'),
        "path of test PATH --> " . $get_path->('/usr/local/bin:/usr/bin:/bin'),
        "\n"
}
EOR
