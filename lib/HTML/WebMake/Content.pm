#

=head1 NAME

Content - a content item.

=head1 SYNOPSIS

  <{perl

    $cont = get_content_object ("foo.txt");
    [... etc.]

  }>

=head1 DESCRIPTION

This object allows manipulation of WebMake content items directly.

=head1 METHODS

=over 4

=cut

package HTML::WebMake::Content;

require Exporter;
use Carp;
use strict;
use locale;

use vars	qw{
  	@ISA @EXPORT
	%SORT_SUBS $WM_META_PAT $MIN_FMT_CACHE_LEN
};

@ISA = qw(Exporter);
@EXPORT = qw();

%SORT_SUBS = ();
$WM_META_PAT = qr{<wm meta}x;
$MIN_FMT_CACHE_LEN = 1024;

###########################################################################

sub new ($$$$$$$) {
  my $class = shift;
  $class = ref($class) || $class;

  my ($name, $file, $attrs, $text, $datasource, $ismetadata) = @_;
  my $attrval;
  my $self = { %$attrs };	# copy the attrs
  bless ($self, $class);

  $self->{name}			= $name;
  $self->{main}			= $file->{main};

  if (defined $text) {
    $self->{text}		= $text;
  }

  # check this content item's format. text/html is the default, so
  # if it's set to that, delete it to save space; otherwise, convert
  # it to a compressed representation to save space.
  $attrval = $attrs->{'format'};
  $attrval ||= $self->{main}->{metadata}->get_attrdefault ('format');
  if (defined $attrval) {
    if ($attrval eq 'text/html') {
      delete $self->{format};
    } else {
      $self->{format} =
	  HTML::WebMake::FormatConvert::format_name_to_zname($attrval);
    }
  }

  $self->{location}		= \$file->{filename};
  $self->{deps}			= $self->mk_deps ($file->get_deps());

  # used for Content items defined from Contents sections
  if (defined $datasource) {
    $self->{datasource}		= $datasource;
  }

  # can this content item, in turn, support metadata?
  # (metadata items cannot support metadata themselves).
  if ($ismetadata) {
    $self->{cannot_have_metadata} = 1;
  }

  # is this content item formatted as-is, no content refs to be expanded
  # etc.?
  $attrval = $attrs->{'asis'};
  $attrval ||= $self->{main}->{metadata}->get_attrdefault ('asis');
  if (defined $attrval) {
    $self->{keep_as_is} = $self->{main}->{util}->parse_boolean ($attrval);
    delete $self->{'asis'};	# in case it was set as an attr
  }

  # sitemap support.
  $attrval = $attrs->{'up'};
  $attrval ||= $self->{main}->{metadata}->get_attrdefault ('up');
  if (defined $attrval) {
    $self->{up_name} = $attrval;
    delete $self->{'up'};	# in case it was set as an attr
  }

  # see if we have 'map=false' as an attribute
  $attrval = $attrs->{'map'};
  $attrval ||= $self->{main}->{metadata}->get_attrdefault ('map');
  if (defined $attrval) {
    if (!$self->{main}->{util}->parse_boolean ($attrval)) {
      $self->{no_map} = 1;
    }
    delete $self->{'map'};	# in case it was set as an attr
  }

  $attrval = $attrs->{'isroot'};
  $attrval ||= $self->{main}->{metadata}->get_attrdefault ('isroot');
  if (defined $attrval) {
    $self->{is_root} = $self->{main}->{util}->parse_boolean ($attrval);
    delete $self->{'isroot'};	# in case it was set as an attr
  }

  if (defined $attrs->{is_sitemap}) {
    $self->{is_sitemap}	=
  	$self->{main}->{util}->parse_boolean ($attrs->{is_sitemap});
  }

  if ($self->{is_sitemap}) {
    $self->{sitemap_node_name}	= $attrs->{node};
    $self->{sitemap_leaf_name}	= $attrs->{leaf};
    $self->{sitemap_dynamic_name} = $attrs->{dynamic};
  }

  if ($self->{is_root}) {
    $self->{main}->getmapper()->set_root ($self);
  }

  # is_navlinks is an attribute set by Main::add_navlinks().
  if ($self->{is_navlinks}) {
    $self->{cannot_have_metadata} = 1;
    $self->{only_usable_from_def_refs} = 1;
    $self->{no_map}		= 1;
  }

  # is_breadcrumbs: set by Main::add_breadcrumbs().
  if ($self->{is_breadcrumbs}) {
    $self->{cannot_have_metadata} = 1;
    $self->{only_usable_from_def_refs} = 1;
    $self->{no_map}		= 1;
  }

  if (!$self->is_generated_content()) {
    $self->{main}->{metadata}->add_metadefaults ($self);
  }

  if ($self->{is_root} && $self->{no_map}) {
    warn ($self->as_string().": root content cannot have \"map=false\"!\n");
    undef $self->{no_map};
  }

  $self;
}

