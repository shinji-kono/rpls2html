#!/usr/bin/perl

use strict;
use Getopt::Std;

my $version = "0.22";

our($opt_g, $opt_d,$opt_f,$opt_h, $opt_r);
getopts('gdfhr');

my $detail = $opt_d;
my $show_file = $opt_f;
my $idid = "id000000";

open(OUT,"| nkf -wZ");
select OUT;

my $kin = "\033\$B";
my $kout = "\033\(B";
my $hout = "\033\(I";
my @title;
my @detail;

my $both = 0;

opening() if ($opt_h) ;

my @v;

if ( $opt_r ) {
    open(my $fd,"find -s . -print|");
    while (<$fd>) {
       chop;
       push(@v,$_);
    }
}  else {
    @v = @ARGV;
}

for my $arg (@v) {
    if ($arg =~ /rpls/i) { &rpls($arg) 
    } elsif ($arg =~ /VR_MANGR.IFO/i) { &dvdtitle($arg) 
    } elsif ($arg =~ /\.png|\.jpg/i) { &video($arg) 
    }
}

for my $arg (@v) {
    if ($arg =~ /TTDETAIL.IFO/i) { &ttdetail($arg) 
    }
}


closing() if ($opt_h) ;
close OUT;

exit 0;

my $dir;
my $dir1;
my $prevtitle = "-----";
my $prevdstr = "-----";

sub checkdir {
    my ($file) = @_;

    my $mdir = "./";
    if ($file =~ m=(.*)/([^/]+)$=) {
        $mdir = $1;
    }
    my $dir2 = $mdir;
    $dir2 =~ s-/TS_MANGR--;
    $dir2 =~ s-/DVD_RTAV--;
    @detail = ();
    if ($dir1 ne $dir2) { 
        @title = ();
        $prevtitle = "-----";
        $prevdstr = "-----";
        $dir1 = $dir2;
    }
    $dir = $mdir;
    $both = 0;
    if ($file =~ /VR_MANGR.IFO/i) {
        $both = 3;
        my $tt1 =  "$dir/TTDETAIL.IFO";
        my $tt2 =  "$dir1/TS_MANGR/TTDETAIL.IFO";
        if (-f $tt1) {
            &ttdetail($tt1) ;
        } elsif (-f $tt2) {
            &ttdetail($tt2) ;
        } else {
            $both = 0;
        }
    } 
}

sub video {
    my ($file) = @_;
    # thumbnail of DVD Video
    &checkdir($file);
    my $txt = $dir."title.txt";
    if ($opt_h) {
        print "<p> $dir <a href=\"$file\"> <img src=\"$file\" height=\"200\" style=\"vertical-align: top\"> </a>\n";
    }
    print "$file \n" if ($show_file);
    &cat($txt) if ( -f $txt) ;
}

sub cat {
    my ($file) = @_;
    local($/); undef $/;
    open my $h,"<",$file or die("$! $file");
    my $buf ;
    $buf .= <$h>;
    print $buf;
}

my $gr = 'H';   # GR is single byte A, double byte B
my $g0 = 'A';   # G0 .. G3 is single byte A, double byte B
my $g1 = 'I';  
my $g2 = 'H';  
my $g3 = 'K';  
my $grp = $gr;  

