#!/usr/bin/perl   
#####!/nerc/packages/perl/bin/perl    for testing or cron job
#####!/usr/bin/perl                   for live running
# perl program to take input from Iridium attachment and update database
# Jul 2011 has relationship to PAP ideas




exit;



use DBI;
use CGI;
use File::stat;
use Time::Local;
use lib "/noc/users/animate/lib";
use quality_control_v3;

$dbh = DBI->connect("DBI:mysql:animate:mysql","animate_admin","an1mate9876") || die "Can't open $database";

#@Depths=('30','31');
#@sbe_depth{4460}=$Depths[0];
#@sbe_depth{9992}=$Depths[1];
#$nvar=2;
$nightly=1;   # attempting to run once a night to mop any missed data. but possibly nolonger required now running from concatenated files.


$gps_range=-1;
$gps_range_test=200;  # mred 21Jul2009
$mooring="CIS201108";   # mred May 2010
$mooring_lc=lc($mooring);
$last_access="last_access_".$mooring_lc.".dat";
#$transmitter="buoy8";   # mred May 2010
$in_t_std=3;
$in_c_std=3;
$data_type=99;


$sbe_qc_Date_Time = 0;

#$file_dir0="/noc/user/usl/REMOTETEL/ascdata/".$transmitter."/";
$mailprog='/usr/lib/sendmail';
$from_address="Iridium_System\@noc.soton.ac.uk";
$to_address="mred\@noc.soton.ac.uk";


open (DATE, "< /noc/users/iridburst/exec/$last_access"); #!!!!!!!!!!!!!!!!file name also used in write at end of run !!
$last_run=<DATE>;
$loop_time=$last_run;
$unix_last_run=$last_run;

$nvar=<DATE>;
chomp($nvar);
print("XXXX $nvar \n");
$j=0;
while($j<$nvar)
	{
	$in=<DATE>;
	chomp($in);
	$j1=$j+1;
	($n,$Depths[$j1],$sn[$j1],$start_sec[$j1],$pressure_ind[$j1])=split(/ /,$in);
	print("$n ::$j :: Serial no $sn[$n] Depth $Depths[$n] $pressure[$n] $start_sec[$n] $pressure_ind[$n]\n");
	$j++;
	}
#oxgen ID
$in=<DATE>;
chomp($in);
($bgc_type,$bgc_sn)= split(/ /,$in,2);
$bgc_id=$bgc_type.'_'.bgc_sn;
print("BGC IDENT $bgc_type : $bgc_sn ::: $bgc_id \n"); 



close(DATE);

@tm=gmtime($last_run);
print "Last Run $last_run ----";
printf("%04d-%02d-%02d %02d:%02d:%02d \n", @tm[5]+1900, @tm[4]+1, @tm[3], @tm[2], @tm[1], @tm[0] );
$ddd=sprintf("%03u",@tm[7]+1);
$yyyy=@tm[5]+1900;

@now=gmtime(time);
$nowmon = @now[4] + 1;
print "MONTH  $nowmon $now\n";



$nowunix = time();
@now = gmtime();
$nowdate=sprintf("%04d-%02d-%02d %02d:%02d:%02d", @now[5]+1900,@now[4]+1,@now[3],@now[2],@now[1],@now[0]);

$nowyyyy=@now[5]+1900;
$nowddd=sprintf("%03u",@now[7]+1);
$no_loops=int( ($nowunix-$last_run) / 86400);
# leave in useful to have 2 running modes
$nightly=0;
if ($nightly>0)  
	{$file_dir0.="concat/";
#	$loop_time=$loop_time-86400;  removed to stop double run when running from concat
	$no_loops=1;
	}
print("FILE_DIR0-1 $file_dir\n");

print("TIMES $yyyy:$ddd :: $nowyyyy:$nowddd :: \n");



