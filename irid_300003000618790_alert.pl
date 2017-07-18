#!/nerc/packages/perl/bin/perl
# Bruce Dupee 2nd Dec 2002
# Read station table to get parameters
# Then read table via parameter to see if the staion is out of range
# email  message if required
#
use DBI;
use Time::Local;

$mailprog='/usr/lib/sendmail';
$from_address="irid_alert\@noc.soton.ac.uk";
#$to_address="joc\@noc.soton.ac.uk";
#,jjmh\@noc.soton.ac.uk";
$to_address="mred\@noc.soton.ac.uk";

$earth_radius=6371;
$pi=atan2(1,1) * 4;
$piover180=$pi/180;

local $/ = "";
$header = <STDIN>;
@lines = split /\n(?!\s)/, $header;
foreach $line (@lines) {
my ($label,$value) = split /:\s*/, $line, 2;
$hash{$label} = $value;
}
$spl0=": ";
($subj_line,$irid_id)= split /$spl0/,$hash{'Subject'};
#print $irid_id;

($dy,$dn,$mn,$yyyy,$rest)= split /\s/,$hash{'Date'};
#print "MONTH $mn, YEAR $yyyy\n";

undef $/;
$data = <STDIN>;
print "DATA $data \n";

$dbh = DBI->connect("DBI:mysql:soc:mysql","guest","guest") || die "Can't open $d
atabase";
$sql="select * from station where station_name = 'IRID_$irid_id'";
$sth=$dbh->prepare($sql);
$sth->execute();
@row = $sth->fetchrow_array;
($station_id,$program,$ptt,$station_name,$lat_ref,$lon_ref,$error_radius,$hours_silent,$alert_address,$alert_enabled,$add_tim) = @row;
print("READ STATION\n");
($jday,$lat,$lon,$rest)=split /,/,$data,4;

if (($lat < 1) & ( $lon < 1)) { exit; }
print("EXIT1\n");
if (($jday lt 10) & ($mn == 'Dec')) { $yyyy= $yyyy +1};
if (($jday gt 350) and ($mn == 'Jan')) { $yyyy = $yyyy -1};
$epoch = ($jday * 60 * 60 *24) + timegm(0,0,0,1,0,($yyyy-1900));
($sec,$mins,$hours,$dom,$mon,$year,$wd,$yd,$isdst)=gmtime($epoch);
$dat_tim=sprintf "%04d-%02d-%02d %02d:%02d:%02d", (1900+$year),($mon+1),($dom-1),$hours,$mins,$sec;
print("dat_tim $dat_tim lat=$lat lon=$lon station_id=$station_id\n");
#
$lat_ref_rad=$lat_ref*$piover180;
$lon_ref_rad=$lon_ref*$piover180;
$one_deg=((2*$pi*$earth_radius)/360)*cos($lon_ref_rad);
$lat_rad=$lat*$piover180;
$lon_rad=$lon*$piover180;
$bearing=atan2(($lat_rad-$lat_ref_rad),($lon_rad-$lon_ref_rad))*(180/$pi);
$radius=$one_deg*sqrt((($lat-$lat_ref)**2)+($lon-$lon_ref)**2);
printf("${station}_id = $station_id \n");
printf("Date:Time: $dat_tim \n");
printf("Lat=$lat Lon=$lon (Lat_ref=$lat_ref Lon_ref=$lon_ref)\n");
printf("Bearing: %6.3f \n",$bearing);
printf("Distance: %f \n",$radius);
if ($radius > $error_radius) {
  if ($alert_enabled) {
    open( MAIL, "|$mailprog $alert_address" )
    #open( MAIL, "|$mailprog bwd" )
    #open( MAIL, "| cat" )
             || die "can't open sendmail \n";
    print MAIL "Reply-to: $alert_address\n";
    print MAIL "From: $alert_address\n";
    print MAIL "Subject: Iridium transmitter $irid_id\n\n";
    printf(MAIL "Buoy off station?\n");
    printf(MAIL "%6.3f\n",$lat);
    printf(MAIL "%6.3f\n",$lon);
    printf(MAIL "%s\n",$dat_tim);
    print("Email sent for station $station to $alert_address lat = $lat lon = $l
on \n");
  }
} else {
  print("No email sent  for station $station to $alert_address lat = $lat lon =
$lon \n");
}

