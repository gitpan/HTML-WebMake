#!/usr/bin/perl -w

use lib '.'; use lib 't';
use WMTest; webmake_t_init("perllib");
use Test; BEGIN { plan tests => 9 };

# ---------------------------------------------------------------------------

%patterns = (
q{
 <li>
Content: <strong>"foo"</strong>
</li>}, 'seen_foo',


q{
 <li>
Content: <strong>"__MainContentName"</strong>
</li>}, 'seen_main',


q{
 <li>
Content: <strong>"WebMake.GeneratorString"</strong>
</li>}, 'seen_genstring',

q{
<li>
  Content: <strong>"foo"</strong><br />
  <blockquote> <pre> <!--etsafe--> Foo!<!--/etsafe--> </pre>
  </blockquote> </li> }, 'seen_foo_value',

);

# ---------------------------------------------------------------------------

ok (wmrun ("-F -f data/$testname.wmk", \&patterns_run_cb));
checkfile ($testname."_2.html", \&patterns_run_cb);
ok_all_patterns();