while($data=<STDIN>)
{

print "DATA $data \n";   # passed in from email via iridium.pl

if ($data =~ m/Status/)
	{
	($rest,$status_data)=split(/:/,$data,2);
#	print "STATUS record $status_data \n";
	($volts,$lat0,$lon0,$x1,$x2,$x3,$x4,$date,$time0,$rest)=split(/\s/,$status_data,10);
	$volts=$volts/1000;
	($time,$rest)=split(/}/,$time0,2);  ###################
#	print("STATUS2 $volts:$lat0:$lon0:$date $time: \n");
#	($deg,$min,$sec,$x)=split(/\xB0\x27/,$lat0,4);
	$deg=substr($lat0,0,2);
	$min=substr($lat0,3,2);
	$sec0=substr($lat0,6);
	($sec,$x)=split(/"/,$sec0,4);
	$latitude=$deg+($min/60)+($sec/3600);
#	print("LAT ($deg,$min,$sec) $latitude\n");
	$deg=substr($lon0,0,2);
	$min=substr($lon0,3,2);
	$sec0=substr($lon0,6);
	($sec,$x)=split(/"/,$sec0,4);
	$longitude=$deg+($min/60)+($sec/3600);
#	print("LON ($deg,$min,$sec) $longitude\n");
	$rec_date_time=substr($date,4)." ".$time;
	
#	print "GPS2 $rec_date_time \n";
	
		$sqlsel="SELECT *  FROM ".$mooring."_gps WHERE Date_Time = '".$rec_date_time."'";
		print("$sqlsel\n");
		$sel = $dbh->prepare($sqlsel);    
		$sel->execute(); 
#		|| die "Update $sql failed";

		@rowh=$sel->fetchrow_array();

		unless (@rowh)
			{      
			$sql="INSERT INTO ".$mooring."_gps SET Date_Time='".$rec_date_time."'";
			$ins = $dbh->prepare($sql);    
			$ins->execute()  || die "insert $sql failed";
							}	
	                #  use e/w long indicator
	                $longitude = $longitude * -1;
		        
			$sqlupd="UPDATE ".$mooring."_gps SET  Latitude='".$latitude."', ";
			$sqlupd.="Longitude='".$longitude."',";						
			$sqlupd.="battery_v='".$volts."',";
			$sqlupd.=" add_dat='".$nowdate."' ";
			$sqlupd.=" where Date_Time = '".$rec_date_time."'";
		print ("GPS sql $sqlupd \n");
			$ins = $dbh->prepare($sqlupd);    
			$ins->execute()|| die "Update $sql failed";
			
	}   # end of dealing with status record
#################### ###############


    $data_start=substr($data,0,2);
    $data_type=substr($data,6,2);
    $data_date=substr($data,9,23);
  print("DATA  xxrecord $data_type      ::$data \n");
    if (($data_start eq "!{") and ($data_type eq "00"))
       {
       print("DATA_TYPE00: $data_type\n");
       #read until Sampledata or next 513 record
       $data=<STDIN>;
       unless (($data =~ m/Remo/ ) or ($data =~ m/SampleData/))
        {$data=<STDIN>;}
 #       print("DATA READ in 00:$data\n");
	 if ($data =~ m/SampleData/)
	 {
	    $tagblock="SampleData";
	    $bgcsample = &cutTagBlock($data,$tagblock);
#	    print "SAMPLEDATA $bgcsample \n";
#	    ($x,$id0)=split(/ID='0x/,$bgcsample,2);
#	    ($id,$x1)=split(/'/,$id0,2);
#	    print("ID $id0:::\n$id:::\n");
#	    if ($id==$bgc_sn)
#	     {
#	       print("SAMPLEDATA1 $bgc_type:$id:\n");
	       ($x,$oxygen,$o2_temp,$rest)=split(/;/,$bgcsample);
		
	       $rec_date_time=substr($data_date,0,13).":15:00";   # force to be quarter past
	
#	print "BGC2 $rec_date_time \n";
	
		$sqlsel="SELECT *  FROM ".$mooring."_data WHERE Date_Time = '".$rec_date_time."'";
		print("$sqlsel\n");
		$sel = $dbh->prepare($sqlsel);    
		$sel->execute(); 
#		|| die "Update $sql failed";

		@rowh=$sel->fetchrow_array();

		unless (@rowh)
			{      
			$sql="INSERT INTO ".$mooring."_data SET Date_Time='".$rec_date_time."'";
			$ins = $dbh->prepare($sql);    
			$ins->execute()  || die "insert $sql failed";
							}	
	
		        
			$sqlupd="UPDATE ".$mooring."_data SET  oxygen='".$oxygen."',";
			$sqlupd.="o2_temp='".$o2_temp."',";
			$sqlupd.=" add_dat='".$nowdate."' ";
			$sqlupd.=" where Date_Time = '".$rec_date_time."'";
#		print ("BGC sql $sqlupd \n");
			$ins = $dbh->prepare($sqlupd);    
			$ins->execute()|| die "Update $sql failed";
		
		$data_type=99;	
		#}  
		#else
		#{ # invalid sn  bgc type combination
		    print ("END of Oxygen invalid serial number $id \n");           
	        #} 
         } # end of writing an oxygen record
         } # end of datatype 0
  ########################################################       


	# potential microcat data
        if (($data_start eq "!{") and  ($data_type<99) )   
	{
	 print("DATA_TYPE $data_type\n");

	print "potential microcat record $data \n";
         $data=<STDIN>;
	($mc_sn,$mc_temp,$mc_cond,$mc_rest)=split(/,/,$data,4);
#	print("MICROCAT0 $data:$mc_sn:$data_type:$sn[$data_type]\n");
	if ($mc_sn==$sn[$data_type])
	   {
	   # write microcat data
#	   print "MICROCAT $data \n";
	      $nom_depth=$Depths[$data_type];
	      $rec_date_time=substr($data_date,0,13).":15:00";   # force to be quarter past !!!! may be problem for microcats so will need chacking

	   
			$sqlsel="SELECT *  FROM ".$mooring."_data WHERE ABS(TIMEDIFF(Date_Time,'".$rec_date_time."'))<5";
 
	#		print("$sqlsel\n");
			$sel = $dbh->prepare($sqlsel);    
			$sel->execute(); 
	#		|| die "Update $sql failed";
 
			@rowh=$sel->fetchrow_array();
			 unless (@rowh)
			 {      
  			  $sql="INSERT INTO ".$mooring."_data SET Date_Time='".$rec_date_time."'";
  			  $ins = $dbh->prepare($sql);    
  			  $ins->execute()  || die "insert $sql failed";
  			 }	
    	        	$mc_cond=$mc_cond*10;
  			$sqlupd="UPDATE ".$mooring."_data SET  temp".$nom_depth." = $mc_temp, ";
 			$sqlupd.="cond".$nom_depth." = $mc_cond, ";
	#		  print("MCREST $mc_rest:$data_type:$pressure_ind[$data_type]\n");
   			if ($pressure_ind[$data_type] eq 'P')
			  {
			  ($mc_press,$rest0)=split(/,/,$mc_rest,2);
			    $sqlupd.="press".$nom_depth." = $mc_press, ";
				      }
  			$sqlupd.="add_dat='".$nowdate."' ";
  			$sqlupd.=" where Date_Time = '".$rec_date_time."'";
  	#		$sqlupd.=" WHERE ABS(TIMEDIFF(Date_Time,'".$rec_date_time."'))<5";
  			#print ("SBE sql $sqlupd \n");
  			$ins = $dbh->prepare($sqlupd);    
  			$ins->execute()|| die "Update $sqlupd failed";
            } # end of microcat write	   
	  }

    
}  #end of biggest read loop	


exit;	
	
sub cutTagBlock
{
        $input=$_[0];
	$tagblock=$_[1];
	($start,$middle,$end)=split(?<[>\s]*\b$tagblock\b?,$input,3);
	($tagblockout,$xs)=split(?/$tagblock\s*>?,$middle,2);
#	<[>\s]*\bauthor\b[>]*>   example reg ex
#	print "X1 $start \n";
#	print "X2 $tagblockValue \n";
#	print "X3 $end \n";
	$return=$tagblockout;
}

	