sub dbg { HTML::WebMake::Main::dbg (@_); }
sub vrb { HTML::WebMake::Main::vrb (@_); }

# -------------------------------------------------------------------------

=item $text = $cont->get_name();

Return the content item's name.

=cut

sub get_name {
  my ($self) = @_;
  $self->{name};
}

=item $text = $cont->as_string();

A textual description of the object for debugging purposes; currently it's
name.

=cut

sub as_string {
  my ($self) = @_;
  "\$\{".$self->{name}."\}";
}

# -------------------------------------------------------------------------

=item $fname = $cont->get_filename();

Get the filename or datasource location that this content was loaded from.
Datasource locations look like this:
C<proto>:C<protocol-specific-location-data>, e.g. C<file:blah/foo.txt> or
C<http://webmake.taint.org/index.html>.

=cut

sub get_filename {
  my ($self) = @_;
  return ${$self->{location}};
}

=item @filenames = $cont->get_deps();

Return an array of filenames and locations that this content depends on, i.e.
the filenames or locations that it contains variable references to.

=cut

sub get_deps {
  my ($self) = @_;

  map {
    if ($_ eq "\001") { $self->{location}; }
    elsif ($_ eq "\002") { '(dep_ignore)'; }
    else { $_; }
  } split (/\0/, $self->{deps});
}

sub mk_deps {
  my ($self, $deps) = @_;

  join ("\0", map {
    if ($_ eq $self->{location}) { "\001"; }
    elsif ($_ eq '(dep_ignore)') { "\002"; }
    else { $_; }
  } @{$deps});
}

=item $flag = $cont->is_generated_content();

Whether or not a content item was generated from Perl code, or is metadata.
Generated content items cannot themselves hold metadata.

=cut

sub is_generated_content {
  my ($self) = @_;
  return ($self->{cannot_have_metadata} ? 1 : 0);
}

# -------------------------------------------------------------------------

=item $val = $cont->expand()

Expand a content item, as if in a curly-bracket content reference.  If the
content item has not been expanded before, the current output file will be
noted as the content item's ''main'' URL.

=cut

sub expand {
  my ($self) = @_;
  return $self->{main}->curly_subst ($self->{name}, $self->{name});
}

=item $val = $cont->expand_no_ref()

Expand a content item, as if in a curly-bracket content reference.  The current
output file will not be used as the content item's ''main'' URL.

=cut

sub expand_no_ref {
  my ($self) = @_;
  return $self->{main}->fileless_subst ($self->{name}, '${'.$self->{name}.'}');
}

# -------------------------------------------------------------------------

=item $val = $cont->get_metadata($metaname);

Get an item of this object's metadata, e.g.

	$score = $cont->get_metadata("score");

The metadatum is converted to its native type, e.g. C<score> is return as an
integer, C<title> as a string, etc.  If the metadatum is not provided, the
default value for that item, defined in HTML::WebMake::Metadata, is used.