sub rpls {

    my ($file) = @_;
    local($/); undef $/;
    open my $h,"<",$file or die("$! $file");
    my $buf ;
    $buf .= <$h>;
    &checkdir($file);
    my $mydir = $dir; $mydir =~ s/\/PLAYLIST//i;

    my $dd = unpack("H*",substr($buf,0x32,0x3c-0x32));

    my $year1 = substr($dd,0,4);
    my $month1= substr($dd,4,2);
    my $day1  = substr($dd,6,2);
    my $hour2 = substr($dd,8,2);
    my $min2  = substr($dd,10,2);
    my $hour3 = substr($dd,12,4);
    my $min3  = substr($dd,16,2);
    my $sec3  = substr($dd,18,2);
    $gr = 'H'; 
    $g0 = 'A'; 
    $g1 = 'I';  
    $g2 = 'H';  
    $g3 = 'K';  
    $grp = $gr;  

    $hour3 = ($hour3==0) ? "" : ($hour3+0).":";
    my $name = substr($buf,0,8);

    my $chlen = unpack("C",substr($buf,0x43,1));
    my $channel = $kin. substr($buf,0x44,$chlen) . $kout;
    my $tilen = unpack("C",substr($buf,0x58,1));
    my $ti =  &string1(substr($buf,0x59,$tilen));
    $ti = 'no title' if ( $ti eq '' );

    if ($opt_g) {
        print unpack("H*",substr($buf,0x59,$tilen)),"\n";
        print unpack("H*",$ti),"\n";
    }
    if ($opt_h) {
        my $mts =  substr($buf,0x63c,9);
        $mts = &findMts($mts,$file);
        if (-f $mts) {
            my $size = -s $mts;
            print "<p>$mydir <a href=\"$mts\"> $ti </a>";
	    if ($size) {
		printf(" %2.1fGB ",$size/1000000000.0);
	    }
        } else {
            print "<p>$mydir $ti ";
        }
    } else {
        print "$file $name " if ($show_file);
    }

    # my $offset = 0x59;
    # print &string($buf,$offset);

    print $ti if (! $opt_h);

    my $s;
    my $offset = 0x159;

    my $abst =  &string($buf, $offset);

    if ($detail || $opt_h) {
        # print "\n\n",0x159," $offset\n";

        my $rest = &string1(substr($buf,$offset,0x600-$offset));
        if ($opt_h) {
            &detail('*',$rest);
            print "$abst\n\n";
        } else {
            print "$abst\n\n";
            print $rest;
        }
    } else {
        print $abst;
    }
    print "\n\n";
    print "$year1/$month1/$day1 $hour2:$min2 $hour3$min3.$sec3 ";
    print "$channel\n\n";

    print " $kout\n\n\n";
    # print " $kout$offset\n";

}

sub findMts {
    my ($mts, $file) = @_;
    $file =~ m=^(.*)/[^/]+$=;
    my $dir = $1;
    $file =~ s/.*\///; 
    $file =~ s/rpls/m2ts/; 
    my $f1 = "$dir/$file"; return $f1 if (-f $f1 );

    $mts =~ s/M2TS//; $mts .= ".m2ts";
    my $f = "$dir/$file"; return $f if (-f $f );
    $f = "$dir/$mts"; return $f if (-f $f );
    $dir =~ s=/[^/]+$==;
    $f = "$dir/$file"; return $f if (-f $f );
    $f = "$dir/$mts"; return $f if (-f $f );
    my $dir1 = "$dir/stream";
    my $f2 = "$dir1/$file"; return $f2 if (-f $f2 );
    $f = "$dir1/$mts"; return $f if (-f $f );
    my $dir2 = "$dir/../stream";
    $f = "$dir2/$mts"; return $f if (-f $f );
    my $f3 = "$dir2/$file"; return $f3 if (-f $f3 );
    return "";
}

