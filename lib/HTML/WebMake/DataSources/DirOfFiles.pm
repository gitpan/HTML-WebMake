#

package HTML::WebMake::DataSources::DirOfFiles;

require Exporter;
use File::Find;
use Carp;
use strict;

use HTML::WebMake::DataSourceBase;

use vars	qw{
  	@ISA @EXPORT
	$TmpGlobalSelf
};

@ISA = qw(HTML::WebMake::DataSourceBase);
@EXPORT = qw();

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new (@_);
  bless ($self, $class);

  $self;
}

# -------------------------------------------------------------------------

sub add {
  my ($self) = @_;
  local ($_);

  if ($self->{src} eq '') { $self->{src} = '.'; }

  my $use_find = 0;
  if ($self->{name} =~ s/^\.\.\.\///) {
    $use_find = 1;
  }
  my $patt = $self->{main}->{util}->glob_to_re ($self->{name});
  my @matched;

  $self->{src} =~ s,/+$,,;

  if ($use_find) {
    $self->{found} = [ ];

    if ($patt =~ m,/,) {
      $patt =~ s/^\^/\//;		# replace start-of-string marker with /
      $self->{find_full_path_pattern} = $patt;
    } else {
      $self->{find_file_pattern} = $patt;
    }

    $self->{find_startdir} = qr/\Q$self->{src}\E/;

    $TmpGlobalSelf = $self;
    find (\&find_wanted, $self->{src});
    undef $TmpGlobalSelf;

    @matched = @{$self->{found}};
    undef $self->{found};

  } else {
    if (!opendir (DIR, $self->{src})) {
      warn "can't open ".$self->as_string()." src dir \"$self->{src}\": $!\n";
      return;
    }

    # grep for files that (a) match the pattern and (b) are files, not dirs
    @matched = grep {
      /^${patt}$/ && -f (File::Spec->catfile ($self->{src}, $_));
    } readdir(DIR);
    closedir DIR;
  }

  foreach my $name (@matched) {
    my $fname = File::Spec->catfile ($self->{src}, $name);
    $fname =~ s,^\.[\\\/],,;	# fix ./foo => foo
    my $mtime = $self->{main}->cached_get_modtime ($fname);
    if (!defined $mtime || $mtime == 0) {
      warn "cannot stat file $fname\n";
      next;
    }

    my $fixed = $self->{parent}->fixname ($name);
    $self->{parent}->add_file_to_list ($fixed);
    $self->{parent}->add_location ($fixed, "file:".$fname, $mtime);
  }
}

sub find_wanted {
  -f $_ or return;		# ensure not a dir etc.

  my $self = $TmpGlobalSelf;

  if (defined $self->{find_file_pattern}) {
    ($_ =~ /$self->{find_file_pattern}/) or return;
  } else {
    ($File::Find::name =~ /$self->{find_full_path_pattern}/) or return;
  }

  my $name = $File::Find::name;
  $name =~ s/^$self->{find_startdir}\///g;
  push (@{$self->{found}}, $name);
}

# -------------------------------------------------------------------------

sub get_location_url {
  my ($self, $fname) = @_;

  $fname =~ s/^file://;
  return $fname;
}

# -------------------------------------------------------------------------

sub get_location_contents {
  my ($self, $fname) = @_;

  $fname =~ s/^file://;
  if (!open (IN, "<$fname")) {
    carp "cannot open file \"$fname\"\n"; return "";
  }
  my $text = join ('', <IN>); close IN;
  return $text;
}

# -------------------------------------------------------------------------

sub get_location_mod_time {
  my ($self, $fname) = @_;
  $fname =~ /^file:/;
  $self->{main}->cached_get_modtime ($');
}

1;
