#!/usr/bin/perl
###!/nerc/packages/perl/bin/perl   # for testing MRP20160511 /usr/bin/perl now works on mercury and other servers e.g. tethys
###!/usr/bin/perl    # for mercury
# created from orby.pl - Bruce Dupee Oct 2002
# orby mail messages are routed to the old user ids perl scripts
# Messages are sent to iridburst@noc.soton.ac.uk
# There is the following line in iridburst's home directory .forward file:
# \iridburst, "| /noc/users/iridburst/exec/iridium.pl > /noc/users/iridburst/exec/iridium_run.log"
# alert_enabled 201 for alert for PAP as no ???_upd required mred 8-Jan-2012

# Set the perl libraries to use
use Time::Local;
use CGI;
use DBI;

# find date and time now
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
$mon = $mon + 1;

# Set up email notification specification
$mailprog='/usr/lib/sendmail';
$from_address="Iridium_System\@noc.soton.ac.uk";
$to_address="migcha\@noc.ac.uk,john.walk\@noc.ac.uk,joncamoceandata\@gmail.com,bodcnocs\@bodc.ac.uk";   # address that SBD message is sent to
local $/ = "";

# Split the header information from the email
$header = <STDIN>;
# Split header into header fields
@lines = split /\n(?!\s)/, $header;
foreach $line (@lines) {
  my ($label,$value) = split /:\s*/, $line, 2;
  $hash{$label} = $value;
}

# Station ID will be given in the "From" field
($station)= split /@/,$hash{'From'};
$stationl=lc($station); # Ensure always lower case for string matching
#$stationl=$station;
#$stationl=~ tr/A-Z/a-z/;
#
# Iridium ID in the "Subject" field
#($rest,$irid_id)= split /": "/,$hash{'Subject'},2;
$irid_id = substr($hash{'Subject'},-15);

print("STATION $stationl\n");

# For messages from iridburst - set the station to sbdservice
if (($stationl =~ m/bodcnocs/) || ($stationl =~ m/iridburst/)) {
  $stationl = 'sbdservice';
  print("STATION-modified to  $stationl\n");
}

#print "REST $rest\n";
print "IRID_ID $irid_id\n";

# Read in content - either from attachment or message body
if ($header =~ m/Content-Disposition: attachment/) {
  undef $/;
  $body = <STDIN>;
} else {
  $body="";
  while(<STDIN>) {$body .= $_;}
}

($x,$attFileName0)=split /filename="/,$body,2;
($attFileName,$x)=split /"/,$attFileName0,2;
print ("attachment filename: $attFileName\n");
print("BODY $body\n");

if ($stationl eq 'xxxx') {
  # If the station name is 'xxxx' use the xxxx_upd.pl script to process
  $handler="/noc/users/iridburst/exec/${stationl}_upd.pl";
  # If this is sbdservice, or iridburst, data
} else {
  if ( ($stationl eq 'sbdservice') or ($stationl eq 'iridburst')  ) {
    # decodes attachment input for $irid_id,$jday,$lat,$lon,$rest0
    #################
    # Find out from realtime database what the alert status is for this station
    $dbhrt = DBI->connect("DBI:mysql:realtime:mysql","rt_admin","rt_adm1n") || die "Can't open $database";
    $sth=$dbhrt->prepare("SELECT * from station WHERE program > 88000  and ptt = $irid_id");
    $sth->execute();
    @row = $sth->fetchrow_array;
    ($station_id,$station_program,$station_ptt,$station_name,$lat_ref,$lon_ref,$error_radius,$hours_silent,$alert_address,$alert_enabled,$add_tim) = @row;
    #printf("@row\n");
    print("STATION TABLE DATA $station_id,$station_program,$station_ptt,$station_name,$lat_ref,$lon_ref,$error_radius,$hours_silent,$alert_address,$alert_enabled \n");

    fbox1($stationl,$body,$mon,$alert_enabled);

    if ($alert_enabled == 0) {
      printf("No alert checking for $station, no further action\n");
      exit;
    }
    if ($alert_enabled == 101) {
      print("record for IRID stationl  $station send to ???_upd.pl \n");
      exit;
    }
    ####################
    if (($alert_enabled == 1) || ($alert_enabled == 201)) {
      $pass_out=$irid_id.",".$data;
      $alert_prog="/noc/users/iridburst/exec/irid_alert.pl > /noc/users/iridburst/exec/out.log";
      open(ALERT, "| $alert_prog") || die "can't open $logfile: $!\n";
      print(ALERT "$pass_out\n");
      close(ALERT);
      exit;
    }
  } else {
    $handler="/noc/users/iridburst/exec/${stationl}_upd.pl";
  }
}

