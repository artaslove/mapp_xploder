#!/usr/bin/perl

sub inttohex4 {
 my $hexval=sprintf("%08X",$_[0]);
 my $vala=substr($hexval,6,2);
 my $valb=substr($hexval,4,2);
 my $valc=substr($hexval,2,2);
 my $vald=substr($hexval,0,2);
 $_[1]=pack("H8","$vala$valb$valc$vald");
}

sub inttohex2 {
 my $hexval=sprintf("%04X",$_[0]);
 my $vala=substr($hexval,2,2);
 my $valb=substr($hexval,0,2);
 $_[1]=pack("H4","$vala$valb");
}

sub hextoint4 {
 my $vala=hex(unpack("H2",substr($_[0],0,1)));
 my $valb=hex(unpack("H2",substr($_[0],1,1)))*256;
 my $valc=hex(unpack("H2",substr($_[0],2,1)))*65536;
 my $vald=hex(unpack("H2",substr($_[0],3,1)))*16777216; 
 $_[1]=$vala+$valb+$valc+$vald; 
}

sub hextoint2 {
 my $vala=hex(unpack("H2",substr($_[0],0,1)));
 my $valb=hex(unpack("H2",substr($_[0],1,1)))*256;
 $_[1]=$vala+$valb; 
}

my $MAPPHEADER = "^.{8}\x4E\x49\x4D\x61";
my $MAPPFOOTER = "\x00\x00\x03\x00\x00\x00\x02\x01";
my $AUDIOHEADER = "\x00\x00\x00\x00\x20\x00\x00\x00\x01\x00\x00\x00";
my $AUDIOFOOTER = "\x65\x6E\x74\x72\x54.{87}";

foreach my $file ( @ARGV )
{
 if ( -e $file && not -d $file ) {
  print "\e[1;31mXploding Reaktor Mapp file $file...\e[0m\n"; 
  if ( not -e "$file.sounds" ) { 
   mkdir "$file.sounds";
  }
  my $data = do { local $/; open my( $fh ), $file; <$fh> };
  $data =~ m/($MAPPHEADER.{8}.*?)$MAPPFOOTER/s;    
  my $mappoffset = length($1);
  while( substr($data,$mappoffset) =~ m/($MAPPFOOTER.*?$AUDIOFOOTER)/sg )
  {
   my $image = $1;
   $image =~ m/^.*?[\/\\](.*?)\x00/s;
   my $namelength = length($1);
   $1 =~ m/.*[\/\\](.*)/s;
   my $wavname = $1;
   $wavname =~ s/%(..)/pack('c', hex($1))/eg;
   $wavname =~ s/\..*$//; 	
   my $sampleshex = substr($image,$namelength+19,4); 
   hextoint4($sampleshex,$samplesint);
   my $samplechannelshex = substr($image,$namelength+23,2); 
   hextoint2($samplechannelshex,$samplechannelsint);
   my $samplefreqhex = substr($image,$namelength+27,4); 
   hextoint4($samplefreqhex,$samplefreqint);
   my $sampleblockalignint = $samplechannelsint * 4; 
   inttohex2($sampleblockalignint,$sampleblockalignhex);
   my $samplelengthint = $samplesint * $sampleblockalignint; 
   inttohex4($samplelengthint,$samplelengthhex);
   my $chunksizeint = $samplelengthint + 40; 
   inttohex4($chunksizeint,$chunksizehex);
   my $samplebyterateint = $samplefreqint * $sampleblockalignint; 
   inttohex4($samplebyterateint,$samplebyteratehex);
   $image =~ m/$AUDIOHEADER(.*?)($AUDIOFOOTER)/s;
   $mappoffset = $mappoffset + length($AUDIOHEADER) + length($1) + length($AUDIOFOOTER);
   my $wavimage = $1;
   my $footer = $2; # Todo: extract additional information such as the base note 
   my $wavdata = "RIFF" . $chunksizehex . "WAVEfmt " . "\x12\x00\x00\x00\x03\x00" . $samplechannelshex . $samplefreqhex . $samplebyteratehex . $sampleblockalignhex . "\x20\x00\x00\x00" . "fact" . "\x04\x00\x00\x00" . $sampleshex . "data" . $samplelengthhex; 
   if ( $samplechannelsint == 2 ) { 
    my $sampleposition = 0; 
    my $midpoint = $samplelengthint/2; 
    while ( $sampleposition < $midpoint ) 
    {
     $wavdata = $wavdata . substr($wavimage,$sampleposition,4); 
     $wavdata = $wavdata . substr($wavimage,$midpoint+$sampleposition,4);
     $sampleposition=$sampleposition+4;
    }
   } else {	
    $wavdata = $wavdata . substr($wavimage,0,$samplelengthint);
   }
   my $filename = "$file.sounds/$wavname.wav";
   open my $fo, "> $filename" or warn "$filename: $!", next;
   print $fo $wavdata; 
   close $fo;
   print " ", $wavname, ".wav\n"; 
  }
  close $fh; 
 } else {
  print "Usage: $0 [Reaktor Mapp File]\n";
 }
}
