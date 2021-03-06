#/usr/local/bin/perl
# A beta windows version

sub inttohex4 {
 $_[1]=pack("H8",sprintf("%08X",$_[0]));
}

sub inttohex2 {
 $_[1]=pack("H4",sprintf("%04X",$_[0]));
}

sub hextoint {
 $_[1]=unpack("s",$_[0]); 
}

my $MAPPHEADER = "^.{8}\x4E\x49\x4D\x61";
my $MAPPFOOTERH = "\x6D\x61\x70\x70";
my $AUDIOHEADER = "\x00\x00\x00\x00\x20\x00\x00\x00\x01\x00\x00\x00";
my $AUDIOFOOTER = "\x65\x6E\x74\x72\x54.{87}";

foreach my $file ( @ARGV )
{
 if ( -e $file && not -d $file ) {
  print "Xploding Reaktor Mapp file $file...\n"; 
  if ( not -e "$file.sounds" ) { 
   mkdir "$file.sounds";
  }
  my $data = do { local $/; open my( $fh ), $file; <$fh> };
  $data =~ m/($MAPPHEADER.{8}.*?$MAPPFOOTERH)/s;    
  my $mappoffset = length($1); 	
  print "Header: ", $mappoffset, "\n";
  while( substr($data,$mappoffset) =~ m/(\w:\\\w.*?$AUDIOFOOTER)/sg )
  {
   my $image = $1;
   $image =~ m/^.*?\\(.*?)\x04\x00\x00\x00/s;
   my $namelength = length($1);
   $1 =~ m/.*\\(.*)/s;
   my $wavname = $1;
   $wavname =~ s/\W/_/g; 	
   $wavname =~ s/_...$//; 	
   my $sampleshex = substr($image,$namelength+11,4); 
   hextoint($sampleshex,$samplesint);
   my $samplechannelshex = substr($image,$namelength+15,2); 
   hextoint($samplechannelshex,$samplechannelsint);
   my $samplefreqhex = substr($image,$namelength+19,4); 
   hextoint($samplefreqhex,$samplefreqint);
   my $sampleblockalignint = $samplechannelsint * 4; 
   inttohex2($sampleblockalignint,$sampleblockalignhex);
   my $samplelengthint = $samplesint * $sampleblockalignint; 
   inttohex4($samplelengthint,$samplelengthhex);
   my $chunksizeint = $samplelengthint + 40; 
   inttohex4($chunksizeint,$chunksizehex);
   my $samplebyterateint = $samplefreqint * $sampleblockalignint; 
   inttohex4($samplebyterateint,$samplebyteratehex);
   $image =~ m/$AUDIOHEADER(.*?)$AUDIOFOOTER/s;
   $mappoffset = $mappoffset + length($AUDIOHEADER) + length($1) + length($AUDIOFOOTER);
   my $wavimage = $1;
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
   my $filename = "$file.sounds" . "\\" . "$wavname.wav";
   open my $fo, "> $filename" or warn "$filename: $!", next;
   binmode($fo);	
   print $fo $wavdata; 
   close $fo;
   print " ", $wavname, ".wav\n"; 
  }
  close $fh; 
 } else {
  print "Usage: $0 [Reaktor for Windows Mapp File]\n";
 }
}
