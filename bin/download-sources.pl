#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw();
use JSON qw( decode_json );

my $repo_root = join('/', dirname($FindBin::Bin));
my $dist = "dependency-sources";

system("rm -rf /tmp/$dist");

# Stage files in /tmp/$dist.
system("mkdir -p /tmp/$dist");

system("mkdir -p $repo_root/downloads");
my $dependencies = `brew deps --full-name qemu`;
my @arr = split('\n', $dependencies);

# Add qemu itself. 
push(@arr, "qemu");
for my $dependency (@arr) {
    print "Downloading sources for: $dependency \n";
    # download source code
    download_deps($dependency);
}

sub download_deps {
    my $dep = shift;
    # parse download url from package
    my $dep_info = `brew info --json $dep`;
    my @decoded_dep_info = @{decode_json($dep_info)};
    my $source_url = $decoded_dep_info[0]->{'urls'}{'stable'}{'url'};
    print "Source url: $source_url\n";

    # -L flag to allow redirections
    system("cd /tmp/$dist && (curl -LO $source_url; cd -;)");
    system("tar czfv $repo_root/downloads/dependency-sources.tar.gz -C /tmp/dependency-sources/ .");
}

sub dirname {
    shift =~ s|/[^/]+$||r;
}