$logfile='/noc/users/iridburst/iridium.log';
open(LOG, ">> $logfile") || die "can't open $logfile: $!\n";
$t=`date`;

# subroutines

sub fbox1 {
  $stationl=$_[0];
  $body=$_[1];
  $mon=$_[2];
  $alert_enabled=$_[3];
  #print("IN SUB $station $body \n");
  if ( ($stationl eq 'sbdservice') or ($stationl eq 'iridburst')  ) {
    $datatype="irid_".$irid_id;
#   $process="/noc/users/iridburst/exec/${stationl}_upd.pl";
    $process="/noc/users/iridburst/exec/${datatype}_upd.pl";
    if ($alert_enabled == 101) {
      print ("PROCESS $process\n");
      $to_address = $alert_address;
    }
    $rawdat="/noc/users/iridburst/$datatype"."/".$datatype."_raw_$mon.dat";
    $unhexdat="/noc/users/iridburst/$datatype/".$datatype."_unhexed_$mon.dat";
    $unbindat="/noc/users/iridburst/$datatype/".$datatype."_unbinary_$mon.dat";

    if (($body=~ m/SBM Message/)&&($body=~ m/Encoding: base64/ )) {
      ($body_clear,$body_hex0)= split /base64/,$body,2;
      ($body_hex1,$rest)=split /--SBD/,$body_hex0,2;
      if ($body_hex1 =~ m/SBMmessage.sbd"/) {
        ($rest,$body_hex)=split /SBMmessage.sbd"/,$body_hex1,2;
      } else {
        $body_hex=$body_hex1;
      }
      $data = old_decode_base64($body_hex);
    }

    if (($body=~ m/multipart message in MIME format/)&&($body=~ m/Encoding: base64/ )) {
      print ("ENTERING NEW CODE\n");
      ($body_clear,$body_hex0)= split /base64/,$body,2;
      print ("BODY_HEX0:$body_hex0\n");
      ($rest,$body_hex1)=split /.sbd"/,$body_hex0,2;
      print ("BODY_HEX1:$body_hex1\n");
      if ($body_hex1 =~ m/xxxx"/) {
        ($rest,$body_hex)=split /SBMmessage.sbd"/,$body_hex1,2;
      } else {
        $body_hex=$body_hex1;
      }
      print ("BODY_HEX:$body_hex\n");
      $data = old_decode_base64($body_hex);
    }
    # print(LOG "RAWDATname $rawdat\n");
    if ($irid_id == 300034012433270) {
      decode_nmf($datatype,$mon,$data);
    } else {
      open( MAIL, "|$mailprog $to_address") or die "Can't open sendmail \n";
      print MAIL <<"EOF";
Reply-to: $from_address
From: $from_address
To: $to_address
Subject: Iridium email ID=$irid_id

$data

EOF
      close(MAIL);
    }

  } else {
    if ($stationl eq 'xxx') {
      $datatype='xxxxxxx';
      $process="/noc/users/iridburst/exec/".$stationl."_upd.pl";
      # print ("PROCESS $process\n");
      $rawdat="/noc/users/iridburst/$datatype"."/".$datatype."_raw_$mon.dat";
      $unhexdat="/noc/users/iridburst/$datatype/".$datatype."_unhexed_$mon.dat";
      $unbindat="/noc/users/iridburst/$datatype/".$datatype."_unbinary_$mon.dat";
      $data = old_decode_base64($body);
    } else {
      print("Unreognized source $station\n");
      exit;
    }
  }

  open(RAW, ">> $rawdat") || die "can't open $rawdat: $!\n";
  print(RAW "$header\n"); #for testing
  print(RAW "$body");
  close(RAW);

  open(UNHEX, ">> $unhexdat") || die "can't open $unhexdat: $!\n";
  if ($station_program == 88888) {
    print "Myrtle1:$attFileName\n";
    print(UNHEX "$attFileName\n");
  }
  print(UNHEX "$data\n");
  close(UNHEX);
  print "end of fbox1 sub alert_enabled $alert_enabled \n";
  if ($alert_enabled != 201) {
    open(PROCESS, "| $process") || die "can't open $process: $!\n";
    print(PROCESS "$data\n");
    close(PROCESS);
    print "end of fbox1  alert_enabled $alert_enabled so ??_upd.pl processed\n";
  } else {
    print "end of fbox1  alert_enabled $alert_enabled so ??_upd.pl not processed\n";}
  }

