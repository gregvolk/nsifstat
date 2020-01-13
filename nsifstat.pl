#!/usr/bin/perl -w
#
#
# nsifstat.pl - a telegraf exec script to collect detailed interface statistics 
#		on a NetScout probe and feed the data to telegraf for export to 
#		a TSDB
#
#
# This program executes "/opt/NetScout/rtm/tools/printstats" and parses 
# the output. The following text is an example of printstats output:
#
#-------------Interface 3 ---------------
#StartTime:  1578331500
#EndTime:    1578583740.0
#LastBlock:  2640616
#-------------Interface 4 ---------------
#StartTime:  1578331500
#EndTime:    1578583740.0
#LastBlock:  2640608#
#
#
# When you execute nsifstat.pl the output should look something like this:
#nsprobe.if3_pkts 497172896685 1573849075
#nsprobe.if3_bytes 331037765942706 1573849075
#nsprobe.if3_pktdrop_err 0 1573849075
#nsprobe.if3_bytedrop_err 0 1573849075
#nsprobe.if3_pktreject_err 0 1573849075
#nsprobe.if3_zeroframe_err 0 1573849075
#nsprobe.if3_flushfail_err 0 1573849075
#nsprobe.if3_retention 181675 1573849075
#nsprobe.if4_pkts 63190639147 1573849075
#nsprobe.if4_bytes 39605644618118 1573849075
#
#
# Use the following telegraf.conf input config to instruct telegraf
# to call nsifstat.pl.
#
#[[inputs.exec]]
#  commands = ["/opt/telegraf/bin/scripts/nsifstat.pl"]
#  timeout = "5s"
#  data_format = "graphite"
#
#


use strict;

# debug output?
my $debug = 0;

my $PRINTSTATS="/opt/NetScout/rtm/tools/printstats";
my $XDRSIZESTATS="/usr/bin/du -s /xdr/*";



my $HN = `/bin/hostname`;
chomp $HN;

my (%ifname,%pkts,%bytes,%pktdrop,%bytedrop,%pktreject,%zeroframe,%flushfail,
    %firstpkt,%lastpkt,%xdrsize);
my ($line,$ifnum,@a,$time,$retention);

if($debug) { print STDERR localtime().": executing $PRINTSTATS on $HN\n"; }
my @input = `$PRINTSTATS`;

if($debug) { print STDERR localtime().": back from PRINTSTATS call with $#input lines\n"; }


if($debug) { print STDERR localtime().": parsing data\n"; }
foreach $line (@input) {
  chomp $line;
  if($debug) { print STDERR localtime().": working on $line\n"; }
  if($line =~ /-------/) {
    @a = split /\s+/,$line;
    $ifnum = $a[1];
    $ifname{$ifnum} = $ifnum;
    if($debug) { print STDERR localtime().": interface $ifname{$ifnum} -> $ifnum\n"; }
  }

  if($line =~ /StartTime/) {
    @a = split /:/,$line;
    $firstpkt{$ifnum} = $a[1];
    if($debug) { print STDERR localtime().": firstpkt for $ifnum -> $firstpkt{$ifnum}\n"; }
  }
  if($line =~ /EndTime/) {
    @a = split /:/,$line;
    $lastpkt{$ifnum} = $a[1];
    if($debug) { print STDERR localtime().": lastpkt for $ifnum -> $lastpkt{$ifnum}\n"; }
  }
  if($line =~ /Packet count/){
    @a = split /\s+/,$line;
    $pkts{$ifnum} = $a[2];
    if($debug) { print STDERR localtime().": packet count for $ifnum -> $pkts{$ifnum}\n"; }
  }
  if($line =~ /Bytes cnt/){
    @a = split /\s+/,$line;
    $bytes{$ifnum} = $a[2];
    if($debug) { print STDERR localtime().": byte count for $ifnum -> $bytes{$ifnum}\n"; }
  }
  if($line =~ /Packet drop/){
    @a = split /\s+/,$line;
    $pktdrop{$ifnum} = $a[3];
    if($debug) { print STDERR localtime().": pkt drop count for $ifnum -> $pktdrop{$ifnum}\n"; }
  }
  if($line =~ /Byte drop/){
    @a = split /\s+/,$line;
    $bytedrop{$ifnum} = $a[3];
    if($debug) { print STDERR localtime().": byte drop count for $ifnum -> $bytedrop{$ifnum}\n"; }
  }
  if($line =~ /Packet reject/){
    @a = split /\s+/,$line;
    $pktreject{$ifnum} = $a[3];
    if($debug) { print STDERR localtime().": reject count for $ifnum -> $pktreject{$ifnum}\n"; }
  }
  if($line =~ /Zero frame/){
    @a = split /\s+/,$line;
    $zeroframe{$ifnum} = $a[3];
    if($debug) { print STDERR localtime().": zero frame count for $ifnum -> $zeroframe{$ifnum}\n"; }
  }
  if($line =~ /Flush fail/){
    @a = split /\s+/,$line;
    $flushfail{$ifnum} = $a[3];
    if($debug) { print STDERR localtime().": flush fail count for $ifnum -> $flushfail{$ifnum}\n"; }
  }
}

if($debug) { print STDERR localtime().": executing $XDRSIZESTATS on $HN\n"; }
@input = `$XDRSIZESTATS`;

if($debug) { print STDERR localtime().": back from XDRSIZESTATS call with $#input lines\n"; }

foreach $line (@input) {
  chomp $line;
  if($debug) { print STDERR localtime().": working on $line\n"; }
  @a = split /_if/,$line;
  $ifnum = $a[1];
  if($debug) { print STDERR localtime().": XDR stat interface = $ifnum\n"; }
  @a = split /\s+/,$line;
  $xdrsize{$ifnum} = $a[0];
  if($debug) { print STDERR localtime().": storing xdrsize{$ifnum} -> $a[0]\n"; }
}


$time = time();

if($debug) { print STDERR localtime().": using timestamp = $time\n"; }
#if($debug){
#  print STDERR localtime().": #ifnum,pkts,bytes,pktdrop,bytedrop,pktreject,zeroframe,flushfail,retention\n";
#}


foreach $ifnum (sort keys %ifname) {
  $retention = $lastpkt{$ifnum} - $firstpkt{$ifnum};
  if($retention < 0) { $retention = 0; }
  if($debug) { print STDERR localtime().": calculated retention = $retention\n"; }

#  if($debug) {
#    print STDERR localtime().": $ifnum,$pkts{$ifnum},$bytes{$ifnum},$pktdrop{$ifnum},$bytedrop{$ifnum},$pktreject{$ifnum},$zeroframe{$ifnum},$flushfail{$ifnum},$retention\n";
#  }
  #print "nsprobe.if$ifnum\_pkts $pkts{$ifnum} $time\n";
  #print "nsprobe.if$ifnum\_bytes $bytes{$ifnum} $time\n";
  #print "nsprobe.if$ifnum\_pktdrop_err $pktdrop{$ifnum} $time\n";
  #print "nsprobe.if$ifnum\_bytedrop_err $bytedrop{$ifnum} $time\n";
  #print "nsprobe.if$ifnum\_pktreject_err $pktreject{$ifnum} $time\n";
  #print "nsprobe.if$ifnum\_zeroframe_err $zeroframe{$ifnum} $time\n";
  #print "nsprobe.if$ifnum\_flushfail_err $flushfail{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_retention $retention $time\n";
  print "nsprobe.if$ifnum\_xdrsize $xdrsize{$ifnum} $time\n";
}