sub findMov {
    #  DVD_RTAV/VR_MOVIE.VRO 
    my ($file) = @_;
    $file =~ m=^(.*)/[^/]+$=;
    my $dir = $1;
    $dir =~ s/ /\\ /g;
    my $mts = "VR_MOVIE.VRO";
    my $f = "$dir/$mts"; return $f if (-f $f );
    my @mpg = <$dir/*.MPG>;
    my $f = $mpg[0]; return $f if (-f $f );
    my @mpg = <$dir/*.mpg>;
    my $f = $mpg[0]; return $f if (-f $f );
    $dir =~ s=/[^/]+$==;
    $f = "$dir/$mts"; return $f if (-f $f );
    #  *.MPG
    my @mpg = <$dir/*.MPG>;
    return $mpg[0] if ( -f $mpg[0] );
    my @mpg = <$dir/*.mpg>;
    return $mpg[0] if ( -f $mpg[0] );
    $dir .= "/DVD_RTAV";
    $f = "$dir/$mts"; return $f if (-f $f );
    #  *.MPG
    my @mpg = <$dir/*.MPG>;
    return $mpg[0] if ( -f $mpg[0] );
    my @mpg = <$dir/*.mpg>;
    return $mpg[0] if ( -f $mpg[0] );
    return "";
}

sub detail {
    my ($abst, $rest) = @_;
    return if ( $rest !~ /\w+/ ) ;
    print "<a id=info  href=\"somewhere.html\">$abst\n";
    print "<span>",$rest,"</span></a>\n";
    # print "**",unpack("H*",$rest),"**\n";
}


sub string {
    my ($buf, $offset) = @_;
    my $str;
    my $len = unpack("C",substr($buf,$offset++,1)); 
    $str .=  &string1(substr($buf,$offset,$len));
    $offset+=$len ;
    $_[1] = $offset;
    return $str;
}

sub string1 {
    local ($_) = @_;
    my $s = $kin;
    my $im = 'J';
    my $om = 'J';
    #  I JIS X 0201
    #  H JIS X 0208 first page?
    while ($_ ne '') {
        if ( s/^\0\0+// ) { next;
        } elsif ( s/^\0// ) {  last;
        } elsif ( s/^\x0e// ) {  $im = 'A'; next;
        } elsif ( s/^\x0f// ) {  $im = 'J'; next;
        } elsif ( s/^[\x8a\x89]// ) {  next;
        } elsif ( s/^\x1b\x24\x3b//) { $im = 'J'; $g0 = 'H';  next;
        } elsif ( s/^\x1b\x24\x39//) { $im = 'J';  next;
        } elsif ( s/^\x1b\x24\x29\x3b//) { $im = 'J'; $g1 = 'H';  next;
        } elsif ( s/^\x1b\x24\x29.//) { $im = 'J'; $g1 = 'J';  next;
        } elsif ( s/^\x1b\x29\x4a//) { $im = 'A';  next;
        } elsif ( s/^\x1b\x28\x20\x49//) { $g0 = 'I';  next;
        } elsif ( s/^\x1b\x29\x20\x49//) { $g1 = 'I';  next;
        } elsif ( s/^\x1b\x2a\x20\x49//) { $g2 = 'I';  next;
        } elsif ( s/^\x1b\x2b\x20\x49//) { $g3 = 'I';  next;
        } elsif ( s/^\x1b\x28\x20.//) { $g0 = 'A';  next;
        } elsif ( s/^\x1b\x29\x20.//) { $g1 = 'A';  next;
        } elsif ( s/^\x1b\x2a\x20.//) { $g2 = 'A';  next;
        } elsif ( s/^\x1b\x2b\x20.//) { $g3 = 'A';  next;
        } elsif ( s/^\x1b\x28\x49//) {  $g0 = 'I'; next;
        } elsif ( s/^\x1b\x29\x49//) {  $g1 = 'I'; next;
        } elsif ( s/^\x1b\x2a\x49//) {  $g2 = 'I'; next;
        } elsif ( s/^\x1b\x2b\x49//) {  $g3 = 'I'; next;
        } elsif ( s/^\x1b\x28.//) {  $g0 = 'A'; next;
        } elsif ( s/^\x1b\x29.//) {  $g1 = 'A'; next;
        } elsif ( s/^\x1b\x2a.//) {  $g2 = 'A'; next;
        } elsif ( s/^\x1b\x2b.//) {  $g3 = 'A'; next;
        } elsif ( s/^\x1b\x24\x28\x20.//) { $g0 = 'J'; next;
        } elsif ( s/^\x1b\x24\x29\x20.//) { $g1 = 'J'; next;
        } elsif ( s/^\x1b\x24\x2a\x20.//) { $g2 = 'J'; next;
        } elsif ( s/^\x1b\x24\x2b\x20.//) { $g3 = 'J'; next;
        } elsif ( s/^\x1b\x24\x28.//) {  $g0 = 'J'; next;
        } elsif ( s/^\x1b\x24\x29.//) {  $g1 = 'J'; next;
        } elsif ( s/^\x1b\x24\x2a.//) {  $g2 = 'J'; next;
        } elsif ( s/^\x1b\x24\x2b.//) {  $g3 = 'J'; next;
        } elsif ( s/^\x1b\x7e//) {  $gr = $g1 ; next;
        } elsif ( s/^\x1b\x7d//) {  $gr = $g2 ; next;
        } elsif ( s/^\x1b\x7c//) {  $gr = $g3 ; next;
        }
        if ($gr ne $grp) {
            $grp = $gr; print "gr = $gr $g0 $g1 $g2 $g3\n" if ($opt_g);
        }
        if (s/^[\x0-\x20]//) {
            if ($om eq 'J') { $s .= $kout; $om = 'A'; }
            $s .= $&; next;
        }
        if ($im eq 'A') {
            if ($om eq 'J') { $s .= $kout; $om = 'A'; }
            s/^.//; $s .= $&; next;
        }
        my $h;
        if (/^(.)/ && ord($1) > 0x7f) {
            next if ( s/^\xfa.//) ;
            my $i = ord($1);
            if ($gr eq 'H') {
               print "ord ",sprintf("%x",$i)," $gr\n" if ($opt_g);
               s/^.//;
               if ($om eq 'A') { $s .= $kin; $om = 'J'; }
               $s .= chr(0x24).chr($i-0x80);
               next;
           } elsif ($gr eq 'K') {
               print "ord ",sprintf("%x",$i)," $gr\n" if ($opt_g);
               s/^.//;
               if ($om eq 'A') { $s .= $kin; $om = 'J'; }
               $s .= chr(0x25).chr($i-0x80);
               next;
            } elsif ($gr ne 'I') {
               print "ord ",$i," $gr\n" if ($opt_g);
               s/^..// if ($gr eq 'J') ;
               s/^.// if ($gr eq 'A') ;
               next;
            } else {
               print "ord ",$i," I\n" if ($opt_g);
            }
        }
        if ( s/^\x7a\x50//) { $h .= "[HV]";
        } elsif ( s/^\x7a\x51//) { $h .= "[SD]";
        } elsif ( s/^\x7a\x52//) { $h .= "[P]";
        } elsif ( s/^\x7a\x54//) { $h .= "[MV]";
        } elsif ( s/^\x7a\x5d//) { $h .= "[SS]";
        } elsif ( s/^\x7a\x72//) { $h .= "[PPV]";
        } elsif ( s/^\x7e\x21.//) { $h .= "[I]";
        } elsif ( s/^\x7e\x22.//) { $h .= "[II]";
        } elsif ( s/^\x7e\x23.//) { $h .= "[III]";
        } elsif ( s/^\x7e\x24.//) { $h .= "[IV]";
        } elsif ( s/^\x7e\x25.//) { $h .= "[V]";
        } elsif ( s/^\x7e\x26.//) { $h .= "[VI]";
        } elsif ( s/^\x7e\x27.//) { $h .= "[VII]";
        } elsif ( s/^\x7e\x28.//) { $h .= "[VIII]";
        } elsif ( s/^\x7e\x29.//) { $h .= "[IX]";
        } elsif ( s/^\x7e\x2a.//) { $h .= "[X]";
        } elsif ( s/^\x7e\x2b.//) { $h .= "[XI]";
        } elsif ( s/^\x7e\x2c.//) { $h .= "[XII]";
        } elsif ( s/^\x7e\x2d.//) { $h .= "[17]";
        } elsif ( s/^\x7e\x2e.//) { $h .= "[18]";
        } elsif ( s/^\x7e\x2f.//) { $h .= "[19]";
        } elsif ( s/^\x7e\x30.//) { $h .= "[20]";
        } elsif ( s/^\x7e\x61.//) { $h .= "[1]";
        } elsif ( s/^\x7e\x62.//) { $h .= "[2]";
        } elsif ( s/^\x7e\x63.//) { $h .= "[3]";
        } elsif ( s/^\x7e\x64.//) { $h .= "[4]";
        } elsif ( s/^\x7e\x65.//) { $h .= "[5]";
        } elsif ( s/^\x7e\x66.//) { $h .= "[6]";
        } elsif ( s/^\x7e\x67.//) { $h .= "[7]";
        } elsif ( s/^\x7e\x68.//) { $h .= "[8]";
        } elsif ( s/^\x7e\x69.//) { $h .= "[9]";
        } elsif ( s/^\x7e\x6a.//) { $h .= "[10]";
        } elsif ( s/^\x7e\x6b.//) { $h .= "[11]";
        } elsif ( s/^\x7e\x6c.//) { $h .= "[12]";
        } elsif ( s/^\x7e\x6d.//) { $h .= "[13]";
        } elsif ( s/^\x7e\x6e.//) { $h .= "[14]";
        } elsif ( s/^\x7e\x6f.//) { $h .= "[15]";
        } elsif ( s/^\x7e\x70.//) { $h .= "[16]";
        }
        if ($h) {
            if ($om eq 'J') { $s .= $kout; $om = 'A'; }
            $s .= $h;
            next;
        }
        my $a = "!N"; my $b = "!O";
        if ($om eq 'A') { $s .= $kin; $om = 'J'; }
        if ( s/^\x7c.//) {  next;
        } elsif ( s/^\x7d.//) {  next;
        }
        if ( s/^\x7a\x52//) { $s .= "#P";
        } elsif ( s/^\x7a\x53//) { $s .= $a."#W".$b;
        } elsif ( s/^\x7a\x55//) { $s .= $a."<j".$b;
        } elsif ( s/^\x7a\x56//) { $s .= $a.";z".$b;
        } elsif ( s/^\x7a\x57//) { $s .= $a."AP".$b;
        } elsif ( s/^\x7a\x58//) { $s .= $a."\%G".$b;
        } elsif ( s/^\x7a\x59//) { $s .= $a."#S".$b;
        } elsif ( s/^\x7a\x5a//) { $s .= $a."Fs".$b;
        } elsif ( s/^\x7a\x5b//) { $s .= $a."B?".$b;
        } elsif ( s/^\x7a\x5c//) { $s .= $a."2r".$b;
        } elsif ( s/^\x7a\x5e//) { $s .= $a."#B".$b;
        } elsif ( s/^\x7a\x5f//) { $s .= $a."#N".$b;
        } elsif ( s/^\x7a\x60//) { $s .= $a."\"#".$b;
        } elsif ( s/^\x7a\x61//) { $s .= $a."\!|".$b;
        } elsif ( s/^\x7a\x62//) { $s .= $a."E7".$b;
        } elsif ( s/^\x7a\x63//) { $s .= $a."8r".$b;
        } elsif ( s/^\x7a\x64//) { $s .= $a."1G".$b;
        } elsif ( s/^\x7a\x65//) { $s .= $a."L5".$b;
        } elsif ( s/^\x7a\x66//) { $s .= $a."NA".$b;
        } elsif ( s/^\x7a\x67//) { $s .= $a."80".$b;
        } elsif ( s/^\x7a\x68//) { $s .= $a."A0".$b;
        } elsif ( s/^\x7a\x69//) { $s .= $a."8e".$b;
        } elsif ( s/^\x7a\x6a//) { $s .= $a.":F".$b;
        } elsif ( s/^\x7a\x6b//) { $s .= $a."\?7".$b;
        } elsif ( s/^\x7a\x6c//) { $s .= $a."\=i".$b;
        } elsif ( s/^\x7a\x6d//) { $s .= $a."\=*".$b;
        } elsif ( s/^\x7a\x6e//) { $s .= $a."\@8".$b;
        } elsif ( s/^\x7a\x6f//) { $s .= $a."HN".$b;
        } elsif ( s/^\x7a\x70//) { $s .= $a."\@<".$b;
        } elsif ( s/^\x7a\x71//) { $s .= $a."\?a".$b;
        } elsif ( s/^\x7a\x73//) { $s .= $a."Hk".$b;
        } elsif ( s/^\x7a\x74//) { $s .= $a."\$\[\$\+".$b;
        } elsif ( s/^..//) { $s .= $&;
        } elsif ( s/^.//) { 
            if ($om eq 'J') { $s .= $kout; $om = 'A'; }
            $s .= $&;
        }
    }

    if ($om eq 'J') { $s .= $kout; $om = 'A'; }
    return '' if ($s eq $kin.$kout);
    return $s;
}

my %ttdone;

sub ttdetail { 

    my ($file) = @_;
    next if ($ttdone{$file});
    $ttdone{$file} = 1;

    local($/); undef $/;
    open my $h,"<",$file or die("$! $file");
    my $buf ;
    $buf .= <$h>;

    print "$file\n" if ($show_file);
    # &checkdir($file);

    my $mov = &findMov($file);
    my $num_title = unpack("N",substr($buf,4,4));
    # print "$num_title\n";

    my $offset = 0;
    all: for(my $i = 0;$i<$num_title;$i++) {
        for(;;) {
            my $flag =  unpack("n",substr($buf,$offset+0xe,2)) ;
            last if ($flag==1);
            $offset +=0x10;
            last all if ($offset > length($buf));
        }
        my $desc = substr($buf,$offset+0x1c,0x330-0x1c);
        $desc =~ s/\0//g;
        # print "$year/$month/$day\n"; #  $hour:$min:$sec\n";
        if ($both==3) {
            if ($title[$i]) {
                if ($opt_h) {
                    if (-f $mov) {
                        my $size = -s $mov;
                        print "<p>$dir1<a href=\"$mov\"> $title[$i] </a> ";
                        if ($size) {
                            printf(" %2.1fGB ",$size/1000000000.0);
                        }
                    } else {
                        print "$dir1<p>$title[$i] ";
                    }
                    if ($desc) {
                        &detail('*', $desc);
                    } 
                } elsif ($detail) {
                    print "$title[$i] $desc\n\n"; 
                } else {
                    print "$title[$i]\n\n"; 
                }
                $title[$i] = '';
            } else {
                if (! $desc) {
                    $desc = "1"; # to notice we have passed TTDETAIL
                }
            }
            $detail[$i] = $desc;
        } else {
            print "$dir1 $desc\n\n";
        }

        $offset += 0x330;
    }

}

sub dvdtitle { 

    my ($file) = @_;
    local($/); undef $/;
    open my $h,"<",$file or die("$! $file");
    my $buf ;
    $buf .= <$h>;

    print "$file\n" if ($show_file);
    my $offset = unpack("N",substr($buf,0x104,4)) ;
    # printf "offset %x\n",$offset;
    &checkdir($file);

    my $num_title = unpack("n",substr($buf,$offset+8,2));
    # print "$num_title\n";

    my $mov = &findMov($file);
    my @td;

    my $dstr = '';
    my $od = unpack("N",substr($buf,0x160,4));
    my $count = unpack("n",substr($buf,$od+2,2));
    if ($count==$num_title) {
           # Panasonic case
           my $ofs = unpack("n",substr($buf,$od+8,2));
           $od += $ofs;
           # print "ddd $count\n";
           my $i = 0;
           for(;;) {
              my $ty = unpack("C",substr($buf,$od,1));
              if ($ty == 1) {
                  $od+=1; next;
              } elsif ($ty == 0) {
                  last;
              }
              my $len = unpack("C",substr($buf,$od+1,1));
              my $s = substr($buf,$od+2,$len);
              $od += $len+2;
              if ($ty == 0x90 && $len==0x1b) {
                   my $year = substr($s,11,4);
                   my $month = substr($s,15,2);
                   my $day = substr($s,17,2);
                   my $hour = substr($s,19,2);
                   my $min = substr($s,21,2);
                   $td[$i++] = "$year/$month/$day $hour:$min";
              }
              # printf "ty0x%x len 0x%x s %s\n",$ty, $len,$s;
           }
           # print $dst;
    }

    for(my $i=0;$i<$num_title;$i++) {

        my $dstr = substr($buf,$offset+0x10,0x40);
        if ($dstr =~ /\#Toshiba\#(.*)/) {
            # Toshiba case
            my $year = substr($dstr,30,2) + 2000;
            my $month = substr($dstr,32,2);
            my $day = substr($dstr,34,2);
            my $shour = substr($dstr,40,2);
            my $smin = substr($dstr,42,2);
            my $ehour = substr($dstr,44,2);
            my $emin = substr($dstr,46,2);
            $dstr = "$year/$month/$day $shour:$smin-$ehour:$emin";
        }  elsif ($td[$i]) {
            $dstr = $td[$i];
        }

        my $title = substr($buf,$offset+0x50,0x40);
        $title =~ s/\0//g;
        if ($prevtitle ne $title) {
            $prevtitle = $title;
            $prevdstr = $dstr;
        } elsif ($prevdstr ne $dstr) {
            $prevdstr = $dstr;
        } else {
            $offset += 0x8e;
            next;
        }
        if ($both==3) {
            if ($detail[$i]) {
                if ($opt_h) {
                    if (-f $mov) {
                        my $size = -s $mov;
                        print "<p>$dir1 <a href=\"$mov\"> $title </a> ";
                        if ($size) {
                            printf(" %2.1fGB ",$size/1000000000.0);
                        }
                    } else {
                        print "<p>$dir1 $title ";
                    }
                    if ($detail[$i] && $detail[$i] ne "1") {
                        &detail('*', $detail[$i]);
                    } 
                    print "$dstr";
                } else {
                    print "$title\t$dstr\n";
                    if ($detail && $detail[$i] ne "1") {
                        print $detail[$i]; 
                    }
                    print "\n\n";
                }
                $detail[$i] = '';
            } else {
                $title[$i] = "$title\t$dstr\n";
            }
        } else {
            if ($opt_h) {
                if (-f $mov) {
                    my $size = -s $mov;
                    print "<p>$dir1 <a href=\"$mov\"> $title </a> $dstr\n";
		    if ($size) {
			printf(" %2.1fGB ",$size/1000000000.0);
		    }
                } else {
                    print "<p>$dir1 $title $dstr\n";
                }
            } else {
                print "$dir1 $title\t$dstr\n";
            } 
        }

        $offset += 0x8e;
    }


}

sub opening {
print <<RogueRogue;
<html>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<title>Title List</title>
<STYLE type="text/css">
body { column-count: 2 }
a#info{
    position:relative; /*this is the key*/
    text-decoration:none}
