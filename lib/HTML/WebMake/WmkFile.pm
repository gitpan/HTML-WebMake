#

package HTML::WebMake::WmkFile;

require Exporter;
use HTML::WebMake::File;
use Carp;
use strict;

use vars	qw{
  	@ISA @EXPORT
};

@ISA = qw(HTML::WebMake::File);
@EXPORT = qw();

###########################################################################

sub new ($$$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main, $filename) = @_;
  my $self = $class->SUPER::new ($main, $filename);

  bless ($self, $class);
  $self;
}

# -------------------------------------------------------------------------

sub dbg { HTML::WebMake::Main::dbg (@_); }
sub dbg2 { HTML::WebMake::Main::dbg2 (@_); }

# -------------------------------------------------------------------------

sub parse {
  my ($self, $str) = @_;
  local ($_) = $str;

  if (!defined $self->{main}) { carp "no main defined in WmkFile::parse"; }

  # trim off text before/after <webmake> chunk
  s/^.*?<webmake\b[^>]*?>//gis;
  s/<\/\s*webmake\s*>.*$//gis;

  # Now, we can't use a real XML parser here, as some of the contents
  # will contain HTML tags that are not necessarily in matched pairs.
  # still, the strip_first_tag regexps seem to work well.

  my $util = $self->{main}->{util};
  if (!defined $util) { carp "no util defined in WmkFile::parse"; }

  $util->set_filename ($self->{filename});

  my $prevpass;
  my ($lasttag, $lasteval);
  for (my $evalpass = 0; 1; $evalpass++) {
    last if (defined $prevpass && $_ eq $prevpass);
    $prevpass = $_;

    s/^\s+//gs;
    last if ($_ !~ /^</);

    1 while s/<\{!--.*?--\}>//gs;	# WebMake comments.
    1 while s/^<!--.*?-->//gs;		# XML-style comments.

    # Preprocessing.
    $_ = $util->strip_first_tag ($_, "include",
				  $self, \&tag_include, qw(file));
    $_ = $util->strip_first_tag ($_, "use",
				  $self, \&tag_use, qw(plugin));

    $self->{main}->eval_code_at_parse (\$_);

    $self->{main}->getusertags()->subst_wmk_tags
    					($self->{filename}, \$_);

    my $text = $self->{main}->{last_perl_code_text};
    if (defined $text) { $lasteval = $text; $lasttag = undef; }

    # Declarations.
    $_ = $util->strip_first_tag ($_, "content",
				  $self, \&tag_content, qw(name));
    $_ = $util->strip_first_tag ($_, "contents",
				  $self, \&tag_contents, qw(src name));
    $_ = $util->strip_first_tag ($_, "contenttable",
				  $self, \&tag_contenttable, qw());
    $_ = $util->strip_first_tag ($_, "media",
				  $self, \&tag_media, qw(src name));
    $_ = $util->strip_first_tag ($_, "metadefault",
				  $self, \&tag_metadefault, qw(name));
    $_ = $util->strip_first_tag ($_, "attrdefault",
				  $self, \&tag_attrdefault, qw(name));
    $_ = $util->strip_first_tag ($_, "metatable",
				  $self, \&tag_metatable, qw());
    $_ = $util->strip_first_tag ($_, "sitemap",
				  $self, \&tag_sitemap, qw(name node leaf));
    $_ = $util->strip_first_tag ($_, "navlinks",
				  $self, \&tag_navlinks,
				  qw(name map up prev next));
    $_ = $util->strip_first_tag ($_, "breadcrumbs",
				  $self, \&tag_breadcrumbs,
				  qw(name map level));

    # Outputs.
    $_ = $util->strip_first_tag ($_, "for",
				  $self, \&tag_for, qw(name values));
    $_ = $util->strip_first_tag ($_, "out",
				  $self, \&tag_out, qw(file));

    # Misc.
    $_ = $util->strip_first_tag ($_, "cache",
				  $self, \&tag_cache, qw(file));
    $_ = $util->strip_first_tag ($_, "option",
				  $self, \&tag_option, qw(name value));

    $text = $util->{last_tag_text};
    if (defined $text) { $lasttag = $text; $lasteval = undef; }
  }

  if (/\S/) {
    my $failuretext = $lasttag;

    if (defined $lasteval) {
      if ($_ !~ /^</) {
	# easy to spot; the Perl code returned '1' or something.
	# flag it clearly.

	s/\n.*$//gs;
	$self->{main}->fail ("Perl code didn't return valid WebMake code:\n".
		"\t$lasteval\n\t=> \"$_\"\n");
	return 0;
      }
      $failuretext = $lasteval;
    }

    /^(.*?>.{40,40})/s; $_ = $1; $_ =~ s/\s+/ /gs;
    $lasttag ||= '';
    $self->{main}->fail ("WMK file contains unparseable data at or after:\n".
	      "\t$lasttag\n\t$_ ...\"\n");
  }
  1;
}

