#

package HTML::WebMake::MetaTable;

###########################################################################

use Carp;
use strict;

use HTML::WebMake::Main;

use vars	qw{
  	@ISA
};

###########################################################################

sub new ($$$$$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main) = @_;

  my $self = {
    'main'		=> $main,
  };
  bless ($self, $class);

  $self;
}

sub dbg { HTML::WebMake::Main::dbg (@_); }

# -------------------------------------------------------------------------

sub parse_metatable {
  my ($self, $attrs, $text) = @_;

  my $fmt = $attrs->{format};
  if (!defined $fmt || $fmt eq 'csv') {
    return $self->parse_metatable_csv ($attrs, $text);
  } else {
    return $self->parse_metatable_xml ($attrs, $text);
  }
}

# -------------------------------------------------------------------------

sub parse_metatable_csv {
  my ($self, $attrs, $text) = @_;

  my $delim = $attrs->{delimiter};
  $delim ||= "\t";
  $delim = qr{\Q${delim}\E};

  my @metanames = ();
  my $i;

  foreach my $line (split (/\n/, $text)) {
    my @elems = split (/${delim}/, $line);
    my $contname = shift @elems;
    next unless defined $contname;

    if ($contname eq '.') {
      @metanames = @elems; next;
    }

    my $contobj = $self->{main}->{contents}->{$contname};
    if (!defined $contobj) {
      $self->{main}->fail ("<metatable>: cannot find content \${$contname}");
      next;
    }

    for ($i = 0; $i <= $#elems && $i <= $#metanames; $i++) {
      my $metaname = $metanames[$i];
      my $val = $elems[$i];

      $contobj->create_extra_metas_if_needed();
      $contobj->{extra_metas}->{$metaname} = $val;
    }
  }
}

# -------------------------------------------------------------------------

sub parse_metatable_xml {
  my ($self, $attrs, $text) = @_;

  # trim off text before/after <metaset> chunk
  $text =~ s/^.*?<metaset\b[^>]*?>//gis;
  $text =~ s/<\/\s*metaset\s*>.*$//gis;

  # TODO: once we require an XML parser for XSLT stuff, we should use
  # that here instead of strip_tags.

  my $util = $self->{main}->{util};
  my $src = $attrs->{src}; $src ||= '(.wmk file)';
  $util->set_filename ($src);

  $self->parse_xml_block ($text, \&search_for_targets);
}

# -------------------------------------------------------------------------

sub search_for_targets {
  my ($self, $util, $textref) = @_;
  $util->strip_first_tag ($textref, "target", $self, \&tag_target, qw(id));
}

sub tag_target {
  my ($self, $tag, $attrs, $text) = @_;

  my $contname = $attrs->{'id'};

  my $contobj = $self->{main}->{contents}->{$contname};
  if (!defined $contobj) {
    $self->{main}->fail ("<metatable>: cannot find content \${$contname}");
    return '';
  }

  $self->{tagging_content} = $contobj;

  $self->parse_xml_block ($text, \&search_for_metas);

  '';
}

# -------------------------------------------------------------------------

sub search_for_metas {
  my ($self, $util, $textref) = @_;
  $util->strip_first_tag ($textref, "meta", $self, \&tag_meta, qw(name));
}

sub tag_meta {
  my ($self, $tag, $attrs, $text) = @_;
  my $contobj = $self->{tagging_content};
  $contobj->create_extra_metas_if_needed();
  $contobj->{extra_metas}->{$attrs->{'name'}} = $text;
  '';
}

# -------------------------------------------------------------------------

sub parse_xml_block {
  my ($self, $block, $sub) = @_;
  local ($_) = $block;

  my $util = $self->{main}->{util};
  my $prevpass;
  for (my $evalpass = 0; 1; $evalpass++) {
    last if (defined $prevpass && $_ eq $prevpass);
    $prevpass = $_;

    s/^\s+//gs;
    last if ($_ !~ /^</);

    1 while s/<\{!--.*?--\}>//gs;       # WebMake comments.
    1 while s/^<!--.*?-->//gs;          # XML-style comments.

    &$sub ($self, $util, \$_);
  }

  if (/\S/) {
    /^(.*?>.{40,40})/s; $_ = $1; $_ =~ s/\s+/ /gs;
    $self->{main}->fail ("metatable file contains unparseable data at:\n".
              "\t$_ ...\"\n");
  }
  1;
}

# -------------------------------------------------------------------------

1;

# METATABLE XML FORMAT
# 
# The idea is to allow tagging of content items with metadata in an XML
# format.
# 
#	 <metaset>
#	  <target id="contentname">
#	    <meta name="title">
#	      This is contentname's title.
#	    </meta>
#	  </target>
#	</metaset>