=cut

sub get_metadata {
  my ($self, $key) = @_;

  my $val = undef;

  if (!defined $self->{cached_metas}) {
    $self->{cached_metas} = { };
  }

  if (!defined $self->{cached_metas}->{$key})
  {
    if (!$self->is_generated_content()) {
      $val = $self->{main}->expand_content_quietly("(meta)", $self->{name}.".".$key);
    } else {
      # kludge: ensure metadata clusters beside its parent datum
      # for (full) sitemaps.
      if ($key eq 'score') { $val = '0'; }
    }

    if (!defined $val || $val eq '') {
      $val = $self->{main}->{metadata}->get_default_value ($key);
    }

    $val = $self->{main}->{metadata}->convert_to_type ($key, $val);
    $self->{cached_metas}->{$key} = $val;

  } else {
    $val = $self->{cached_metas}->{$key};
  }

  return $self->{cached_metas}->{$key};
}

# -------------------------------------------------------------------------

sub create_extra_metas_if_needed {
  my ($self) = @_;
  if (!defined $self->{extra_metas}) {
    $self->{extra_metas} = { };
  }
}

# -------------------------------------------------------------------------

sub load_metadata {
  my ($self) = @_;

  if ($self->is_generated_content()) { return; }

  $self->load_text_if_needed();
  $self->parse_metadata_tags ($self->{name}, $self->{text});
  $self->add_extra_metas ($self->{name});
  $self->infer_implicit_metas();
}

# -------------------------------------------------------------------------

sub parse_metadata_tags {
  my ($self, $from, $str) = @_;

  if ($str !~ /${WM_META_PAT}/i) { return; }

  my $util = $self->{main}->{util};

  $self->{meta_from} = $from;
  $str = $util->strip_tags ($str, "wmmeta",
                            $self, \&tag_wmmeta, qw(name));
  $self->{meta_from} = undef;

  if ($str =~ /${WM_META_PAT}.*?>/i) {
    warn "<wm"."meta> tag could not be parsed: \${$from} in ".
              $self->{main}->{current_subst}->{filename}.": $&\n";
  }
}

sub tag_wmmeta {
  my ($self, $tag, $attrs, $text) = @_;

  # use a "value" attr if available; otherwise use the text
  # inside the tag.
  my $name = lc $attrs->{name};
  my $val = $attrs->{value};
  $val ||= $text;

  $self->{main}->add_metadata ($self->{meta_from}, $name, $val, $attrs);
  "";
}

# -------------------------------------------------------------------------

sub infer_implicit_metas {
  my ($self) = @_;

  if (defined $self->{main}->{contents}->{"this.title"}
  	&& defined $self->{main}->{contents}->{$self->{name}.".title"})
  {
    return;		# no need to infer it, it's already defined
  }

  # Snarf a default title from the text, if one has not been set.
  $self->find_implicit_title_in_text (\$self->{text});
}

# -------------------------------------------------------------------------

sub find_implicit_title_in_text {
  my ($self, $txt) = @_;

  my $fmt = $self->get_format();

  # POD documentation: the NAME section
  if ($fmt eq 'text/pod') {
    if ($$txt =~ /^\s*=head1\s+[-A-Z0-9_ ]+\n\s+(\S[^\n]*?)\n/s)
      { $self->add_inferred_metadata ("title", $1, 'text/html'); }
  }

  # HTML/XML: the first title tag or heading
  elsif ($fmt eq 'text/html') {
    if ($$txt =~ /<title>(.*?)<\/title>/si)
      { $self->add_inferred_metadata ("title", $1, 'text/html'); }
    # or title tag
    elsif ($$txt =~ /<h\d>(.*?)<\/h\d>/si)
      { $self->add_inferred_metadata ("title", $1, 'text/html'); }
  }

  # EtText: EtText headings
  elsif ($fmt eq 'text/et') {
    if ($$txt =~ /(?:^\n+|\n\n)([^\n]+)[ \t]*\n[-=\~]{3,}\n/s)
      { $self->add_inferred_metadata ("title", $1, 'text/html'); }

    elsif ($$txt =~ /(?:^\n+|\n\n)([0-9A-Z][^a-z]+)[ \t]*\n\n/s)
      { $self->add_inferred_metadata ("title", $1, 'text/html'); }
  }

  # otherwise the first line of non-white chars
  elsif ($$txt =~ /^\s*(\S[^\n]*?)\s*\n/s)
    { $self->add_inferred_metadata ("title", $1, $fmt); }

  undef;
}

