#!/usr/bin/perl -w

use lib '.'; use lib 't';
use WMTest; webmake_t_init("ettextmarkup");
use Test; BEGIN { plan tests => 37 };

# ---------------------------------------------------------------------------

%patterns = (
  q{<em>This is protected HTML &amp; should be OK.</em><hr /> <hr /> <hr />},
  'protected',

  q{<p> Non-bold again!
  <em>This is protected HTML &amp; should be OK.</em><hr /> <hr /> <hr />
  Still part of the Non-bold para, right?
  </p>},
  'etsafe_para_preserve',

  q{<p> Test for HR conversion.
  </p>
  <hr />
  <p> End of HR test.
  </p>},
  'hr',

  q{ just see if &amp; sign handling is OK. &amp; B&amp;N B&N -- lovely.
  Now as raw signs: &amp; sign handling &amp; B&N.  </p>},
  'amps',

  q{<p> What about leaving &amp; entity references as they should be? Or
  2 levels of same? &amp;amp; </p>},
  'keepamps',

  q{<table> <tr>
    <td valign="top"> <p> this is on the left </p> </td>
    <td width="99%" valign="top"> <p> This is the main paragraph body.
    </p> </td>
    </tr> </table>},
  'etleft',

  q{<table> <tr>
    <td width="99%" valign="top"> <p> This is the main paragraph body.
    </p> </td>
    <td valign="top"> <p> this is on the right </p> </td>
    </tr> </table>},
  'etright',

  q{<p> This is a list: </p> <ul> <li> <p> foo </p> </li>
  <li> <p> bar </p> </li> <li> <p> baz </p> </li> </ul>},
  'list',

  q{<blockquote> <p> This should be reproduced as a blockquote text segment,
  because it's indented.
  </p> </blockquote>},		# fix vim: '
  'block1',

  q{<blockquote> <p> This too.
  </p> </blockquote>},
  'block2',

  q{<h3>A H3 HEADING</h3></a>
  <p> Some text.
  </p>},
  'h3',

  q{<h2>A H2 HEADING WITH A LINE</h2></a>
  <p> More text.
  </p>},
  'h21',

  q{<h1>A H1 HEADING WITH EQUALS SIGNS</h1></a>
  <p> Guess what's here then.
  </p>},		# fix vim: '
  'h1',

  q{<h2>And Yet Another H2 Heading</h2></a>
  <p> Pretty easy, this!
  </p>},
  'h22',

  q{<blockquote> <p> &Agrave; &Aring; &Atilde; &Auml; &Ccedil; &ETH; &Eacute;
  &Ecirc; &Egrave; &Euml; &Iacute; &Icirc; &Igrave; &Iuml; &Ntilde;
  &Oacute; &Ocirc; &Ograve; &Oslash; &Otilde;
  &Ouml; &THORN; &Uacute; &Ucirc; &Ugrave; &Uuml; &Yacute; &aacute;
  &acirc; &aelig; &agrave; &aring; &atilde; &auml; &ccedil; &eacute;
  &ecirc; &egrave; &eth; &euml; &ouml; &szlig; &uuml; &yacute; &yuml;
  &copy; &reg; &pound; &yen; &brvbar; &sect;
  </p> </blockquote>},
  'highbits',

  q{What about <b>this</b> -- <strong>balanced</strong> <i>tag
  generation</i>?},
  'balanced_tag_generation',

  q{Make it a <strong>bit <i>trickier</i></strong>.},
  'balanced_tag_generation_2',

  q{<pre> pre tag generation.  This text should all be pre-formatted.
	   (Hopefully.) </pre>},
  'pre_text_with_double_colons',

);

# ---------------------------------------------------------------------------

ok (wmrun ("-F -f data/$testname.wmk", \&patterns_run_cb));
ok_all_patterns();
