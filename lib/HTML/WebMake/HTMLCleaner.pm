#

package HTML::WebMake::HTMLCleaner;

require Exporter;
use Carp;
use strict;
use HTML::Parser;
use HTML::WebMake::Main;

use vars	qw{
  	@ISA @EXPORT
	@ALLFEATURES $INLINE_TAGS $KEEP_FORMAT_TAGS
	$EMPTY_ELEMENT_TAGS $BOOL_ATTR_VALUE
};

@ISA = qw(HTML::Parser);
@EXPORT = qw();

@ALLFEATURES =		qw{
    pack nocomments addimgsizes addxmlslashes fixcolors cleanattrs
};

$KEEP_FORMAT_TAGS =	qr{(?:xmp|listing|pre|plaintext)};

$INLINE_TAGS =		qr{(?:a|b|i|em|q|strong|h\d|code|abbr|acronym|address|big|cite|del|ins|s|small|strike|sub|sup|u|samp|kbd|var|img|span)};

$EMPTY_ELEMENT_TAGS =	qr{(?:area|base|basefont|bgsound|br|col|embed|frame|hr|img|input|isindex|keygen|link|meta|param|spacer|wbr)};

###########################################################################

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main) = @_;

  my $self = $class->SUPER::new ( api_version => 2 );
  $self->{main} = $main;
  $self->clear_features();

  $BOOL_ATTR_VALUE = undef;

  # this parameter is not supported in earlier versions
  if ($HTML::Parser::VERSION >= 3.00) {
    my $val = '==BOOL_TRUE==';
    eval '
      $self->boolean_attribute_value ($val);
      $BOOL_ATTR_VALUE = $val;
    ';
  }

  bless ($self, $class);
  $self;
}

###########################################################################

sub select_features {
  my ($self, $feats) = @_;

  $self->clear_features();

  if ($feats =~ /\ball\b/i) {
    foreach my $feat (@ALLFEATURES) {
      $self->{$feat} = 1;
    }
  }

  foreach my $feat (split (' ', $feats)) {
    if ($feat =~ s/^\-//) {
      $self->{$feat} = 0;		# turned off
    } else {
      $self->{$feat} = 1;		# turned on
    }
  }
}

sub clear_features {
  my ($self) = @_;

  foreach my $feat (@ALLFEATURES) {
    $self->{$feat} = 0;
  }
}

###########################################################################

sub clean {
  my ($self, $txt) = @_;

  $self->{out} = [ ];
  $self->{in_pre} = 0;

  $self->parse ($$txt); $self->eof();

  join ('', @{$self->{out}});
}

###########################################################################

sub start {
  my($self, $tagname, $attr, $attrseq, $origtext) = @_;

  if ($tagname =~ /^${KEEP_FORMAT_TAGS}$/) {
    $self->{in_pre}++;
  }
  
  if (!$self->{cleanattrs}) {
    push (@{$self->{out}}, $origtext);
  } else {
    $self->clean_attrs_at_start ($tagname, $attr, $attrseq, $origtext);
  }

  if ($tagname !~ /^${INLINE_TAGS}$/) {
    push (@{$self->{out}}, "\n");
  }
  $self->{last_was_noninline_close_tag} = 0;
}

sub clean_attrs_at_start {
  my ($self, $tagname, $attr, $attrseq, $origtext) = @_;

  my $attrs = '';
  my $imgsrc = '';
  foreach my $name (@{$attrseq})
  {
    my $val = $attr->{$name};

    if ($self->{fixcolors} && $name =~ /colou?r$/) {
      if ($val =~ /^[\da-f]{6}$/i) {
	$val = "#".$val;	# color=004000 -> color="#004000"
      }
    }

    if ($tagname eq 'img' && $name eq 'src') {
      $imgsrc = $val;
    }

    if (defined $BOOL_ATTR_VALUE && $val eq $BOOL_ATTR_VALUE) {
      $attrs .= " ".$name;
    } elsif (!defined $BOOL_ATTR_VALUE && $val eq $name) {
      $attrs .= " ".$name;
    } elsif ($val =~ /\"/) {
      $attrs .= " ".$name ."=\'".$attr->{$name}."\'";
    } else {
      $attrs .= " ".$name ."=\"".$attr->{$name}."\"";
    }
  }

  my $tagend = '';
  if ($self->{addxmlslashes} && $attrs !~ /\/\s*$/ &&
	$tagname =~ /^${EMPTY_ELEMENT_TAGS}$/)
  {
    $tagend = " />";		# HTML-4, XHTML, XML style
  } else {
    $tagend = ">";
  }

  if ($tagname eq 'img' && $self->{addimgsizes} &&
	      $attrs !~ /(height|width)/i &&
	      $imgsrc !~ /^(?:[a-z0-9A-Z]+:|\/)/)
  {
    push (@{$self->{out}}, $self->{main}->fileless_subst
		    ("(html-cleaner)", "<$tagname".$attrs.' ${IMGSIZE}>'));
  } else {
    push (@{$self->{out}}, "<".$tagname, $attrs, $tagend);
  }
}

# --------------------------------------------------------------------------

sub end {
  my($self, $tagname, $origtext) = @_;
  
  my $exiting_pre = ($tagname =~ /^${KEEP_FORMAT_TAGS}$/);
  if ($exiting_pre) { $self->{in_pre}--; }

  if ($tagname !~ /^${INLINE_TAGS}$/) {
    if (!$self->{last_was_noninline_close_tag} && !$exiting_pre) {
      push (@{$self->{out}}, "\n");
    }
    if (!$self->{cleanattrs}) {
      push (@{$self->{out}}, $origtext);
    } else {
      push (@{$self->{out}}, "</$tagname>\n");
    }
    $self->{last_was_noninline_close_tag} = 1;

  } else {
    if (!$self->{cleanattrs}) {
      push (@{$self->{out}}, $origtext);
    } else {
      push (@{$self->{out}}, "</$tagname>");
    }
    $self->{last_was_noninline_close_tag} = 0;
  }
}

# --------------------------------------------------------------------------

sub text {
  my($self, $origtext, $is_cdata) = @_;

  $self->pack_text (\$origtext);
  $self->{last_was_noninline_close_tag} = 0;

  # to preserve whitespace:
  # push (@{$self->{out}}, $origtext);

  # or, to tidy up whitespace:
  if ($origtext =~ /\S/ || $self->{in_pre} > 0) {
    push (@{$self->{out}}, $origtext);
  } else {
    push (@{$self->{out}}, ' ');
  }
}

# --------------------------------------------------------------------------

sub process {
  my ($self, $origtext) = @_;
  push (@{$self->{out}}, "<?$origtext>\n");
}

# --------------------------------------------------------------------------

sub comment {
  my ($self, $origtext) = @_;
  if (!$self->{nocomments}) {
    $self->pack_text (\$origtext);
    push (@{$self->{out}}, "<!--$origtext-->\n");
  }
}

# --------------------------------------------------------------------------

sub declaration {
  my ($self, $origtext) = @_;
  push (@{$self->{out}}, "<!$origtext>\n");
}

###########################################################################

sub pack_text {
  my($self, $txt) = @_;
  if ($self->{pack} && !$self->{in_pre} > 0) {
    $$txt =~ s/\n\n+/\n/gm;
    $$txt =~ s/[ \t]+/ /gm;
    $$txt =~ s/^ / /gm;
    $$txt =~ s/ $/ /gm;
  }
}

###########################################################################

1;
