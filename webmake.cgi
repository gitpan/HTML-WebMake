#!/usr/bin/perl -w

$WEBMAKE = '/home/jm/ftp/webmake';

push (@INC, "$WEBMAKE/lib"); push (@INC, "$WEBMAKE/site_perl");

require WebMakeCGI::Edit;
require WebMakeCGI::Dir;
require CGI;

my $q = new CGI();
my $handler;

if (defined ($q->param('edit'))) {
  $handler = new WebMakeCGI::Edit($q);
} else {
  $handler = new WebMakeCGI::Dir($q);
}

$handler->run();
exit;