a#info:hover{z-index:25; }
a#info span{display: none}
a#info:hover span{ /*the span will display just on :hover state*/
    display:block;
    position:absolute;
    top:2em; left:2em; width:40em;
    background-color:#cff; color:#000;
    }
</STYLE>
<body>
RogueRogue
# <!--入口--->
}


sub closing {
    printf "</body></html>\n";
}



1;

__END__


=head1 NAME

rpls.pl -- Display title/description of DVD / BD-R

=head1 SYNOPSIS

  rpls.pl  -d /Volumes/DVD/**/*.IFO
  rpls.pl  /Volumes/BDR/**/*.rpls

=head1 ABSTRACT

Read title and description for DVD TTDETAIL.IFO and VR_MANGR_IFO or BDR .rpls files.

=head1 DESCRIPTION

=head2 EXPORT

=head1 SEE ALSO

=head1 AUTHOR

Shinji KONO, E<lt>kono@ie.u-ryukyu.ac.jpE<gt>

=head1 COPYRIGHT AND LICENSE

  rpls.pl -- Display title/description of DVD / BD-R

  Copyright (C) 2012  Shinji Kono

    Everyone is permitted to do anything on this program 
    including copying, modifying, improving,
    as long as you don't try to pretend that you wrote it.
    i.e., the above copyright notice has to appear in all copies.  
    Binary distribution requires original version messages.
    You don't have to ask before copying, redistribution or publishing.
    THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE.



