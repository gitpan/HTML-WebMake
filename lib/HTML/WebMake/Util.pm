#

package HTML::WebMake::Util;


use Carp;
use File::Basename;
use File::Path;
use File::Spec;
use Cwd;
use strict;

use vars	qw{
  	@ISA
};




###########################################################################

sub new ($) {
  my $class = shift;
  $class = ref($class) || $class;

  my $self = {
    'last_tag_text' => undef,
  };

  bless ($self, $class);
  $self;
}

sub dbg { HTML::WebMake::Main::dbg (@_); }

###########################################################################

sub glob_to_re ($$) {
  my ($self, $patt) = @_;

  if ($patt =~ s/^RE://) {
    return $patt;
  }

  $patt =~ s:([].+^\-\${}[|]):\\$1:g;
  $patt =~ s/\\\.\\\.\\\./.*/g;
  $patt =~ s/\*/[^\/]*/g;
  $patt =~ s/\?/./g;
  '^'.$patt.'$';
}

###########################################################################

sub parse_boolean ($$) {
  my ($self, $val) = @_;

  if (defined $val && $val =~ /^(?:true|yes|on|y|1)$/i) {
    1;
  } else {
    0;
  }
}

###########################################################################

sub parse_xml_tag_attributes ($$$$$) {
  my ($self, $tag, $origtxt, $filename, @reqd_attrs) = @_;
  my $attrtxt = " ".$origtxt." ";
  my $attrs = { };

  #dbg ("tag: <$tag$origtxt>");
  while ($attrtxt =~ s{\s([A-Z0-9a-z_]+)\s*=\s*\"([^\"]*?)\"\s}{ }is) {
    #dbg ("tag: <$tag$attrtxt>: $1=$2");
    my ($atname, $atval) = ($1, $2); $atname =~ tr/A-Z/a-z/;
    $attrs->{$atname} = $atval;
  }                             # fix vim highlighting: "
  while ($attrtxt =~ s{\s([A-Z0-9a-z_]+)\s*=\s*\'([^\']*?)\'\s}{ }is) {
    my ($atname, $atval) = ($1, $2); $atname =~ tr/A-Z/a-z/;
    $attrs->{$atname} = $atval;
  }                             # fix vim highlighting: '
  while ($attrtxt =~ s{\s([A-Z0-9a-z_]+)\s*=\s*(\S*)\s}{ }is) {
    my ($atname, $atval) = ($1, $2); $atname =~ tr/A-Z/a-z/;
    $attrs->{$atname} = $atval;
  }

  foreach my $attr (@reqd_attrs) {
    if (!defined $attrs->{$attr}) {
      warn ($filename.": tag \"".$tag.
        "\" is missing required attribute \"$attr\": <$tag $origtxt>\n");
      return;
    }
  }

  return $attrs;
}

###########################################################################

sub set_filename ($$) {
  my ($self, $filename) = @_;
  $self->{filename} = $filename;
}

sub strip_tags ($$$$$@) {
  my ($self, $file, $tag, $taghandler, $tagfn, @reqd_attributes) = @_;
  $self->{strip_tags_reqd_attrs} = \@reqd_attributes;
  $self->{strip_tags_handler_obj} = $taghandler;
  $self->{strip_tags_handler_method} = $tagfn;
  $self->{last_tag_text} = undef;

  $file =~ s{<${tag}\b([^>]*?)/>}{
    $self->_found_tag ($tag, $1, '');
  }gies;

  $file =~ s{<${tag}\b([^>]*?)>(.*?)<\/\s*${tag}\s*>}{
    $self->_found_tag ($tag, $1, $2);
  }gies;

  $file;
}

sub strip_first_tag ($$$$$@) {
  my ($self, $fileref, $tag, $taghandler, $tagfn, @reqd_attributes) = @_;
  $self->{strip_tags_reqd_attrs} = \@reqd_attributes;
  $self->{strip_tags_handler_obj} = $taghandler;
  $self->{strip_tags_handler_method} = $tagfn;
  $self->{last_tag_text} = undef;

  $$fileref =~ s{^\s*<${tag}\b([^>]*?)/>}{
    $self->_found_tag ($tag, $1, '');
  }gies && return;

  $$fileref =~ s{^\s*<${tag}\b([^>]*?)>(.*?)<\/\s*${tag}\s*>}{
    $self->_found_tag ($tag, $1, $2);
  }gies;
}

sub _found_tag ($$$$) {
  my ($self, $tag, $origtxt, $text) = @_;

  $self->{last_tag_text} = '<'.$tag.$origtxt.'> ... </'.$tag.'>';

  my $attrs = $self->parse_xml_tag_attributes ($tag, $origtxt,
  	$self->{filename}, @{$self->{strip_tags_reqd_attrs}});
  if (!defined $attrs) { return; }

  &{$self->{strip_tags_handler_method}}
  		($self->{strip_tags_handler_obj}, $tag, $attrs, $text);
}

###########################################################################

=item @sorted = sort_by_score_title (@list);

A sort function (see C<perldoc -f sort>) which sorts a list of content items in
order of their C<score> metadata, with alphanumeric sorting by C<title> used
for items of the same score.

=cut

sub sort_by_score_title {
  my $cmp = $a->get_score() <=> $b->get_score();
  if ($cmp != 0) { return $cmp; }

  $a->get_title() cmp $b->get_title();
}

# a convenience function to do the sort for us, otherwise some package
# twiddling is required (as $a and $b are set in the caller's pkg).
#
sub sort_list_by_score_title {
  my ($self, @list) = @_;
  return sort sort_by_score_title @list;
}

###########################################################################

sub text_eol {
  my ($self) = @_;
  if ($^O =~ /(?:win|os2)/i) {
    return "\r\n";
  } elsif ($^O =~ /(?:mac)/i) {
    return "\r";
  } else {
    return "\n";
  }
}

###########################################################################

1;

