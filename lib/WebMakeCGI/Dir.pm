
package WebMakeCGI::Dir;

use Carp;
use strict;
use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';
use WebMakeCGI::Lib;

use vars	qw{
  	@ISA $VERSION $HTML
};

@ISA = qw();
$VERSION = "0.1";

###########################################################################

$HTML = q{

<html><head>
<title>Webmake: Edit Directory</title>
</head>
<body bgcolor="#ffffff" text="#000000" link="#3300cc" vlink="#660066">

<h1>WebMake: Edit Directory</h1><hr />

__ERRORS__

__FORM__

</body></html>
};

###########################################################################

$CGI::POST_MAX = 1024*1024*2;
$CGI::DISABLE_UPLOADS = 1;

sub new {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
    'q'			=> shift,
    'msgs'		=> ''
  };

  $self->{file_base} = "/home/jm/ftp/wmtest";

  bless ($self, $class);
  $self;
}

###########################################################################

sub mksafe { return WebMakeCGI::Lib::mksafe (@_); }
sub mksafepath { return WebMakeCGI::Lib::mksafepath (@_); }

sub warn {
  my ($self, $err) = @_;
  
  warn "WebMakeCGI: $err\n";
  $self->{msgs} .= "<font color=\"#ff0000\">Warning: $err</font><br /><hr />\n";
}

sub run {
  my $self = shift;
  my $q = $self->{q};

  print "Content-Type: text/html\r\n\r\n";
  $self->{msgs} = '';

  # my $dir = $q->path_info();
  my $dir = &mksafepath($q->param('dir'));
  $self->{dir} = $dir;

  my $step = $q->param('step');
  my $form;
  if (!defined $step || $step eq 'list') {
    $form = $self->write_list_page ();
  }
  $form ||= '';

  my $txt = $HTML;
  $txt =~ s/__ERRORS__/$self->{msgs}/gs;
  $txt =~ s/__FORM__/${form}/gs;
  print $txt;
}

sub write_list_page
{
  my $self = shift;
  my $q = $self->{q};

  my $form = '';
  # $form = $q->startform();

  if (!defined ($self->{dir})) {
    $self->{dir} = '.';
    # $self->warn ("No directory defined."); return '';
  }

  $form .= "
    <hr />
    <p>Files in <strong>$self->{dir}</strong>:</p>
    <ul>
  ";

  if (!opendir (DIR, $self->{file_base}."/".$self->{dir})) {
    $self->warn ("can't opendir {WMROOT}/$self->{dir}: $!");
  }
  my @files = sort readdir (DIR);
  closedir DIR;

  foreach my $file (@files) {
    my $partpath = &mksafepath ($self->{dir}."/".$file);
    my $path = $self->{file_base}."/".$partpath;

    if ($file eq '.') { next; }
    if ($file eq '..') { $file = 'Up to higher level directory'; }

    if (-d $path) {
      $form .= qq{
	<li>Dir: <strong>$file</strong>
	<a href="webmake.cgi?dir=$partpath">[Go]</a>
	</li>
      };

    } else {
      $form .= qq{
	<li>File: <strong>$file</strong>
	<a href="webmake.cgi?edit=$partpath">[Edit]</a>
	</li>
      };
    }
  }

  $form .= q( </ul> <hr /> );

  $form .= $q->startform(-action => 'webmake.cgi',
  				-method => 'GET')
	  . $q->p ("Create New File:  "
	    . $q->textfield (-name => 'edit',
		    -default => '')." "
	    . $q->submit (-name=>'Create', -value=>'Create')
	  )
	  . $q->endform();

  $form .= q{
    (Both text and image files can be created this way. They
    will be differentiated by their file extension.)
  };

  $form;
}

###########################################################################

1;
