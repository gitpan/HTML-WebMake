#

package HTML::WebMake::HTMLCleaner;


use Carp;
use strict;
use HTML::Parser;
use HTML::WebMake::Main;

use vars	qw{
  	@ISA
	@ALLFEATURES $INLINE_TAGS $KEEP_FORMAT_TAGS
	$EMPTY_ELEMENT_TAGS $BOOL_ATTR_VALUE
};

@ISA = qw(HTML::Parser);


@ALLFEATURES =		qw{
    pack nocomments addimgsizes addxmlslashes fixcolors cleanattrs
    indent
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
  my ($self, $txt, $fname) = @_;

  $self->{out} = [ ];
  $self->{in_pre} = 0;

  $self->{indent_level} = 0;
  $self->{indent_str} = '';
  $self->{indent_depth} = 2;

  $self->parse ($$txt); $self->eof();

  if ($self->{indent_level} > 0) {
    warn "HTML cleaner: unbalanced tags found in $fname\n";
  }

  join ('', @{$self->{out}});
}

###########################################################################

sub start {
  my($self, $tagname, $attr, $attrseq, $origtext) = @_;

  if ($tagname =~ /^${KEEP_FORMAT_TAGS}$/) {
    $self->{in_pre}++;
  }
  
  if (!$self->{cleanattrs}) {
    $self->add_text ($origtext);
  } else {
    $self->clean_attrs_at_start ($tagname, $attr, $attrseq, $origtext);
  }

  if ($tagname !~ /^${INLINE_TAGS}$/) {
    $self->add_text ("\n");
    if (!$self->{in_pre} && $tagname !~ /^${EMPTY_ELEMENT_TAGS}$/) {
      $self->open_indent();
    } else {
      $self->add_current_indent();
    }
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
      $attr->{$name} =~ s/\'/&#039;/g;
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

  if ($self->{last_was_noninline_close_tag}) {
    $self->add_current_indent();
  }

  if ($tagname eq 'img' && $self->{addimgsizes} &&
	      $attrs !~ /(height|width)/i &&
	      $imgsrc !~ /^(?:[a-z0-9A-Z]+:|\/)/)
  {
    $self->add_text ($self->{main}->fileless_subst
	("(html-cleaner)", "<$tagname".$attrs.' ${IMGSIZE}>'));
  } else {
    $self->add_text ("<".$tagname, $attrs, $tagend);
  }
}

# --------------------------------------------------------------------------

sub end {
  my($self, $tagname, $origtext) = @_;
  
  my $exiting_pre = ($tagname =~ /^${KEEP_FORMAT_TAGS}$/);
  if ($exiting_pre) { $self->{in_pre}--; }

  if ($tagname !~ /^${INLINE_TAGS}$/) {
    if (!$self->{last_was_noninline_close_tag} && !$exiting_pre) {
      $self->add_text ("\n");
    }
    $self->close_indent();

    $self->add_text ("</$tagname>\n");
    $self->{last_was_noninline_close_tag} = 1;

  } else {
    $self->add_text ("</$tagname>");
    $self->{last_was_noninline_close_tag} = 0;
  }
}

# --------------------------------------------------------------------------

sub text {
  my($self, $origtext, $is_cdata) = @_;

  if ($self->{in_pre} > 0) {
    $self->{last_was_noninline_close_tag} = 0;
    $self->add_text ($origtext);
    return;

  } elsif ($origtext =~ /^\s*$/s) {
    return;
  }

  $self->{last_was_noninline_close_tag} = 0;
  $self->pack_text (\$origtext);

  # to preserve all whitespace:
  # $self->add_text ($origtext);

  # or, to tidy up whitespace:
  if ($origtext =~ /\S/) {
    $self->add_text ($origtext);
  } else {
    $self->add_text (' ');
  }
}

# --------------------------------------------------------------------------

sub process {
  my ($self, $origtext) = @_;
  $self->add_text ("<?$origtext>\n");
  $self->add_current_indent();
}

# --------------------------------------------------------------------------

sub comment {
  my ($self, $origtext) = @_;
  if (!$self->{nocomments}) {
    $self->pack_text (\$origtext);
    $self->add_text ("<!--$origtext-->\n");
    $self->add_current_indent();
  }
}

# --------------------------------------------------------------------------

sub declaration {
  my ($self, $origtext) = @_;
  $self->add_text ("<!$origtext>\n");
  $self->add_current_indent();
}

###########################################################################

sub pack_text {
  my($self, $txt) = @_;
  if ($self->{pack} && !$self->{in_pre} > 0) {
    $$txt =~ s/\n\n+/\n/gm;
    $$txt =~ s/[ \t]+/ /gm;
    $$txt =~ s/^ / /gm;
    $$txt =~ s/ $/ /gm;

    my $indent = $self->get_current_indent();
    $$txt =~ s/\n/\n${indent}/gs;
  }
}

###########################################################################

sub add_text {
  my $self = shift;
  push (@{$self->{out}}, @_);
  # $self->{last_was_indent} = 0;
}

sub open_indent {
  my ($self) = @_;

  if (!$self->{indent}) { return; }

  $self->{indent_level} += $self->{indent_depth};
  $self->{indent_str} = (' ' x $self->{indent_level});

  # return if ($self->{last_was_indent});
  push (@{$self->{out}}, $self->{indent_str});
  # $self->{last_was_indent} = 1;
}

sub close_indent {
  my ($self) = @_;

  if (!$self->{indent}) { return; }

  $self->{indent_level} -= $self->{indent_depth};
  if ($self->{indent_level} < 0) { $self->{indent_level} = 0; }
  $self->{indent_str} = (' ' x $self->{indent_level});

  # return if ($self->{last_was_indent});
  push (@{$self->{out}}, $self->{indent_str});
  # $self->{last_was_indent} = 1;
}

sub add_current_indent {
  my ($self) = @_;

  if (!$self->{indent}) { return; }

  # return if ($self->{last_was_indent});
  push (@{$self->{out}}, $self->{indent_str});
  # $self->{last_was_indent} = 1;
}

sub get_current_indent {
  my ($self) = @_;
  $self->{indent_str};
}

###########################################################################

1;
