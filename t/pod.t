#!/usr/bin/perl -w

use lib '.'; use lib 't';
use WMTest; webmake_t_init("pod");
use Test; BEGIN { plan tests => 10 };

# ---------------------------------------------------------------------------

%patterns = (
  q{ <ul> <li> <a href="#NAME">NAME</a> <li>
  <a href="#DESCRIPTION">DESCRIPTION</a> </ul>},
  'pod_header_list',

  q{ <h1><a name="NAME">NAME</a></h1> <p> Blah foo etc. <p>},
  'pod_name',

  q{<hr /> <h1><a name="DESCRIPTION">DESCRIPTION</a></h1> <p>
   argh etc.},
  'pod_description',

  q{ <h1><a name="BAR_NAME">BAR_NAME</a></h1> <p>
   Blah bar etc. <p>
   <hr />
   <h1><a name="BAR_DESCRIPTION">BAR_DESCRIPTION</a></h1> <p>
   argh etc.},
  'bar_found',
);

%anti_patterns = (
  q{ <ul> <li> <a href="#BAR_NAME">BAR_NAME</a> <li>
  <a href="#BAR_DESCRIPTION">BAR_DESCRIPTION</a> </ul>},
  'anti_bar_header_list',
);

# ---------------------------------------------------------------------------

ok (wmrun ("-F -f data/$testname.wmk", \&patterns_run_cb));
ok_all_patterns();

# clean up some leftover tmp files
unlink ("pod2html-dircache");
unlink ("pod2html-itemcache");

