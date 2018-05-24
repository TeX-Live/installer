# DO NOT EDIT. CREATED AUTOMATICALLY BY myConfig
package Tk::Config;
require Exporter;
use base qw(Exporter);
$VERSION = '804.034';
$inc = '-I$(TKDIR) -I$(TKDIR)/pTk/mTk/xlib';
$define = '';
$xlib = '';
$xinc = '';
$gccopt = ' -Wall -Wno-implicit-int -Wno-comment -Wno-unused -D__USE_FIXED_PROTOTYPES__';
$win_arch = 'MSWin32';
@EXPORT = qw($VERSION $inc $define $xlib $xinc $gccopt $win_arch);
1;
