#!/usr/bin/perl -w

use lib '.'; use lib 't';
use WMTest; webmake_t_init("example_sitemap");
use Test; BEGIN { plan tests => 13 };

# ---------------------------------------------------------------------------

%patterns = (
  q{
<li>
 <em>[story_4.txt.title = "Story 4, zzzzzzz"]</em> 
</li>
<li>
 <em>[story_4.txt.score = "999"]</em> 
</li>
 
</ul>
 
</p>
 
</li>
 
</ul>
 
</p>
 
</li>
<hr />
<p>
 <em>Sorry about the crappy 
  }, 'full_map_bot',


q{
 <a href="../log/example_sitemap_story_6.html">Story 6, blah blah</a>: Story 6, ju
st another story.<br />
 <em>[score: 20, name: story_6.txt, is_node: 1]</em> <ul>
 <li>
 <em>[story_6.txt.score = "20"]</em> 
</li>
<li>
 <em>[story_6.txt.abstract = "Story 6, just another story."]</em> 
</li>
<li>
 <em>[story_6.txt.section = "World"]</em> 
</li>
<li>
 <em>[story_6.txt.title = "Story 6, blah blah"]</em> 
</li>
 
</ul> }, 'full_map_mid', 


  q{This is story 1.},
  'story_1_body',


  q{Breaking news! this is story 3.},
  'story_3_body',

 q{<a href="../log/example_sitemap_story_3.html">Hot! story 3, etc etc.</a><br />
 <p> Story 3, the highest-scored story.  </p> </li> <li>
 <a href="../log/example_sitemap_story_1.html">Story 1, blah blah</a><br />
 <p> Story 1, just another story.  </p> </li> <li>
 <a href="../log/example_sitemap_story_2.html">Story 2, blah blah</a><br />
 <p> Story 2, just another story.  </p>},
  'index_ordering',

q{
<li> <p> <a href="../log/example_sitemap.html">WebMake
 Sample: a news site</a>: some old news site<br />
 <em>[score: 50, name: index_chunk, is_node: 1]</em> <ul> <li>
 <em>[index_chunk.title = "WebMake Sample: a news site"]</em> </li> <li>
 <em>[index_chunk.abstract = "some old news site"]</em> </li> <li>
 <p> <a href="../log/example_sitemap_story_3.html">Hot!
 story 3, etc etc.</a>: Story 3, the highest-scored story.<br />
 <em>[score: 10, name: story_3.txt, is_node: 1]</em> <ul>
},
  'full_map_top',


);

# ---------------------------------------------------------------------------

ok (wmrun ("-F -f data/$testname.wmk", \&patterns_run_cb));
checkfile ($testname."_map.html", \&patterns_run_cb);
checkfile ($testname."_fullmap.html", \&patterns_run_cb);
checkfile ($testname."_story_1.html", \&patterns_run_cb);
checkfile ($testname."_story_3.html", \&patterns_run_cb);
# etc.
ok_all_patterns();

