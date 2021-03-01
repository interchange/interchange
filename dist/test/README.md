# Interchange unit test harness catalog

This catalog is used to test Interchange's internal functioning, for developers to be warned by regressions in any work they do on the Interchange core.

Here are the steps to set it up and use it.

## Copy the catalog

Copy the catalog template from a Git checkout of the Interchange source code. For example, if you want to call the test catalog `ictest`:

```
cp -Rp /path/to/interchange-checkout/dist/test /path/to/your/catalogs/ictest
```

## Configure interchange.cfg

Add a line like this to your `interchange.cfg` file:

```
Catalog ictest /path/to/your/catalogs/ictest /cgi-bin/ictest
```

Uncomment this line in your `interchange.cfg` file:

```
Variable  DEBUG  1
```

so that the following directives are active in the block beginning with `ifdef @DEBUG`:

```
# A few simple tests ...
GlobalSub sub test_global_sub { return 'Test of global subroutine OK.' }
Variable  TEST_VARIABLE  Test of global variable OK.
```

And add right after that:

```
include catalogs/ictest/global/usertag/*.tag
```

## Configure database

Edit `products/variable.txt` to point to an existing SQL database to use for the test. Make sure not to mangle the single tab character after SQLDSN! For example, to use a PostgreSQL database named `ictest`, you should have in that file:

```
SQLDSN	dbi:Pg:dbname=ictest
```

## Copy CGI link program

Copy and already-built vlink or tlink program:

```
cd /path/to/cgi-bin
cp -p strap ictest
```

## Restart Interchange daemon

```
/path/to/your/interchange/bin/interchange -r
```

## Run the tests

In a web browser, visit the catalog. The URL for your other catalogs should work, with the catalog name modified, for example:

```
http://localhost.localdomain/cgi-bin/ictest
```

## Reload the test page

You'll need to run the test twice in a row in the same session so that any tests depending on previously-set cookies or session data will work.

## Success?

If the tests all ran successfully, you should see only `OK` next to each test number run, like this:

```
OK 000001 OK 000002 OK 000003 OK 000004 OK 000005
OK 000006 OK 000007 OK 000008 OK 000009 OK 000010
OK 000011 OK 000012 OK 000013 OK 000014 OK 000015
OK 000016 OK 000017 OK 000018 OK 000019 OK 000020
OK 000021 OK 000022 OK 000023 OK 000024 OK 000025
OK 000026 OK 000027 OK 000028 OK 000029 OK 000030
OK 000031 OK 000032 OK 000033 OK 000034 OK 000035
OK 000036 OK 000037 OK 000038 OK 000039 OK 000040
OK 000041 OK 000042 OK 000043 OK 000044 OK 000045
OK 000046 OK 000047 OK 000048 OK 000049 OK 000050
OK 000051 OK 000052 OK 000053 OK 000054 OK 000055
OK 000056 OK 000057 OK 000058 OK 000059 OK 000060
OK 000061 OK 000062 OK 000063 OK 000064 OK 000065
OK 000066 OK 000067 OK 000068 OK 000069 OK 000070
OK 000071 OK 000072 OK 000073 OK 000074 OK 000075
OK 000076 OK 000077 OK 000078 OK 000079 OK 000080
OK 000081 OK 000082 OK 000083 OK 000084 OK 000085
OK 000086 OK 000087 OK 000088 OK 000089 OK 000090
OK 000091 OK 000092 OK 000093 OK 000094 OK 000095
OK 000096 OK 000097 OK 000098 OK 000099 OK 000100
OK 000101 OK 000102 OK 000103 OK 000104 OK 000105
OK 000106 OK 000107 OK 000108 OK 000109 OK 000110
OK 000111 OK 000112 OK 000113 OK 000114 OK 000115
OK 000116 OK 000117 OK 000118 OK 000119 OK 000120
OK 000121 OK 000122 OK 000123 OK 000124 OK 000125
OK 000126 OK 000127 OK 000128 OK 000129 OK 000130
OK 000131 OK 000132 OK 000133 OK 000134 OK 000135
OK 000136 OK 000137 OK 000138 OK 000139 OK 000140
OK 000141 OK 000142 OK 000143 OK 000144 OK 000145
OK 000146 OK 000147 OK 000148 OK 000149 OK 000150
OK 000151 OK 000152 OK 000153 OK 000154 OK 000155
OK 000156 OK 000157 OK 000158 OK 000159 OK 000160
OK 000161 OK 000162 OK 000163 OK 000164 OK 000165
OK 000166 OK 000167 OK 000168 OK 000169 OK 999999
```

If any test fails you will see `NOT OK` by the test number and an explanation of the expected vs. received output to help you troubleshoot the problem.

Happy testing!
