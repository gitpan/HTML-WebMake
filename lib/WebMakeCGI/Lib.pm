
package WebMakeCGI::Lib;

use Carp;
use strict;
use HTML::Entities;
use HTML::WebMake::Util;

use vars	qw{ @ISA };

@ISA = qw();

###########################################################################

sub mksafe {
  local($_) = shift;
  if (!defined $_) { return undef; }

  s/\0/_/gs;		# strip NULs
  s/[^-_+\[\]\@\#,.\/:\~%^\(\)\{\}A-Za-z0-9 ]/_/gs;
  $_;
}

sub mksafepath {
  local($_) = shift;
  if (!defined $_) { return undef; }

  $_ = mksafe($_);
  s/[^-_+\@,.\/:%A-Za-z0-9 ]/_/gs;
  s,[^/]+/+\.\./+,,gs;	# strip ..s
  s,\.\./+,,gs;		# strip any leftover ..s
  $_;
}

1;
