# PerlCode; allow arbitrary perl code be embedded in a WebMake file.

package HTML::WebMake::PerlCode;

require Exporter;
use Carp;
use strict;
use IO::Handle;

use HTML::WebMake::Main;
use HTML::WebMake::PerlCodeLibrary;

use vars	qw{
  	@ISA @EXPORT 
	$GlobalSelf @PrevSelves %SORT_SUBS $PipeDelimiter
};

@ISA = qw(Exporter);
@EXPORT = qw();

# ho ho, what a kludge
$PipeDelimiter = '!!!EnDoFwEBmAKEpipEOUtPut!!!';

###########################################################################

sub new ($$) {
  my $class = shift;
  $class = ref($class) || $class;
  my ($main) = @_;

  # Open a pipe, set autoflush on for the write 
  # side and make the read side non-blocking
  pipe(RP,WP);
  WP->autoflush(1);
  # RP->blocking(0);	# not supported on 5.00503 -- use delimiters instead.

  my $self = {
    'main'		=> $main,
    'readpipe'          => *RP,
    'writepipe'         => *WP
  };
  bless ($self, $class);
  $self;
}

sub finish {
  close RP;
  close WP;
}

sub dbg { HTML::WebMake::Main::dbg (@_); }

# -------------------------------------------------------------------------

sub interpret { 
  my ($self, $type, $str) = @_;
  my ($ret);
  local ($_) = '';

  if ($self->{main}->{paranoid}) {
    return "\n(Paranoid mode on - perl code evaluation prohibited.)\n";
  }

  # note that both $self and $_ are available from within evaluated
  # perl code.

  $self->enter_perl_call();

  if ($type ne "perlout") {
    $ret = eval 'package main;'.$str;
  }
  else {
    my ($readpipe, $writepipe) = ($self->{readpipe}, $self->{writepipe});
    local(*STDOUT) = *$writepipe;

    $ret = eval 'package main;'.$str;

    if (defined($ret)) {
      print $writepipe "\n".$PipeDelimiter."\n";
      $ret = '';
      while (<$readpipe>) {
	/^${PipeDelimiter}$/o and last;
	$ret .= $_;
      }
      chomp $ret;
    }
  }

  $self->exit_perl_call();

  if (!defined $ret) {
    warn "<{perl}> code failed: $@\nCode: $str\n";
    $ret = '';
  }
  $ret;
}

sub enter_perl_call {
  my ($self) = @_;
  push (@PrevSelves, $GlobalSelf); $GlobalSelf = $self;
}

sub exit_perl_call {
  my ($self) = @_;
  $GlobalSelf = pop (@PrevSelves);
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

1;