# subroutines
sub old_decode_base64 ($) {
# Bruce's subroutine which decodes the orby attachemnt which is uuencoded
  local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]

  my $str = shift;
  my $res = "";

  $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
  if (length($str) % 4) {
    require Carp;
    Carp::carp("Length of base64 data not a multiple of 4")
  }
  $str =~ s/=+$//;                        # remove padding
  $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
  while ($str =~ /(.{1,60})/gs) {
    my $len = chr(32 + length($1)*3/4); # compute length byte
    $res .= unpack("u", $len . $1 );    # uudecode
  }
  $res;
}

sub decode_nmf {
  $datatype=$_[0];
  $mon=$_[1];
  $bytes=$_[2];
  # call decode_nmf($datatype,$mon,$data);
  $unbindat="/noc/users/iridburst/$datatype/".$datatype."_unbinary_$mon.dat";
  open (UNBIN, ">> $unbindat");

  $NSEW=ord(substr($bytes,0,1));
  $hr=ord(substr($bytes,1,1));
  $min=ord(substr($bytes,2,1));
  $sec=ord(substr($bytes,3,1));
  $jday_high=ord(substr($bytes,4,1));
  $jday_low=ord(substr($bytes,5,1));
  $lat_deg=ord(substr($bytes,6,1));
  $lat_min=ord(substr($bytes,7,1));
  $lat_min_dec_high=ord(substr($bytes,8,1));
  $lat_min_dec_low=ord(substr($bytes,9,1));
  $long_deg=ord(substr($bytes,10,1));
  $long_min=ord(substr($bytes,11,1));
  $long_min_dec_high=ord(substr($bytes,12,1));
  $long_min_dec_low=ord(substr($bytes,13,1));
  $speed_high=ord(substr($bytes,14,1));
  $speed_low=ord(substr($bytes,15,1));
  $course_high=ord(substr($bytes,16,1));
  $course_low=ord(substr($bytes,17,1));
  $batt_volt=ord(substr($bytes,18,1));
  $temperature=ord(substr($bytes,19,1));
  $alert=substr($bytes,20,1);
  if ($alert == 'A') {
    $altitude_high=ord(substr($bytes,21,1));
    $altitude_low=ord(substr($bytes,22,1));
    $movement=substr($bytes,23,1);
  } else {
    $alert=' ';
    $altitude_high=ord(substr($bytes,20,1));
    $altitude_low=ord(substr($bytes,21,1));
    $movement=substr($bytes,22,1);
  }

  print(UNBIN "$NSEW,$hr, $min, $sec, $jday_high, $jday_low, $lat_deg, $lat_min, $lat_min_dec_high, $lat_min_dec_low, $long_deg, $long_min, $long_min_dec_high, $long_min_dec_low, $speed_high, $speed_low, $course_high, $course_low, $batt_volt, $temperature, $alert, $altitude_high, $altitude_low, $movement\n");

  close(UNBIN);
}

# end of subroutines

