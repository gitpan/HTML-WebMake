require 5.005;
use ExtUtils::MakeMaker;

sub MY::libscan {
  my($self,$path) = @_;

  return '' if ($path =~ /windows_install/
		|| $path =~ /WebMakeCGI/	# not ready yet
		);

  $path;
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'HTML::WebMake',
    'VERSION_FROM' => 'lib/HTML/WebMake/Main.pm', # finds $VERSION

    'EXE_FILES'	=> ['webmake'],

    'PMLIBDIRS' => [ 'lib' ],

    'PREREQ_PM' => {
      			'File::Spec' => 0,
			'Text::EtText' => 0,
		  },

    'dist' => { COMPRESS => 'gzip -9f', SUFFIX => 'gz',
	      DIST_DEFAULT => 'tardist' },

    'clean' => { FILES =>
	't/log t/.webmake doc/.webmake examples/.webmake pod2html* '.
	'examples/*html WebMake.spec doc/pod2html*'
    },

    'AUTHOR' => 'Justin Mason <jm@jmason.org>',
    'ABSTRACT' => 'A simple CMS with templating and metadata'

);

