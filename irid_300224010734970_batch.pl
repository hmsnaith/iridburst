#!/usr/bin/perl
#irid_300224010734970_batch.pl
#Run as cat <local data file> | perl irid_300224010734970_batch.pl
#Adds data from local data file to database
#####!/nerc/packages/perl/bin/perl    for testing or cron job
#####!/usr/bin/perl                   for live running
# perl program to take input from Iridium attachment and update database
# MET OFFICE DATA 24-apr-2013 (29-may-2012)
# MET OFFICE DATA April 2017 deployment

# Set the perl libraries to use
use DBI;
use CGI;
use File::stat;
use Time::Local;

print "Running irid_300224010734970_batch\n";

# Establish link to animate MySQL tables
$dbh = DBI->connect("DBI:mysql:animate:mysql","animate_admin","an1mate9876") || die "Can't open $database";
print "Opened database\n";

#$nightly=1;   # attempting to run once a night to mop any missed data. but possibly nolonger required now running from concatenated files.

#$gps_range=-1;
#$gps_range_test=200;  # mred 21Jul2009
$mooring="PAP201704";   # hms June 2017   changed for 2017
$mooring_lc=lc($mooring);

#$last_access="last_access_".$mooring_lc.".dat";
#$in_t_std=3;
#$in_c_std=3;
#$data_type=99;

#$sbe_qc_Date_Time = 0;

# Set up email notification specification
#$mailprog='/usr/lib/sendmail';
#$from_address="Iridium_System\@noc.soton.ac.uk";
#$to_address="bodcnocs\@bodc.ac.uk";

#open (DATE, "< /noc/users/iridburst/exec/$last_access"); #!!!!!!!!!!!!!!!!file name also used in write at end of run !!
#$last_run=<DATE>;
#$loop_time=$last_run;
#$unix_last_run=$last_run;

#$nvar=<DATE>;
#chomp($nvar);
#print("XXXX $nvar \n");
#close(DATE);

#@tm=gmtime($last_run);
#print "Last Run $last_run ----";
#printf("%04d-%02d-%02d %02d:%02d:%02d \n", @tm[5]+1900, @tm[4]+1, @tm[3], @tm[2], @tm[1], @tm[0] );
#$ddd=sprintf("%03u",@tm[7]+1);
#$yyyy=@tm[5]+1900;

# Find current date / month
#@now=gmtime(time);
#$nowmon = @now[4] + 1;
#print "MONTH $nowmon $now\n";

$nowunix = time();
@now = gmtime();
$nowdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d", @now[5]+1900,@now[4]+1,@now[3],@now[2],@now[1],@now[0]);

#$nowyyyy=@now[5]+1900;
#$nowddd=sprintf("%03u",@now[7]+1);
#$no_loops=int( ($nowunix-$last_run) / 86400);
# leave in useful to have 2 running modes
#$nightly=0;
#if ($nightly>0) {
#  $file_dir0.="concat/";
#  $loop_time=$loop_time-86400;  removed to stop double run when running from concat
#  $no_loops=1;
#}
#print("FILE_DIR0-1 $file_dir\n");

#print("TIMES $yyyy:$ddd :: $nowyyyy:$nowddd :: \n");

