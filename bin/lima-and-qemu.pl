#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw();
use JSON qw( decode_json );

my $proc = qx(uname -p);
my $arch = $proc =~ /86/ ? "x86_64" : "aarch64";

# By default capture both legacy firmware (alpine) and UFI (default) usage
@ARGV = qw(alpine default) unless @ARGV;

# This script creates a tarball containing lima and qemu, plus all their
# dependencies from /usr/local/** or /opt/homebrew/.
# Files opened by limactl and qemu are captured using https://github.com/objective-see/FileMonitor
# `limactl start examples/alpine.yaml; limactl stop alpine; limactrl delete alpine`.

# {"event":"ES_EVENT_TYPE_NOTIFY_WRITE","timestamp":"2022-11-02 02:19:42 +0000","file":
# {"destination":"/Users/siravara/.lima/default/cidata.iso","
# process":{"pid":35515,"name":"limactl","path":"/opt/homebrew/bin/limactl",
# "uid":504,"architecture":"Apple Silicon","arguments":[],"ppid":35512,"rpid":812,"ancestors"
# :[812,1],"signing info (reported)":{"csFlags":570556419,"platformBinary":0,"signingID":"a.out","teamID":"",
# "cdHash":"37B6887F5188C68A1A072989289EAFDB8B68C75A"},"signing info (computed)":{"signatureStatus":0,"signatureSigner":
# "AdHoc","signatureID":"a.out"}}}}
#
# It shows the following binaries from /usr/local are called:

my %deps;
my $install_dir = $arch eq "x86_64" ? "/usr/local" : "/opt/homebrew";
record("$install_dir/bin/limactl");
record("$install_dir/bin/qemu-img");
record("$install_dir/bin/qemu-system-$arch");

# qemu 6.1.0 doesn't use the symlink to access data files anymore
# but we need to include it because we replace the symlinks in
# /usr/local/bin with the actual files, so data file references need
# to resolve relative to that location too.
my $name = "$install_dir/share/qemu";
# Don't call record($name) because we only want the link, not the whole target directory
$deps{$name} = "→ " . readlink($name);

# Capture any library and datafiles access with FileMonitor
my $filemonitor = "/tmp/filemonitor.log";
END { system("sudo pkill FileMonitor") }
print "sudo may prompt for password to run FileMonitor\n";
system("sudo cat $filemonitor");

#Change this FileMonitor path for local build to installed path
system("sudo -b /Applications/FileMonitor.app/Contents/MacOS/FileMonitor >$filemonitor 2>/dev/null");
system("sudo cat $filemonitor");
sleep(1) until -s $filemonitor;

my $repo_root = join('/', dirname($FindBin::Bin), 'src', 'lima');
for my $example (@ARGV) {
    my $config = "$repo_root/examples/$example.yaml", ;
    die "Config $config not found" unless -f $config;
    system("limactl delete -f $example") if -d "$ENV{HOME}/.lima/$example";
    system("limactl start --tty=false $config");
    system("limactl shell $example uname");
    system("limactl stop $example");
    system("limactl delete $example");
}
system("sudo pkill FileMonitor");