# -------------------------------------------------------------------------

sub subst_attrs {
  my ($self, $tagname, $attrs) = @_;

  if (defined ($attrs->{name})) {
    $tagname .= " \"".$attrs->{name}."\"";	# for errors
  }

  my ($k, $v);
  while (($k, $v) = each %{$attrs}) {
    next unless (defined $k && defined $v);
    $attrs->{$k} = $self->{main}->fileless_subst ($tagname, $v);
  }
}

# -------------------------------------------------------------------------

sub tag_include {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<include>", $attrs);

  my $file = $attrs->{file};
  if (!open (INC, "< $file")) {
    die "Cannot open include file: $file\n";
  }
  my @s = stat INC;
  my $inc = join ('', <INC>);
  close INC;

  dbg ("included file: \"$file\"");
  $self->{main}->set_file_modtime ($file, $s[9]);
  $self->add_dep ($file);
  $inc;
}

# -------------------------------------------------------------------------

sub tag_use {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<use>", $attrs);

  my $plugin = $attrs->{plugin};
  my $file;
  my @s;

  $file = '~/.webmake/plugins/'.$plugin.'.wmk';
  $file = $self->{main}->sed_fname ($file);
  @s = stat $file;

  if (!defined $s[9]) {
    $file = '%l/'.$plugin.'.wmk';
    $file = $self->{main}->sed_fname ($file);
    @s = stat $file;
  }

  if (!defined $s[9]) {
    die "Cannot open 'use' plugin: $plugin\n";
  }

foundit:

  if (!open (INC, "<$file")) {
    die "Cannot open 'use' file: $file\n";
  }
  my $inc = join ('', <INC>);
  close INC;

  dbg ("used file: \"$file\"");
  $self->{main}->set_file_modtime ($file, $s[9]);
  $self->add_dep ($file);
  $inc;
}

# -------------------------------------------------------------------------

sub tag_cache {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<cache>", $attrs);
  my $file = $attrs->{file};
  $self->{main}->setcachefile ($attrs->{file});
  "";
}

# -------------------------------------------------------------------------

sub tag_option {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<option>", $attrs);
  $self->{main}->set_option ($attrs->{name}, $attrs->{value});
  "";
}

# -------------------------------------------------------------------------

sub tag_content {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<content>", $attrs);
  my $name = $attrs->{name};
  if (!defined $name) {
    carp ("Unnamed content found in ".$self->{filename}.": $text\n");
    return;
  }

  if (defined $attrs->{root}) {
    warn "warning: \${$name}: 'root' attribute is deprecated, ".
    		"use 'isroot' instead\n";
    $attrs->{isroot} = $attrs->{root};	# backwards compat
  }

  $self->{main}->add_content ($name, $self, $attrs, $text);
  "";
}

sub tag_contents {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<contents>", $attrs);
  my $lister = new HTML::WebMake::Contents ($self->{main},
  			$attrs->{src}, $attrs->{name}, $attrs);
  $lister->add();
  "";
}

