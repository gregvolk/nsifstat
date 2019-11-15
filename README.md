#nsifstat.pl
A telegraf exec script to collect detailed interface statistics
on a NetScout probe and feed the data to telegraf for export to
a TSDB.
<br>
Updates at https://github.com/gregvolk/nsifstat
This program is meant to be exexcuted on a NetScout probe. 
It requires access to "/opt/NetScout/rtm/tools/printstats -h" 
and parses the output from that program. The following text is 
an example of printstats -h output:
<br>
```
---------------------------- Interface 3 ----------------------------
First packet time: 1507661100:0
Last packet time: 1508068066:835502020
Capture start sec: 0
Packet count: 433596980436
Bytes cnt: 262440163742084
Packet drop count: 0
Byte drop count: 0
Packet reject count: 0
Zero frame count: 0
Flush fail count: 0
---------------------------- Interface 4 ----------------------------
First packet time: 1507661100:0
Last packet time: 1508068063:488463430
Capture start sec: 0
.
.
.
```

When you execute nsifstat.pl the output should look something like this:
```
`./nsifstat.pl 
nsprobe.if3_pkts 497172896685 1573849075
nsprobe.if3_bytes 331037765942706 1573849075
nsprobe.if3_pktdrop_err 0 1573849075
nsprobe.if3_bytedrop_err 0 1573849075
nsprobe.if3_pktreject_err 0 1573849075
nsprobe.if3_zeroframe_err 0 1573849075
nsprobe.if3_flushfail_err 0 1573849075
nsprobe.if3_retention 181675 1573849075
nsprobe.if4_pkts 63190639147 1573849075
nsprobe.if4_bytes 39605644618118 1573849075
.
.
.
```

Use the following telegraf.conf input config to instruct telegraf
to call nsifstat.pl.

```
[[inputs.exec]]
  commands = ["/opt/telegraf/bin/scripts/nsifstat.pl"]
  timeout = "5s"
  data_format = "graphite"
```



###debug output:
If you are having trouble making this work, try setting ```$debug = 1;``` in
the script to see where things are failing.