while($data=<STDIN>) { # read input from standard in
 
  print "DATA $data";   # passed in from saved file

  if ($data =~ m/5208001e4525c2ea,1,DAS1/) { # identifier for 2017 deployment
#   If we have a second sensor for air_temp, air_humidity and dew_temp
#   ($WMAN,$data_date, $data_time, $WMAN_sn, $mess_no, $sys_id, $lat0, $lon0,
#          $wind_speed, $wind_dir, $wind_gust, $sea_temp,
#          $air_temp, $humidity, $dew_temp, $air_temp_2, $humidity_2, $dew_temp_2, $air_press,
#          $Hsig, $Hmax, $wave_TP, $wave_dir, $last)=split(/,/,$data,24);
    ($WMAN,$data_date, $data_time, $WMAN_sn, $mess_no, $sys_id, $lat0, $lon0,
           $wind_speed, $wind_dir, $wind_gust, $sea_temp,
           $air_temp, $humidity, $dew_temp, $air_press,
           $Hsig, $Hmax, $wave_TP, $wave_dir, $last)=split(/,/,$data,24);
    ($wave_spread,$checksum)=split(/\*/,$last,2);
    $yy=2000+substr($data_date,0,2);
    $mon=substr($data_date,2,2);
    $day=substr($data_date,4,2);
    $hh=substr($data_time,0,2);
    $min=substr($data_time,2,2);
    $sec=substr($data_time,4,2);

    $lat1=substr($lat0,0,2) + (substr($lat0,2,7)/60);
    $lon1=(substr($lon0,0,2) + (substr($lon0,2,7)/60))*-1;

    $rec_date_time = $yy."-".$mon."-".$day." ".$hh.":".$min.":".$sec;
#   print("DATA  xxrecord $rec_date_time :: $data \n");

    $sqlsel="SELECT *  FROM ".$mooring."_met WHERE Date_Time = '".$rec_date_time."'";
#    print("$sqlsel\n");
    $sel = $dbh->prepare($sqlsel);
    $sel->execute();
#    || die "Update $sqlsel failed";

    @rowh=$sel->fetchrow_array();
    unless (@rowh) {
      $sql="INSERT INTO ".$mooring."_met SET Date_Time='".$rec_date_time."'";
      $ins = $dbh->prepare($sql);
      print ("INSERT\n");
      $ins->execute()  || die "insert $sql failed";
    }

    $sqlupd="UPDATE ".$mooring."_met SET  sea_temp='".$sea_temp."', ";
    if ($wind_dir ne '') { $sqlupd.="wind_dir='".$wind_dir."',"; }
    if ($wind_speed ne '') { $sqlupd.="wind_speed='".$wind_speed."',"; }
    if ($wind_gust ne '') { $sqlupd.="wind_gust='".$wind_gust."',"; }
    if ($wave_TP ne '') { $sqlupd.="wave_TP='".$wave_TP."',"; }
    if ($air_temp ne '') { $sqlupd.="air_temp='".$air_temp."',"; }
    if ($air_temp ne '') { $sqlupd.="dew_temp='".$dew_temp."',"; }
    if ($humidity ne '') { $sqlupd.="humidity='".$humidity."',"; }
#   if ($air_temp_2 ne '') { $sqlupd.="air_temp_2='".$air_temp_2."',"; }
#   if ($dew_temp_2 ne '') { $sqlupd.="dew_temp_2='".$dew_temp_2."',"; }
#   if ($humidity_2 ne '') { $sqlupd.="humidity_2='".$humidity_2."',"; }
    if ($air_press ne '') { $sqlupd.="air_press='".$air_press."',"; }
    if ($Hsig ne '') { $sqlupd.="Hsig='".$Hsig."',"; }
    if ($Hmax ne '') { $sqlupd.="Hmax='".$Hmax."',"; }
    if ($wave_dir ne '') { $sqlupd.="wave_dir='".$wave_dir."',"; }
    if ($wave_spread ne '') { $sqlupd.="wave_spread='".$wave_spread."',"; }
    $sqlupd.="Lat='".$lat1."',";
    $sqlupd.="Lon='".$lon1."',";
    $sqlupd.=" add_dat='".$nowdate."' ";
    $sqlupd.=" where Date_Time = '".$rec_date_time."'";
    print ("METsql $sqlupd \n");
    $ins = $dbh->prepare($sqlupd);
    $ins->execute()|| die "Update $sqlupd failed";
#   print "$WMAN,$data_date,$data_time,$WMAN_sn,$mess_no,$lat0,$lon0,$wind_speed,$wind_dir,$wind_gust,
#                 $sea_temp, $air_temp, $humidity, $dew_temp, $air_temp_2, $humidity_2, $dew_temp_2,
#                 $air_press, $Hsig, $Hmax, $wave_TP, $wave_dir, $last\n";
#    print "$WMAN,$data_date,$data_time,$WMAN_sn,$mess_no,$lat0,$lon0,$wind_speed,$wind_dir,$wind_gust,".
#                 "$sea_temp, $air_temp, $humidity, $dew_temp,". 
#                 "$air_press, $Hsig, $Hmax, $wave_TP, $wave_dir, $last\n";

  } else { # If this isn't for current identifier
    print "Not entered into database\n";
  }
 
print "\n";
}  #end of biggest read loop

exit;
