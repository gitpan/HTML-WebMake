
package WebMakeCGI::Edit;

use Carp;
use strict;
use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';
use WebMakeCGI::Lib;
use Fcntl;

use vars	qw{
  	@ISA $VERSION $HTML
};

@ISA = qw();
$VERSION = "0.1";

###########################################################################

$HTML = q{

<html><head>
<title>WebMake: Edit File</title>
</head>
<body bgcolor="#ffffff" text="#000000" link="#3300cc" vlink="#665066">

<h1>WebMake: Edit File</h1><hr />

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
    'q'			=> new CGI(),
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

sub is_media {
  my ($self, $filename) = @_;

  if ($filename =~ /\.(?:txt|html|htm)$/i) {
    return 1;
  } else {
    return 0;
  }
}


sub run {
  my $self = shift;
  my $q = $self->{q};

  $|++;
  print "Content-Type: text/html\r\n\r\n";
  $self->{msgs} = '';


  # my $fname = $q->path_info();
  my $fname = &mksafepath($q->param('edit'));
  $self->{filename} = $fname;

  my $form = '';
  if ($q->param ('Save')) {
    $form = $self->write_save_page ();
  } elsif ($q->param ('Preview')) {
    $form = $self->write_preview_page ();
  } else {
    $form = $self->write_edit_page ();
  }

  my $txt = $HTML;
  $txt =~ s/__ERRORS__/$self->{msgs}/gs;
  $txt =~ s/__FORM__/${form}/gs;
  print $txt;
}


sub write_edit_page
{
  my $self = shift;
  my $q = $self->{q};

  my $form;
  
  if ($q->param ('upload')) {
    $form = $q->start_multipart_form('-action' => 'webmake.cgi');
    $form .= q{

	<p>
	Currently expecting a file upload. Click here to switch
	to <a href="__REINVOKE__upload=0__">
	editing the file in-page</a>.
	</p><hr />

    };
  } else {
    $form = $q->startform('-action' => 'webmake.cgi');
    $form .= q{

	<p>
	Currently editing in-page. Click here to switch to
	<a href="__REINVOKE__upload=1__">
	file upload</a>.
	</p><hr />

    };
  }

  # TODO -- load metadata from wmmeta file

  $form .= $q->p ("Title:")
      . $q->textfield (-name => 'm_title',
	      -size => 65,
	      -default => '');

  if ($q->param ('allmetadata')) {
    $form .=
      $q->p ("Other metadata:")
      . $q->p ("Section:")
      . $q->textfield (-name => 'm_section',
	      -default => '')
      . $q->p ("Score:")
      . $q->textfield (-name => 'm_score',
	      -default => '')
      . $q->p ("Abstract:")
      . $q->textarea (-name => 'm_abstract',
	      -default => '',
	      -rows => 5,
	      -columns => 80)
      . $q->p ("Up:")
      . $q->textfield (-name => 'm_up',
	      -default => '')
      . $q->p ("Author:")
      . $q->textfield (-name => 'm_author',
	      -size => 65,
	      -default => '');

    $form .= q{

	<p>
	<a href="__REINVOKE__allmetadata=0__">
	Less Metadata...</a>
	</p>

    };

  } else {
    $form .= q{

	<p>
	<a href="__REINVOKE__allmetadata=1__">
	More Metadata...</a>
	</p>

    };
  }

  $form .= $q->hr();

  if ($q->param ('upload')) {

    $form .= $q->p ("Upload file: ")
    	. $q->filefield (-name => 'upload_file',
		-default => '',
		-size => 50,
		-maxlength => 256);

  } else {
    my @from = $q->radio_group (-name => 'text_from',
		-values => [
			'Load from URL',
			'Textbox'
			], -default => 'Textbox');

    $form .= $q->p ($from[0])
	. $q->textfield (-name => 'upload_url',
		-size => 65,
		-default => '');

    $form .= $q->p ($from[1])
	. $q->textarea (-name => 'upload_text',
		-default => '',
		-rows => 20,
		-columns => 80);
  }

  $form .= $q->hr();

  $form .= $q->p ("Link text:")
      . $q->textfield (-name => 'link_text',
	      -size => 65,
	      -default => '');

  $form .= $q->submit(-name=>'Preview',-value=>'Preview')
      . $q->submit(-name=>'Save',-value=>'Save')
      . $q->hidden(-name=>'step',-value=>'editing')
      . $q->hidden(-name=>'edit',-value=>$self->{filename})
      . $q->endform();

  $form =~ s{__REINVOKE__(\S+?)__}{
    $self->reinvoke_with_param($1);
  }ge;

  $form;
}

sub reinvoke_with_param {
  my ($self, $param) = @_;
  my $q = $self->{q};

  my $href = $q->url (-relative=>1, -path=>1) . '?' . $param;
  my $str = $q->query_string ();

  $param =~ /^(.*?)=/;
  my $pkey = $1;
  
  foreach my $elem (split (/\&/, $str)) {
    if ($elem =~ /^(.*?)=/) {
      if ($1 eq $pkey) { next; }
    }

    $href .= '&'.$elem;
  }
  $href;

}

# ---------------------------------------------------------------------------

sub write_preview_page
{
  my $self = shift;
  my $q = $self->{q};

  "TODO";
}

# ---------------------------------------------------------------------------

sub write_save_page
{
  local ($_);
  my $self = shift;
  my $q = $self->{q};
  my $try;

  # if ($self->is_media($self->{filename})) {
  # } else {
  # }

  my $metatable = $self->{file_base}."/wmmeta.tbl";
  my $lock = $metatable.".lock";

  for $try (1..10) {
    last if (open (LOCK, ">$lock"));

    $self->warn ("cannot lock {WMROOT}/wmmeta.tbl, retrying (try $tries)...");
    sleep (1);
  }

  if ($try >= 10) {
    close LOCK;
    $self->warn ("failed to lock {WMROOT}/wmmeta.tbl, ".
    	"someone else is updating content here. Try again later.");
    return '';		# TODO
  }

  print LOCK $$;

  open (MIN, "<$metatable");
  if (open (META, ">$metatable.new")) {
    $self->warn ("cannot write to {WMROOT}/wmmeta.tbl.new!");

  } else {
    # TODO: parse MIN and avoid overwriting its values

    my @names = $q->param();
    foreach my $name (@names) {
      next unless /^m_(\S+)/;

      my $metaname = $1;
      $metaname =~ s/\"/_/gs;

      my $val = $q->param ($name);
      # escape end-of-metadata markers
      $val =~ s/<(\/\s*wmmeta\s*>)/\&lt;$1/gs;

      print META "<metatarget name=\"".$self->{filename}."\">".
      	"<wmmeta name=\"$metaname\">$val</wmmeta></metatarget>\n";
    }

    if (!close META) {
      $self->warn ("write failed to {WMROOT}/wmmeta.tbl.new!");
      close LOCK;
      return '';
    }
    close MIN;

    if (!unlink ($metatable)
      	|| !rename ("$metatable.new", $metatable))
    {
      $self->warn ("unlink/rename of {WMROOT}/wmmeta.tbl failed!");
      close LOCK;
      return '';
    }
    close LOCK;
  }

  my $textfrom = $q->param ('text_from');

  if (!open (FILE, ">".$self->{file_base}."/".$self->{filename})) {
    $self->warn ("cannot write to {WMROOT}/".$self->{filename}."!");

  } else {
    if ($q->param ('upload')) {
      my $infile = $q->param ("upload_file");

      if ($self->is_media($self->{filename})) {
	binmode FILE;
	my $bytesread;
	while ($bytesread=read($infile,$_,1024)) { print FILE $_; }

      } else {
	while (<$infile>) {
	  s/\r$//; print FILE $_;
	}
      }

    } elsif ($textfrom eq 'Load from URL') {
      my $url = $q->param ('upload_url');
      $self->warn ("TODO: load from url");

    } else {
      $_ = $q->param ('upload_text');
      s/\r//gs; print FILE $_;
    }

    close FILE;
  }

  # TODO -- handle link_text

  my $dirurl = $self->{filename};
  if ($dirurl =~ m,/,) {
    $dirurl =~ s,/^[/]+,,g;
  } else {
    $dirurl = '';
  }

  my $form = qq{

    <p>
      Your changes have been submitted. Thanks!  Now return
      to <a href="webmake.cgi?dir=$dirurl">the directory listing</a>.
    </p>

  };

  $form;
}

###########################################################################

1;
