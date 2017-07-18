#!/usr/bin/perl
#####!/nerc/packages/perl/bin/perl   needed for testing on linux etc
#####!/usr/bin/perl   needed for mercury
# Bruce Dupee 2nd Dec 2002
# Read station table to get parameters
# Then read table via parameter to see if the station is out of range
# email  message if required
# this program has not been used for a long time!!!!!

use DBI;
use Time::Local;

($sec,$min,$hour,$mday,$mon,$yyyy,$wday,$yday,$isdst)=gmtime();
$mon = $mon + 1;
#print("$sec,$min,$hour,$mday,$mon,$yyyy,$wday,$yday,$isdst\n");

$mailprog='/usr/lib/sendmail';
$from_address="irid_alert\@noc.soton.ac.uk";

$earth_radius=6371;
$pi=atan2(1,1) * 4;
$piover180=$pi/180;

print("IRID ALERT\n");
$data = <STDIN>;
print "DATA $data \n";
($irid_id,$jday,$lat,$lon,$rest0)=split /,/,$data,5;
$dbh = DBI->connect("DBI:mysql:realtime:mysql","rt_admin","rt_adm1n") || die "Can't open $database";


$sql="select * from station where ptt = '$irid_id'";
#print("$sql\n");
$sth=$dbh->prepare($sql);
$sth->execute();
@row = $sth->fetchrow_array;
($station_id,$program,$ptt,$station_name,$lat_ref,$lon_ref,$error_radius,$hours_silent,$alert_address,$alert_enabled,$add_tim) = @row;
#print("READ STATION $station_name\n");
if ($alert_enabled > 0) 
	{
	if (($lat < 1) & ( $lon < 1)) { exit; }
	if (($jday lt 10) & ($mn == 'Dec')) { $yyyy= $yyyy +1};
	if (($jday gt 350) and ($mn == 'Jan')) { $yyyy = $yyyy -1};
	$epoch = ($jday * 60 * 60 *24) + timegm(0,0,0,1,0,$yyyy,,,);
	($sec,$mins,$hours,$dom,$mon,$year,$wd,$yd,$isdst)=gmtime($epoch);
	$dat_tim=sprintf "%04d-%02d-%02d %02d:%02d:%02d", (1900+$yyyy),($mon+1),($dom-1),$hours,$mins,$sec;
	#print("dat_tim $dat_tim lat=$lat lon=$lon station_id=$station_id\n");
	#
	$lat_ref_rad=$lat_ref*$piover180;
	$lon_ref_rad=$lon_ref*$piover180;
	$one_deg=((2*$pi*$earth_radius)/360)*cos($lon_ref_rad);
	$lat_rad=$lat*$piover180;
	$lon_rad=$lon*$piover180;
	$bearing=atan2(($lat_rad-$lat_ref_rad),($lon_rad-$lon_ref_rad))*(180/$pi);
#	$radius=$one_deg*sqrt((($lat-$lat_ref)**2)+($lon-$lon_ref)**2) * 1.855 ;
	$radius=sqrt(((cos($lat_ref_rad)*($lat-$lat_ref))**2)+($lon-$lon_ref)**2) * 111 ;
	#printf("${station}_id = $station_id \n");
	#printf("Date:Time: $dat_tim \n");
	#printf("Lat=$lat Lon=$lon (Lat_ref=$lat_ref Lon_ref=$lon_ref)\n");
	#printf("Bearing: %6.3f \n",$bearing);
	#printf("Distance: %f \n",$radius);
	if ($radius > $error_radius) {
	    open( MAIL, "|$mailprog $alert_address" );
	    print MAIL "Reply-to: $alert_address\n";
	    print MAIL "From: $alert_address\n";
	    print MAIL "To: $alert_address\n";
	    print MAIL "Subject: ALERT : Iridium transmitter $irid_id\n\n";
	    printf(MAIL "Buoy off station by %6.1f km\n",$radius);
	    printf(MAIL "Position at $dat_tim\n");	   
	    printf(MAIL "Lat %6.3f Long %6.3f\n\n",$lat,$lon);
	    printf(MAIL "Reference position\n");
	    printf(MAIL "Lat %6.3f Long %6.3f\n\n",$lat_ref,$lon_ref);
	    print("Email sent for station $irid_id to $alert_address lat = $lat lon = $lon \n");
	    exit;
	  }
}
  print("No email sent  for station $irid_id to $alert_address lat = $lat lon = $lon \n");


