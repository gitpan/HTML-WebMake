#!/usr/bin/perl -w

use lib '.'; use lib 't';
use WMTest; webmake_t_init("sitemap_with_metatable");
use Test; BEGIN { plan tests => 9 };

# ---------------------------------------------------------------------------

%patterns = (

  q{
</li>
<li>
 <em>[story_2.txt.abstract = "Story 2, just another story."]</em> 
</li>
<li>
 <em>[story_2.txt.score = "20"]</em> 
</li>
<li>
 <em>[story_2.txt.section = "Technology"]</em> 
</li>
<li>
 <p>
 <a href="../data/contentsfind.data/dir1/bar.txt">This is Bar</a>: Abstract for 
bar<br />
 <em>[score: 30, name: dir1/bar.txt, is_node: 0]</em> 
</p>
 
</li>

  },
'full_map_bar_under_story_2',




  q{
 <a href="../log/sitemap_with_metatable_story_4.html">Story 4, zzzzzzz</a>: Story 4, incredibly boring.<br />
 <em>[score: 999, name: story_4.txt, is_node: 1]</em> <ul>
 <li>
 <em>[story_4.txt.abstract = "Story 4, incredibly boring."]</em>
</li>
<li>
 <em>[story_4.txt.section = "Business"]</em>
</li>
<li>
 <em>[story_4.txt.title = "Story 4, zzzzzzz"]</em>
</li>
<li>
 <em>[story_4.txt.score = "999"]</em>
</li>
<li>
 <p>
 <a href="../data/contentsfind.data/dir2/dir2a/baz.txt">This is Baz</a>: Abstract for baz<br />
 <em>[score: 20, name: dir2/dir2a/baz.txt, is_node: 0]</em>

  }, 'full_map_baz_under_story_4',


  q{<li> <p> <a href="../log/sitemap_with_metatable_story_2.html">Story
 2, blah blah</a>: Story 2, just another story.<br /> <em>[score:
 20, name: story_2.txt, is_node: 1]</em> <ul> <li> <p>
 <a href="../data/contentsfind.data/dir1/bar.txt">This
 is Bar</a>: Abstract for bar<br />
 <em>[score: 30, name: dir1/bar.txt, is_node: 0]</em> </p> </li> </ul>
 </p> </li>},
  'small_map_bar_under_story_2',


  q{
   
 <a href="../log/sitemap_with_metatable_story_5.html">Story 5, zzz blah blah</a>: Story 5, nothing much here.<br />
 <em>[score: 21, name: story_5.txt, is_node: 0]</em>
</p>
  
</li>
<li>
 <p>
 <a href="../data/contentsfind.data/foo.txt">This is Foo</a>: Abstract for foo<br />
 <em>[score: 45, name: foo.txt, is_node: 0]</em> 
</p>
                                                                                  </li> 
<li>
 <p>
 <a href="../log/sitemap_with_metatable_map.html">(Untitled)</a>: <br />
 <em>[score: 50, name: mainsitemap, is_node: 0]</em>
</p>
</li>
<li>
 <p>
 <a href="../log/sitemap_with_metatable_fullmap.html">(Untitled)</a>: <br />
 <em>[score: 50, name: fullsitemap, is_node: 0]</em>
</p>

</li>
<li>
 <p>
 <a href="../log/sitemap_with_metatable_story_4.html">Story 4, zzzzzzz 
    
  },
  'small_map_foo_between_5_and_4',

);

# ---------------------------------------------------------------------------

ok (wmrun ("-F -f data/$testname.wmk", \&patterns_run_cb));
checkfile ($testname."_map.html", \&patterns_run_cb);
checkfile ($testname."_fullmap.html", \&patterns_run_cb);
# etc.
ok_all_patterns();

