#

package HTML::WebMake::SiteCache;

###########################################################################

require Exporter;
use Carp;

BEGIN { @AnyDBM_File::ISA = qw(DB_File GDBM_File NDBM_File SDBM_File); }
use AnyDBM_File;

use Fcntl;
use File::Spec;
use strict;

use HTML::WebMake::Main;

use vars	qw{
  	@ISA @EXPORT $DB_MODULE
};

@ISA = qw();
@EXPORT = qw();
$DB_MODULE = undef;

###########################################################################

sub new ($$$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main, $fname) = @_;

  die ("no cache filename") unless defined($fname);

  my $self = {
    'main'		=> $main,
    'filename'		=> $fname,
  };
  bless ($self, $class);

  $self;
}

sub dbg { HTML::WebMake::Main::dbg (@_); }

# -------------------------------------------------------------------------

sub tie {
  my ($self) = @_;

  my $try = 0;

  # use AnyDBM_File, but use the more efficient DB_File where supported
  my $dbtype = 'AnyDBM_File';
  if ($^O !~ /win|mac|os2/i) { $dbtype = 'DB_File'; }

  my %db;
  for ($try = 0; $try < 4; $try++)
  {
    my $dbobj = tie (%db, $dbtype, $self->{filename},
				  O_CREAT|O_RDWR, 0600)
	  or die "Cannot open/create site cache: $self->{filename}\n";

    if ($dbtype ne 'DB_File') {
      dbg ("cannot do db ownership security check on this platform");
      goto all_ok;
    }

    # check the open db file for ownership, to make sure it really
    # is owned by us and we're not the victim of a race exploit.
    my $fd = $dbobj->fd(); undef $dbobj;
    dbg ("checking ownership of site cache: $self->{filename} fd=$fd");
    open (DB_FH, "+<&=$fd") || die "dup $!";
    if (-o DB_FH) { goto all_ok; }

    warn "Site cache file is not owned by us. Deleting and retrying.\n";
    system ("ls -l '".$self->{filename}."' 1>&2");
    untie ($self->{db});
    unlink ($self->{filename});
  }

  die "Site cache file is not owned by us. Giving up.\n";

all_ok:
  # all's well, no funny tricks are underway
  dbg ("opened site cache: $self->{filename}");
  $self->{db} = \%db;
  return;
}

# -------------------------------------------------------------------------

sub untie {
  my ($self) = @_;

  untie ($self->{db}) or die "untie failed";
  dbg ("closed site cache: $self->{filename}");
}

# -------------------------------------------------------------------------

sub get_modtime {
  my ($self, $file) = @_;
  return $self->{db}{'m#'.$file};
}

# -------------------------------------------------------------------------

sub set_content_deps {
  my ($self, $file, %deps) = @_;
  my ($fname, $mod);

  my $depstr = '';
  while (($fname, $mod) = each %deps) {
    $self->{db}{'m#'.$fname} = $mod;
    $depstr .= "\0".$fname;
  }
  $self->{db}{'d#'.$file} = $depstr;
}

sub get_content_deps {
  my ($self, $file) = @_;
  my $str = $self->{db}{'d#'.$file};

  if (defined $str) {
    return split (/\0/, $self->{db}{'d#'.$file});
  } else {
    return ();		# an empty list
  }
}

# -------------------------------------------------------------------------

sub get_metadata {
  my ($self, $key) = @_;
  return $self->{db}{'M#'.$key};
}

sub put_metadata {
  my ($self, $key, $val) = @_;
  if (!defined $key || !defined $val) {
    return;
  }
  $self->{db}{'M#'.$key} = $val;
}

# -------------------------------------------------------------------------

sub get_format_conversion {
  my ($self, $contobj, $fmts, $pretext) = @_;

  my $cachename = $self->{db}{'F#'.$fmts.'#'.$contobj->{name}};
  if (!defined $cachename) { return; }

  my $thenmtime = $self->{main}->cached_get_modtime ($cachename);
  if (!defined $thenmtime) { return; }

  my $nowmtime = $contobj->get_modtime ();

  if ($thenmtime < $nowmtime || !open (IN, "<$cachename")) {
    return;
  }

  dbg ("using cached format conversion for ".$contobj->as_string());
  my $txt = join ('', <IN>);
  close IN;
  return $txt;
}

sub store_format_conversion {
  my ($self, $contobj, $fmts, $posttext) = @_;

  # convert the content object's name and formats to a checksum
  # value, to avoid filename clashes whereever possible.
  my $fname = $fmts.'#'.$contobj->{name};
  $fname = $contobj->{name}.'.'.unpack("%32C*", $fname);
  $fname =~ s/[^A-Za-z0-9]/_/g;

  my $cachename = File::Spec->catfile ($self->{main}->cachedir(), $fname);

  if (!open (OUT, ">$cachename")) { goto giveup; }
  print OUT $posttext;
  if (!close OUT) { goto giveup; }

  $self->{db}{'F#'.$fmts.'#'.$contobj->{name}} = $cachename;
  dbg ("cached format conversion for ".$contobj->as_string().": $cachename");
  return;

giveup:
  warn "cannot write to $cachename\n";
  unlink ($cachename);
  return;
}

# -------------------------------------------------------------------------

1;