sub tag_media {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<media>", $attrs);
  my $lister = new HTML::WebMake::Media ($self->{main},
  			$attrs->{src}, $attrs->{name}, $attrs);
  $lister->add();
  "";
}

sub tag_contenttable {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<contenttable>", $attrs);

  # we actually use a Contents object, reading from the .wmk file
  # to do this.
  $attrs->{src} = 'svfile:';
  if (!defined $attrs->{name})		{ $attrs->{name} = '*'; }
  if (!defined $attrs->{namefield})	{ $attrs->{namefield} = '1'; }
  if (!defined $attrs->{valuefield})	{ $attrs->{valuefield} = '2'; }

  my $lister = new HTML::WebMake::Contents ($self->{main},
  			$attrs->{src}, $attrs->{name}, $attrs);

  $lister->{ctable_wmkfile} = $self;
  $lister->{ctable_text} = $text;

  $lister->add();
  "";
}

sub tag_metadefault {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<metadefault>", $attrs);
  $self->{main}->{metadata}->set_metadefault ($attrs->{name}, $attrs->{value});

  return '' if (!defined $text || $text eq '');
  $text . '<metadefault name="'.$attrs->{name}.'" value="[POP]" />';
}

sub tag_attrdefault {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<attrdefault>", $attrs);
  $self->{main}->{metadata}->set_attrdefault ($attrs->{name}, $attrs->{value});

  return '' if (!defined $text || $text eq '');
  $text . '<attrdefault name="'.$attrs->{name}.'" value="[POP]" />';
}

sub tag_metatable {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<metatable>", $attrs);
  $self->{main}->{metadata}->parse_metatable ($attrs, $text);
  "";
}

sub tag_sitemap {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<sitemap>", $attrs);
  $self->{main}->add_sitemap ($attrs->{name},
  			$attrs->{rootname}, $self, $attrs, $text);
  "";
}

sub tag_navlinks {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<navlinks>", $attrs);
  $self->{main}->add_navlinks ($attrs->{name}, $attrs->{map},
  			$self, $attrs, $text);
  "";
}

sub tag_breadcrumbs {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<breadcrumbs>", $attrs);
  $attrs->{top} ||= $attrs->{level};
  $attrs->{tail} ||= $attrs->{level};
  $self->{main}->add_breadcrumbs ($attrs->{name}, $attrs->{map},
  			$self, $attrs, $text);
  "";
}

sub tag_out {
  my ($self, $tag, $attrs, $text) = @_;

  $self->subst_attrs ("<out>", $attrs);
  my $file = $attrs->{file};
  my $name = $attrs->{name}; $name ||= $file;
  $self->{main}->add_out ($file, $self, $name, $attrs, $text);
  $self->{main}->add_url ($name, $file);
  "";
}

sub tag_for ($$$$) {
  my ($self, $tag, $attrs, $text) = @_;
  local ($_);

  $self->subst_attrs ("<for>", $attrs);
  my $name = $attrs->{name};
  my $namesubst = $attrs->{namesubst};
  my $vals = $attrs->{'values'};

  my @vals = split (' ', $vals);
  if ($#vals >= 0)
  {
    if (!$self->{main}->{paranoid}) {
      if (defined $namesubst) {
	@vals = map { eval $namesubst; $_; } @vals;
      }
      if ($#vals < 0) {
	warn ("<for> tag \"$attrs->{name}\" namesubst failed: $@");
      }

    } else {
      warn "Paranoid mode on: not processing namesubst\n";
    }
  }

  my $ret = '';
  foreach my $val (@vals) {
    next if (!defined $val || $val eq '');
    $_ = $text; s/\$\{${name}\}/${val}/gs;
    $ret .= $_;
  }

  dbg2 ("for tag evaluated: \"$ret\"");
  $ret;
}

###########################################################################

1;