# -------------------------------------------------------------------------

sub add_inferred_metadata {
  my ($self, $name, $val, $fmt) = @_;

  my $attrs = { };

  if ($fmt ne 'text/html') {
    $attrs->{format} = $fmt;
  }

  # If the "title" has a reference to $[this.title], it's not a
  # suitable inference; it uses the genuine title from another
  # content object.
  return if ($val =~ /\$\[this.title\]/i);

  $val =~ s/<[^>]+>//g;		# trim wayward HTML tags
  $val =~ s/^\s+//;
  $val =~ s/\s+$//;

  dbg ("inferring $name metadata from text: \"$val\"");
  $self->{main}->add_metadata ($self->{name}, $name, $val, $attrs);
}

# -------------------------------------------------------------------------

sub add_extra_metas {
  my ($self, $from) = @_;
  # also add our own extra metadata from nav links, <defaultmeta> tags
  # etc.
  my ($metaname, $val);
  while (($metaname, $val) = each %{$self->{extra_metas}}) {
    $self->{main}->add_metadata ($from, $metaname, $val, { });
  }
}

# -------------------------------------------------------------------------

=item $score = $cont->get_score();

Return a content item's score.

=cut

sub get_score {
  my ($self) = @_;
  return $self->get_metadata ("score");
}

=item $title = $cont->get_title();

Return a content item's title.

=cut

sub get_title {
  my ($self) = @_;
  return $self->get_metadata ("title");
}

# -------------------------------------------------------------------------

=item $modtime = $cont->get_modtime();

Return a content item's modification date, in UNIX time_t format,
ie. seconds since Jan 1 1970.

=cut

sub get_modtime {
  my ($self) = @_;
  if (defined $self->{datasource}) {
    return $self->{datasource}->get_location_mod_time ($self->get_filename());
  } else {
    return $self->{main}->cached_get_modtime ($self->get_filename());
  }
}

# -------------------------------------------------------------------------

sub set_declared {
  my ($self, $order) = @_;
  $self->{decl_order} = $order;
}

=item $order = $cont->get_declared();

Returns the content item's declaration order.  This is a number representing
when the content item was first encountered in the WebMake file; earlier
content items have a lower declaration order. Useful for sorting.

=cut

sub get_declared {
  my ($self) = @_;
  return $self->{decl_order};
}

# -------------------------------------------------------------------------

sub get_magic_metadata {
  my ($self, $from, $key) = @_;
  my $val;

  if ($key eq 'name') {
    return $self->get_name();
  }

  elsif ($key eq 'url') {
    return "" if ($self->is_generated_content());
    $val = $self->get_url();
    if (!defined $val) {
      vrb ("no URL defined for content \${".$self->{name}.
				".$key} in \"$from\".");
      return "";
    }
    return $val;
  }

  elsif ($key eq 'mtime') {
    return $self->get_modtime();
  }

  elsif ($key eq 'declared') {
    return $self->get_declared();
  }

  elsif ($key eq 'is_generated') {
    return ($self->is_generated_content()) ? '1' : '0';
  }

  return undef;
}

# -------------------------------------------------------------------------

sub add_kid {
  my ($self, $kid) = @_;

  return if ($kid eq $self);

  if (!defined $self->{kids}) {
    $self->{kids} = [ ];
  }

  push (@{$self->{kids}}, $kid);
}

