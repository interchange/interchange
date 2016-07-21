use strict;
use warnings;
use lib 'lib';
use Test::More;
use Vend::Order;

is( Vend::Order::guess_cc_type(''), '', 'credit card: blank' );

is( Vend::Order::guess_cc_type('4123456789012'),    'visa', 'credit card: visa 13' );
is( Vend::Order::guess_cc_type('4123456789012345'), 'visa', 'credit card: visa 16' );

is( Vend::Order::guess_cc_type('5123456789012345'), 'mc', 'credit card: mc, 51xx' );
is( Vend::Order::guess_cc_type('5512345678901234'), 'mc', 'credit card: mc, 55xx' );
is( Vend::Order::guess_cc_type('2221001234567890'), 'mc', 'credit card: mc BIN-2 #1' );
is( Vend::Order::guess_cc_type('2720991234567890'), 'mc', 'credit card: mc BIN-2 #2' );
is( Vend::Order::guess_cc_type('2700991234567890'), 'mc', 'credit card: mc BIN-2 #3' );

is( Vend::Order::guess_cc_type('5012341234123412'), 'other', 'non-mc similarity #1');
is( Vend::Order::guess_cc_type('2121001234567890'), 'other', 'non-mc similarity #2');
is( Vend::Order::guess_cc_type('2820991234567890'), 'other', 'non-mc similarity #3');

is( Vend::Order::guess_cc_type('3001234567890112'), 'discover', 'credit card: discover diners club 300xx' );
is( Vend::Order::guess_cc_type('3095123456789012'), 'discover', 'credit card: discover diners club 3095xx' );
is( Vend::Order::guess_cc_type('3612345678901212'), 'discover', 'credit card: discover diners club 36xx' );
is( Vend::Order::guess_cc_type('6011123456789012'), 'discover', 'credit card: discover 6011xx' );
is( Vend::Order::guess_cc_type('6441234567890123'), 'discover', 'credit card: discover 644xx' );
is( Vend::Order::guess_cc_type('6512345678901234'), 'discover', 'credit card: discover 65xx' );
is( Vend::Order::guess_cc_type('6221234567890123'), 'discover', 'credit card: discover chinaunionpay 622xx, no country' );
is( Vend::Order::guess_cc_type('6251234567890123'), 'discover', 'credit card: discover chinaunionpay 625xx, no country' );
# not setting Values to test country

is( Vend::Order::guess_cc_type('341234567890123'), 'amex', 'credit card: amex 34xx' );
is( Vend::Order::guess_cc_type('371234567890123'), 'amex', 'credit card: amex 37xx' );

# defunct
#is( Vend::Order::guess_cc_type('36123456789012'), 'dinersclub', 'credit card: dinersclub 36' );
#is( Vend::Order::guess_cc_type('30012345678901'), 'dinersclub', 'credit card: dinersclub 300' );
#is( Vend::Order::guess_cc_type('38123456789012'), 'carteblanche', 'credit card: carteblanche' );

is( Vend::Order::guess_cc_type('201412345678901'), 'enroute', 'credit card: enroute 2014xx' );
is( Vend::Order::guess_cc_type('214912345678901'), 'enroute', 'credit card: enroute 2149xx' );

is( Vend::Order::guess_cc_type('3123456789012345'), 'jcb', 'credit card: jcb' );
is( Vend::Order::guess_cc_type('3213112345678901'), 'jcb', 'credit card: jcb 32131xx' );
is( Vend::Order::guess_cc_type('3180012345678901'), 'jcb', 'credit card: jcb 31800xx' );

is( Vend::Order::guess_cc_type('4903020123456789012'), 'switch', 'credit card: switch' );
is( Vend::Order::guess_cc_type('564182123456789012'),  'switch', 'credit card: switch 564182xx' );
is( Vend::Order::guess_cc_type('633300123456789012'),  'switch', 'credit card: switch 63300xx' );
is( Vend::Order::guess_cc_type('675900123456789012'),  'switch', 'credit card: switch 675900xx' );

is( Vend::Order::guess_cc_type('5610001234567890'), 'bankcard', 'credit card: bankcard 5610xx' );
is( Vend::Order::guess_cc_type('5602211234567890'), 'bankcard', 'credit card: bankcard 56022xx' );

is( Vend::Order::guess_cc_type('633450123456789012'), 'solo', 'credit card: solo 633450xx' );
is( Vend::Order::guess_cc_type('676700123456789012'), 'solo', 'credit card: solo 676700xx' );

is( Vend::Order::guess_cc_type('630409123456789012'), 'laser', 'credit card: laser 630409xx' );
is( Vend::Order::guess_cc_type('6771123456789012'),   'laser', 'credit card: laser 6771xx' );


is( Vend::Order::guess_cc_type('123'), 'other', 'credit card: other' );

done_testing();
