#!/usr/bin/perl

use File::Path;
#$t1="a1234";
#if (substr($t1,0,1) ne " ")
# {substr($t1,0,1)=" ";
#  print "T1 $t1 \n";}
#else
# {print "in else clase\n";}

$rootd = "/noc/users/iridburst";
$datatype = "NOCS-766518";
$mon = 7;
$rawdat="$rootd/$datatype/$datatype"."_raw_$mon.dat";

create_data();
print $data."\n";

sub create_data {
  $data = "good_stuff";
}