sub has_any_kids {
  my ($self) = @_;
  if (!defined $self->{kids}) { return 0; }
  if ($#{$self->{kids}} >= 0) { return 1; }
  return 0;
}

sub get_kids {
  my ($self) = @_;
  if (!defined $self->{kids}) { return (); }
  @{$self->{kids}};
}

sub get_sorted_kids {
  my ($self, $sortby) = @_;

  my $sortsub;
  if (defined $sortby) {
    $sortsub = $self->get_sort_sub($sortby);
  } elsif (defined $self->{sortkids}) {
    $sortsub = $self->get_sort_sub($self->{sortkids});
  } else {
    $sortsub = $self->get_sort_sub('score title declared');
  }
  sort $sortsub ($self->get_kids());
}

sub set_sort_string {
  my ($self, $str) = @_;
  $self->{sortkids} = $str;
}

# -------------------------------------------------------------------------

# get and eval() a sort subroutine for the given sorting criteria.
# stores cached sort sub { } refs in the %SORT_SUBS global array to
# avoid re-evaluating the same piece of perl code repeatedly.
#
sub get_sort_sub {
  my ($self, $sortstr) = @_;

  if (!defined $SORT_SUBS{$sortstr}) {
    my $sortsubstr = $self->{main}->{metadata}->string_to_sort_sub ($sortstr);
    my $sortsub = eval $sortsubstr;
    $SORT_SUBS{$sortstr} = $sortsub;
  }

  $SORT_SUBS{$sortstr};
}

# -------------------------------------------------------------------------

sub get_format {
  my ($self) = @_;
  if (!defined $self->{format}) { return 'text/html'; }
  return HTML::WebMake::FormatConvert::format_zname_to_name($self->{format});
}

# -------------------------------------------------------------------------

sub get_text_as {
  my ($self, $format) = @_;

  if (!defined $format) {
    carp ($self->as_string().": get_text_as with undef arg");
    return "";
  }

  my $fmt = $self->get_format();
  if (!defined $fmt) {
    carp ($self->as_string().": no format defined");
    return "";
  }

  $self->load_text_if_needed();

  # we cache format changes, unless (a) the content object is
  # strictly dynamic, such as navlinks or breadcrumbs or a sitemap;
  # (b) the formats are the same (obviously!), or (c) the length
  # of the text to reformat is smaller than a predefined minimum
  # cacheable length (currently $MIN_FMT_CACHE_LEN).
  #
  my $ignore_reformat_cache = 0;
  my $txt;

  if ($self->{is_navlinks}) {
    $txt = $self->get_navlinks_text();
    $ignore_reformat_cache = 1;

  } elsif ($self->{is_breadcrumbs}) {
    $txt = $self->get_breadcrumbs_text();
    $ignore_reformat_cache = 1;

  } elsif ($self->{keep_as_is}) {
    $txt = $self->get_as_is_text();

  } else {
    $txt = $self->get_normal_content_text();
  }

  if (!defined $txt) { die "undefined text for $self->{name}"; }

  if (!$ignore_reformat_cache) {
    if ($self->{is_sitemap}) { $ignore_reformat_cache = 1; }
    if ($self->{main}->{force_output}) { $ignore_reformat_cache = 1; }
    elsif (length ($txt) < $MIN_FMT_CACHE_LEN) { $ignore_reformat_cache = 1; }
  }

  # reformat before substs; this way we can cache the reformat
  # results for next time.
  if ($fmt ne $format) {
    # strip metadata before conversion
    $self->{main}->strip_metadata ($self->{name}, \$txt);
    # and subst tags before conversion
    $self->{main}->getusertags()->subst_tags ($self->{name}, \$txt);

    $txt = $self->{main}->{format_conv}->convert
	  ($self, $fmt, $format, $txt, $ignore_reformat_cache);

  } else {
    $self->{main}->getusertags()->subst_tags ($self->{name}, \$txt);
  }

  $self->{main}->subst ($self->{name}, \$txt);

  # always remove leading & trailing whitespace from HTML content.
  if ($format =~ /^text\/html$/i) {
    $txt =~ s/^\s+//s;$txt =~ s/\s+$//s;
  }

  $txt;
}

# -------------------------------------------------------------------------

sub get_navlinks_text {
  my ($self) = @_;

  $self->set_navlinks_vars ();
  return $self->{text};
}

# -------------------------------------------------------------------------

sub get_as_is_text {
  my ($self) = @_;

  $self->add_navigation_metadata();
  $self->add_extra_metas ($self->{name});
  $self->infer_implicit_metas();

  # if this content item is mapped, set a var called "__MainContentName"
  # so it'll be used as the "main" content item for the current page
  # while drawing the breadcrumb trail.
  if (!$self->{no_map} && !$self->is_generated_content())
  {
    $self->{main}->add_fileless_content ("__MainContentName",
   			 $self->{name}, undef, 1);
  }

  $self->touch_last_used();
  return $self->{text};
}

# -------------------------------------------------------------------------

sub get_normal_content_text {
  my ($self) = @_;

  $self->add_navigation_metadata();
  $self->parse_metadata_tags ($self->{name}, $self->{text});
  $self->add_extra_metas ($self->{name});
  $self->infer_implicit_metas();

  # if this content item is mapped, set a var called "__MainContentName"
  # so it'll be used as the "main" content item for the current page
  # while drawing the breadcrumb trail.
  if (!$self->{no_map} && !$self->is_generated_content())
  {
    $self->{main}->add_fileless_content ("__MainContentName",
   			 $self->{name}, undef, 1);
  }

  $self->touch_last_used();
  return $self->{text};
}

# -------------------------------------------------------------------------

sub load_text_if_needed {
  my ($self) = @_;

  if (defined $self->{text}) { return; }
  if (!defined $self->{location}) { return; }
  if (!defined $self->{datasource}) { return; }

  # deferred loading of content text.
  $self->touch_last_used();
  $self->{text} = $self->{datasource}->get_location ($self->get_filename());
}

sub unload_text {
  my ($self) = @_;

  if (defined $self->{datasource}) {
    dbg ($self->as_string().": unloading cached text, ".
    		"last used: ".$self->{last_used});
    delete $self->{text};
  }
}

sub is_from_datasource {
  my ($self) = @_;
  if (!defined $self->{datasource}) { return 0; }
  1;
}

sub touch_last_used {
  my ($self) = @_;

  if (defined $self->{datasource}) {
    $self->{last_used} = $self->{main}->{current_tick};
    dbg ("updating last used on ".$self->as_string().": ".$self->{last_used});
  }
}

# -------------------------------------------------------------------------

sub get_up_content {
  my ($self) = @_;
  my $cont;

  if (defined $self->{up_obj}) { return $self->{up_obj}; }

  # magic variables do not appear in the tree.
  if ($self->{name} =~ /^WebMake\./) { return undef; }

  # see if we got an "up" attr passed in.
  if (defined $self->{up_name}) {
    $cont = $self->up_name_to_content ($self->{up_name});
    if (defined $cont) { return $cont; }
    # else, it's not valid; clear it.
    undef $self->{up_name};
  }

  # see if we have an "up" metadatum.
  if (!$self->is_generated_content()) {
    my $meta = $self->{main}->expand_content_quietly
			  ("(meta)", $self->{name}.".up");
    if (defined $meta && $meta ne '') {
      $cont = $self->up_name_to_content ($meta);
      if (defined $cont) {
	return $cont;
      }
    }
  }

  # ach, no "up" item. Use the root content.
  return $self->up_name_to_content ($HTML::WebMake::SiteMap::ROOTNAME);
}

sub up_name_to_content {
  my ($self, $name) = @_;

  my $cont;
  if ($name eq $HTML::WebMake::SiteMap::ROOTNAME) {
    $cont = $self->{main}->getmapper()->get_root();
    if (!defined $cont) { return undef; }
  } else {
    $cont = $self->{main}->{contents}->{$name};
  }

  if (defined $cont) {
    $self->{up_name} = $name;
    $self->{up_obj} = $cont;
    return $cont;
  }

  warn $self->as_string().": \"up\" content not found: \$\{".
	      $name."\}\n";
  return undef;
}

# -------------------------------------------------------------------------

sub add_ref_from_url {
  my ($self, $filename) = @_;
  return if ($filename =~ /^\(/);	# (eval), (dep_ignore) etc.

  if (!defined $self->{reffed_in_url}) {
    $self->{reffed_in_url} = $filename;
    $self->{main}->getcache()->put_metadata ($self->{name}.".url", $filename);
  }
}

# -------------------------------------------------------------------------

=item $text = $cont->get_url();

Get a content item's URL.  The URL is defined as the first page listed in the
WebMake file's out tags which refers to that item of content.

Note that, in some cases, the content item may not have been referred to yet by
the time it's get_url() method is called.  In this case, WebMake will insert a
symbolic tag, hold the file in memory, and defer writing the file in question
until all other output files have been processed and the URL has been found.

=cut

sub get_url {
  my ($self) = @_;
  my $url = $self->{reffed_in_url};
  if (defined $url) { return $url; }

  $url = $self->{main}->getcache()->get_metadata ($self->{name}.".url");

  if (defined $url) {
    $self->{reffed_in_url} = $url;
    return $url;
  }

  $url = $self->{main}->make_deferred_url ($self->{name});
  return $url;
}

# -------------------------------------------------------------------------

sub set_next {
  my ($self, $cont) = @_;
  $self->{next_content} = $cont;
}

sub set_prev {
  my ($self, $cont) = @_;
  $self->{prev_content} = $cont;
}

sub set_up {
  my ($self, $cont) = @_;
  $self->{up_content} = $cont;
}

sub add_navigation_metadata {
  my ($self) = @_;

  return if ($self->{no_map} || $self->is_generated_content());
  return if ($self->{added_nav_metas_flag});
  $self->{added_nav_metas_flag} = 1;

  $self->create_extra_metas_if_needed();
  if (defined ($self->{up_content})) {
    $self->{extra_metas}->{'nav_up'} = $self->{up_content}->get_name();
  }
  if (defined ($self->{next_content})) {
    $self->{extra_metas}->{'nav_next'} = $self->{next_content}->get_name();
  }
  if (defined ($self->{prev_content})) {
    $self->{extra_metas}->{'nav_prev'} = $self->{prev_content}->get_name();
  }
}

sub invalidate_cached_nav_metadata {
  my ($self) = @_;
  $self->{added_nav_metas_flag} = 0;
}

# -------------------------------------------------------------------------

sub set_navlinks_vars {
  my ($self) = @_;

  foreach my $dir (qw{up prev next}) {
    my $contname = $self->navlinks_subst ("this.nav_".$dir."?");
    my ($obj, $url);

    if ($contname ne '') {
      $obj = $self->{main}->{contents}->{$contname};

      # if we haven't got the URL for that content object in our
      # cache, and it hasn't been evaluated, use a symbolic one
      # which the make() mechanism will fix later.
      if (!defined $obj || !defined ($url = $obj->get_url()) || $url eq '')
      {
	$url = $self->{main}->make_deferred_url ($contname);
      }

      # relativise it.
      $url = '$(TOP/)'.$url;

      if (!defined $self->{'nav_'.$dir}) {
	warn $self->as_string().": no name defined for '".$dir."'\n";
	next;
      }

      $self->{main}->add_fileless_content ("url", $url, undef, 1, 1);
      $self->{main}->add_fileless_content ("name", $contname, undef, 1, 1);
      $self->{main}->add_fileless_content ($dir."text",
	      $self->navlinks_subst ($self->{'nav_'.$dir}), undef, 1, 1);

    } elsif (defined $self->{'no_nav_'.$dir}) {		# optional attribute
      $self->{main}->add_fileless_content ($dir."text",
	      $self->navlinks_subst ($self->{'no_nav_'.$dir}), undef, 1, 1);

    } else {
      $self->{main}->add_fileless_content ($dir."text", '', undef, 1, 1);
    }
  }

  $self->{main}->del_content ("name");
  $self->{main}->del_content ("url");
}

sub navlinks_subst {
  my ($self, $var) = @_;
  if (!defined $var) { croak ($self->as_string().
    			": no var defined in navlinks_subst"); }
  $self->{main}->curly_subst ("(eval)", $var);
}

# -------------------------------------------------------------------------

sub get_breadcrumbs_text {
  my ($self) = @_;

  my $root = $self->{main}->getmapper()->get_root();
  if (!defined $root) {
    warn ($self->as_string().": need a root content for <breadcrumbs>!\n");
    return "";
  }

  # to illustrate this, let's consider this chain of contents:
  # TOPPAGE -> CONTENTS -> STORY -> TAILPAGE.
  # $self is TAILPAGE at this point.

  my @uplist = ();
  my $contname = $self->{main}->curly_subst ("(eval)", "__MainContentName");
  if (!defined $contname) {
    dbg ($self->as_string().": no mapped content on page");
    return "";
  }
  my $obj = $self->{main}->{contents}->{$contname};
  if (!defined $obj) {
    dbg ($self->as_string().": cannot find mapped content \${$contname}");
    return "";
  }

  while (1) {
    push (@uplist, $obj); last if ($obj == $root);
    my $upobj = $obj->get_up_content();
    last unless defined $upobj;
    last if ($upobj == $obj);
    $obj = $upobj;
  }
  # @uplist = (TAILPAGE, STORY, CONTENTS, TOPPAGE)

  @uplist = reverse @uplist;
  # @uplist = (TOPPAGE, STORY, CONTENTS, TAILPAGE)

  my $top = shift @uplist;
  # @uplist = (STORY, CONTENTS, TAILPAGE)

  my $tail = pop @uplist;
  # @uplist = (STORY, CONTENTS)

  my $text = '';
  if (defined $top && defined $self->{breadcrumb_top_name}) {
    $text .= $self->cook_a_breadcrumb ($top, $self->{breadcrumb_top_name});
  }
  foreach $obj (@uplist) {
    $text .= $self->cook_a_breadcrumb ($obj, $self->{breadcrumb_level_name});
  }
  if (defined $tail && defined $self->{breadcrumb_tail_name}) {
    $text .= $self->cook_a_breadcrumb ($tail, $self->{breadcrumb_tail_name});
  }

  $self->{main}->del_content ("name");
  $self->{main}->del_content ("url");
  $text;
}

sub cook_a_breadcrumb {
  my ($self, $obj, $linktmpl) = @_;

  # if we haven't got the URL for that content object in our
  # cache, and it hasn't been evaluated, use a symbolic one
  # which the make() mechanism will fix later.
  my $url;
  if (!defined ($url = $obj->get_url()) || $url eq '') {
    $url = $self->{main}->make_deferred_url ($obj->{name});
  }

  # relativise it.
  $url = '$(TOP/)'.$url;

  $self->{main}->add_fileless_content ("url", $url, undef, 1, 1);
  $self->{main}->add_fileless_content ("name", $obj->{name}, undef, 1, 1);
  return $self->{main}->curly_subst ("(eval)", $linktmpl);
}

# -------------------------------------------------------------------------

sub is_only_usable_from_deferred_refs {
  my ($self) = @_;
  return ($self->{only_usable_from_def_refs}) ? 1 : 0;
}

# -------------------------------------------------------------------------

1;
