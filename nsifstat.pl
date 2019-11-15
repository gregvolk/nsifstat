#!/usr/bin/perl -w
#
#
# nsifstat.pl - a telegraf exec script to collect detailed interface statistics
#               on a NetScout probe and feed the data to telegraf for export to
#               a TSDB
#
#
# This program executes "/opt/NetScout/rtm/tools/printstats -h" and parses
# the output. The following text is an example of printstats -h output:
#
#---------------------------- Interface 3 ----------------------------
#First packet time: 1507661100:0
#Last packet time: 1508068066:835502020
#Capture start sec: 0
#Packet count: 433596980436
#Bytes cnt: 262440163742084
#Packet drop count: 0
#Byte drop count: 0
#Packet reject count: 0
#Zero frame count: 0
#Flush fail count: 0
#---------------------------- Interface 4 ----------------------------
#First packet time: 1507661100:0
#Last packet time: 1508068063:488463430
#Capture start sec: 0
#
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

my $PRINTSTATS="/opt/NetScout/rtm/tools/printstats -h";
my $HN = `/bin/hostname`;
chomp $HN;

my (%ifname,%pkts,%bytes,%pktdrop,%bytedrop,%pktreject,%zeroframe,%flushfail,
    %firstpkt,%lastpkt);
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
    $ifnum = $a[2];
    $ifname{$ifnum} = $ifnum;
    if($debug) { print STDERR localtime().": interface $ifname{$ifnum} -> $ifnum\n"; }
  }

  if($line =~ /First packet time/) {
    @a = split /:/,$line;
    $firstpkt{$ifnum} = $a[1];
    if($debug) { print STDERR localtime().": firstpkt for $ifnum -> $firstpkt{$ifnum}\n"; }
  }
  if($line =~ /Last packet time/) {
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

$time = time();

if($debug) { print STDERR localtime().": using timestamp = $time\n"; }
if($debug){
  print STDERR localtime().": #ifnum,pkts,bytes,pktdrop,bytedrop,pktreject,zeroframe,flushfail,retention\n";
}


foreach $ifnum (sort keys %ifname) {
  $retention = $lastpkt{$ifnum} - $firstpkt{$ifnum};
  if($retention < 0) { $retention = 0; }
  if($debug) { print STDERR localtime().": calculated retention = $retention\n"; }

  if($debug) {
    print STDERR localtime().": $ifnum,$pkts{$ifnum},$bytes{$ifnum},$pktdrop{$ifnum},$bytedrop{$ifnum},$pktreject{$ifnum},$zeroframe{$ifnum},$flushfail{$ifnum},$retention\n";
  }
  print "nsprobe.if$ifnum\_pkts $pkts{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_bytes $bytes{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_pktdrop_err $pktdrop{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_bytedrop_err $bytedrop{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_pktreject_err $pktreject{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_zeroframe_err $zeroframe{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_flushfail_err $flushfail{$ifnum} $time\n";
  print "nsprobe.if$ifnum\_retention $retention $time\n";

}

