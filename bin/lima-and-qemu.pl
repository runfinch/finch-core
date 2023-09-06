#!/usr/bin/env perl
use strict;
use warnings;

# Capture any library and datafiles access with FileMonitor
my $filemonitor = "/tmp/filemonitor.log";
END { system("sudo pkill FileMonitor") }
print "sudo may prompt for password to run FileMonitor\n";

#Change this FileMonitor path for local build to installed path
system("sudo -b /Applications/FileMonitor.app/Contents/MacOS/FileMonitor >$filemonitor 2>/dev/null");
system("echo hi");
sleep(1) until -s $filemonitor;

system("sudo pkill FileMonitor");