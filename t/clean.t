#!/usr/bin/perl -w

use lib '.'; use lib 't';
use WMTest; webmake_t_init("clean");
use Test; BEGIN { plan tests => 3 };

# ---------------------------------------------------------------------------

%patterns = (

q{foo
 <p>
  <h1> next foo </h1>
   foo
   <p>
    <hr />}, 'foo'
);

# ---------------------------------------------------------------------------

ok (wmrun ("-F -f data/$testname.wmk", \&patterns_run_cb));
ok_all_patterns();

