#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw();

my $proc = qx(uname -p);
my $arch = $proc =~ /86/ ? "x86_64" : "aarch64";

# By default capture both legacy firmware (alpine) and UFI (default) usage
@ARGV = qw(alpine default) unless @ARGV;

# This script creates a tarball containing lima and qemu, plus all their
# dependencies from /usr/local/** or /opt/homebrew/.
# Dependencies are discovered using fs_usage to analyze file access

my %deps;
my $install_dir = $arch eq "x86_64" ? "/usr/local" : "/opt/homebrew";

# Get the installed QEMU version
my $qemu_version = qx(brew list --versions qemu);
$qemu_version =~ s/qemu\s+//;
chomp($qemu_version);
if (!$qemu_version) {
    die "Failed to get QEMU version using 'brew list --versions qemu'";
}
print "Using QEMU version: $qemu_version\n";

record("$install_dir/bin/limactl");
record("$install_dir/bin/qemu-img");
record("$install_dir/bin/qemu-system-$arch");
record("$install_dir/Cellar/qemu/$qemu_version/bin");

# qemu 6.1.0 doesn't use the symlink to access data files anymore
# but we need to include it because we replace the symlinks in
# /usr/local/bin with the actual files, so data file references need
# to resolve relative to that location too.
my $name = "$install_dir/share/qemu";
# Don't call record($name) because we only want the link, not the whole target directory
$deps{$name} = "→ " . readlink($name);

# Use fs_usage to capture runtime file access patterns
print "Starting fs_usage monitoring for runtime file access...\n";
my $fs_usage_log = "/tmp/fs_usage.log";
print "sudo may prompt for password to run fs_usage\n";
END { system("sudo pkill fs_usage") }
system("sudo -b fs_usage -w -f pathname limactl qemu-img qemu-system-$arch > $fs_usage_log");
sleep(2);

# Run lima templates to capture runtime file access
my $repo_root = join('/', dirname($FindBin::Bin), 'src', 'lima');
my $templatedir = "$repo_root/templates";
if (qx"limactl --version" =~ m/^limactl version (\d+)\.(\d+)\.(\d+)(-.*)*$/) {
    # version 1.0.0-alpha.0 was the last one with the old directory structure
    if ($1 le 0 or ($1 eq 1 and $4 eq "-alpha.0")) {
        print "limactl version ($1.$2.$3$4), falling back to pre-1.0 templatedir\n";
        $templatedir = "$repo_root/examples";
    }
} else {
    print "unknown limactl version, falling back to pre-1.0 templatedir\n";
    $templatedir = "$repo_root/examples";
}

print "Running lima templates to capture runtime file access...\n";
for my $template (@ARGV) {
    my $config = "$templatedir/$template.yaml";
    die "Config $config not found" unless -f $config;
    system("limactl delete -f $template") if -d "$ENV{HOME}/.lima/$template";
    system("limactl start --tty=false --vm-type=qemu $config");
    system("limactl shell $template uname");
    system("limactl stop $template");
    system("limactl delete $template");
}

# Stop fs_usage
print "Stopping fs_usage and parsing results...\n";
system("sudo pkill fs_usage");
sleep(2);

# Parse fs_usage output and merge with existing dependencies
parse_fs_usage_log($fs_usage_log);

# Verify dependencies against verification files
verify_dependencies(\%deps, $arch);

my $dist = "lima-and-qemu";
system("rm -rf /tmp/$dist");

# Copy all files to /tmp tree and make all dylib references relative to the
# /usr/local/bin directory using @executable_path/..
my %resign;
for my $file (keys %deps) {
    my $copy = $file =~ s|^$install_dir|/tmp/$dist|r;
    system("mkdir -p " . dirname($copy));
    if ($file =~ m|^$install_dir/bin/|) {
        # symlinks in the bin directory are replaced by the target file because in
        # macOS Monterey @executable_path refers to the symlink target and not the
        # symlink location itself, breaking the dylib lookup.
        system("cp $file $copy");
    }
    else {
    system("cp -R $file $copy");
    next if -l $file;
    }
    next unless qx(file $copy) =~ /Mach-O/;

    open(my $fh, "otool -L $file |") or die "Failed to run 'otool -L $file': $!";
    while (<$fh>) {
        my($dylib) = m|$install_dir/(\S+)| or next;
        my $grep = "";
        if ($file =~ m|bin/qemu-system-$arch$|) {
            # qemu-system-* is already signed with an entitlement to use the hypervisor framework
            $grep = "| grep -v 'will invalidate the code signature'";
            $resign{$copy}++;
        }
        $resign{$copy}++ if $arch eq "aarch64";
        system "install_name_tool -change $install_dir/$dylib \@executable_path/../$dylib $copy 2>&1 $grep";
    }
    close($fh);
}
# Replace invalidated signatures
for my $file (keys %resign) {
    system("codesign --sign - --force --preserve-metadata=entitlements $file");
}

my $files = join(" ", map s|^$install_dir/||r, keys %deps);


# Package socket_vmnet
die if -e "/tmp/$dist/socket_vmnet";
if (-f "/opt/socket_vmnet/bin/socket_vmnet") {
    system("mkdir -p /tmp/$dist/socket_vmnet/bin");
    system("cp /opt/socket_vmnet/bin/socket_vmnet /tmp/$dist/socket_vmnet/bin/socket_vmnet");
    $files .= " socket_vmnet/bin/socket_vmnet";
}

# Ensure all files are writable by the owner; this is required for Squirrel.Mac
# to remove the quarantine xattr when applying updates.
system("chmod -R u+w /tmp/$dist");

my $repo_root = join('/', dirname($FindBin::Bin), 'src', 'lima');
unlink("$repo_root/$dist.tar.gz");
system("tar cvfz $repo_root/$dist.tar.gz -C /tmp/$dist $files");

# Extract package versions from Cellar and export to JSON
my %package_versions;
for my $file (keys %deps) {
    # Extract package info from Cellar path: /opt/homebrew/Cellar/package/version/...
    if ($file =~ m|/Cellar/([^/]+)/([^/]+)/|) {
        my ($package, $version) = ($1, $2);
        $package_versions{$package} = {
            "package" => $package,
            "version" => $version
        };
    }
    # Handle direct bin files (like limactl) that might not be in Cellar
    elsif ($file =~ m|^$install_dir/bin/([^/]+)$|) {
        my $binary_name = $1;
        # Try to get version from the binary itself
        my $version_output = qx($file --version 2>/dev/null | head -1);
        if ($version_output =~ /(\d+\.\d+\.\d+[^\s]*)/) {
            $package_versions{$binary_name} = {
                "package" => $binary_name,
                "version" => $1
            };
        }
    }
}

# Export to JSON
use JSON qw( encode_json );
my $json_file = "$repo_root/dep-version-mapping-$arch.json";
open(my $json_fh, ">", $json_file) or die "Can't write $json_file: $!";
print $json_fh encode_json(\%package_versions);
close($json_fh);
print "Generated dependency mapping: $json_file\n";

exit;

# File references may involve multiple symlinks that need to be recorded as well, e.g.
#
#   /usr/local/opt/libssh/lib/libssh.4.dylib
#
# turns into 2 symlinks and one file:
#
#   /usr/local/opt/libssh → ../Cellar/libssh/0.9.5_1
#   /usr/local/Cellar/libssh/0.9.5_1/lib/libssh.4.dylib → libssh.4.8.6.dylib
#   /usr/local/Cellar/libssh/0.9.5_1/lib/libssh.4.8.6.dylib [394K]
my %seen;
sub record {
    my $dep = shift;
    return if $seen{$dep}++;
    
    $dep =~ s|^/|| or die "$dep is not an absolute path";
    my $filename = "";
    my @segments = split '/', $dep;
    while (@segments) {
        my $segment = shift @segments;
        my $name = "$filename/$segment";
        my $link = readlink $name;
        # symlinks in the bin directory are replaced by the target, and the symlinks are not
        # recorded (see above). However, at least "share/qemu" needs to remain a symlink to
        # "../Cellar/qemu/6.0.0/share/qemu" so qemu will still find its data files. Therefore
        # symlinks are still recorded for all other files.
        if (defined $link && $name !~ m|^$install_dir/bin/|) {
            # Record the symlink itself with the link target as the comment
            $deps{$name} = "→ $link";
            if ($link =~ m|^/|) {
                # Can't support absolute links pointing outside /usr/local
                die "$name → $link" unless $link =~ m|^$install_dir/|;
                $link = join("/", $link, @segments);
            } else {
                $link = join("/", $filename, $link, @segments);
            }
            # Re-parse from the start because the link may contain ".." segments
            return record($link)
        }
        if ($segment eq "..") {
            $filename = dirname($filename);
        } else {
            $filename = $name;
        }
    }
    $deps{$filename} = sprintf "[%s]", (split / +/, qx(ls -lh $filename))[4];
}

sub dirname {
    shift =~ s|/[^/]+$||r;
}

sub verify_dependencies {
    my ($current_deps, $arch) = @_;
    
    print "=== Dependency Verification ===\n";
    
    # Determine verification file based on architecture
    my $verification_file = $arch eq "x86_64" ? "deps-verification-x86.txt" : "deps-verification-arm64.txt";
    my $verification_path = join('/', $FindBin::Bin, '..', $verification_file);
    
    unless (-f $verification_path) {
        print "WARNING: Verification file $verification_path not found. Skipping dependency verification.\n";
        return;
    }
    
    print "Verifying dependencies against $verification_file (ignoring version mismatches)...\n";
    
    # Load expected dependencies from verification file
    my %expected_deps;
    open(my $fh, '<', $verification_path) or die "Cannot open $verification_path: $!";
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*$/ || $line =~ /^#/; # Skip empty lines and comments
        
        # Parse line format: "/path/to/file [size]" or "/path/to/file → target"
        if ($line =~ /^(\S+)\s+(.+)$/) {
            my ($path, $info) = ($1, $2);
            $expected_deps{$path} = $info;
        } else {
            # Handle lines that are just paths without additional info
            $expected_deps{$line} = "";
        }
    }
    close($fh);
    
    print "Expected dependencies: " . scalar(keys %expected_deps) . "\n";
    print "Current dependencies: " . scalar(keys %$current_deps) . "\n";
    
    print "\n--- Expected Dependencies ---\n";
    for my $path (sort keys %expected_deps) {
        print "  $path $expected_deps{$path}\n";
    }
    
    print "\n--- Current Dependencies ---\n";
    for my $path (sort keys %$current_deps) {
        print "  $path $current_deps->{$path}\n";
    }
    print "\n";
    
    my @missing_deps;
    my @unexpected_deps;
    my @version_mismatches;
    
    # Create version-agnostic lookup for expected dependencies
    my %expected_deps_normalized;
    for my $expected_path (keys %expected_deps) {
        my $normalized_path = normalize_path_for_version_comparison($expected_path);
        push @{$expected_deps_normalized{$normalized_path}}, $expected_path;
    }
    
    # Create version-agnostic lookup for current dependencies
    my %current_deps_normalized;
    for my $current_path (keys %$current_deps) {
        my $normalized_path = normalize_path_for_version_comparison($current_path);
        push @{$current_deps_normalized{$normalized_path}}, $current_path;
}

    # Check for missing dependencies (ignoring versions)
    for my $normalized_expected (keys %expected_deps_normalized) {
        unless (exists $current_deps_normalized{$normalized_expected}) {
            # No matching dependency found at all
            push @missing_deps, @{$expected_deps_normalized{$normalized_expected}};
        } else {
            # Check for version mismatches
            my @expected_paths = @{$expected_deps_normalized{$normalized_expected}};
            my @current_paths = @{$current_deps_normalized{$normalized_expected}};
            
            # If paths don't match exactly, it's a version mismatch
            for my $expected_path (@expected_paths) {
                my $exact_match_found = 0;
                for my $current_path (@current_paths) {
                    if ($expected_path eq $current_path) {
                        $exact_match_found = 1;
                last;
            }
        }
                unless ($exact_match_found) {
                    push @version_mismatches, {
                        expected => $expected_path,
                        current => $current_paths[0] // "unknown"
            };
                }
            }
        }
    }
    
    # Check for unexpected dependencies (ignoring versions)
    for my $normalized_current (keys %current_deps_normalized) {
        unless (exists $expected_deps_normalized{$normalized_current}) {
            push @unexpected_deps, @{$current_deps_normalized{$normalized_current}};
        }
    }
    
    my $verification_failed = 0;
    
    if (@missing_deps) {
        print "ERROR: Missing expected dependencies:\n";
        for my $dep (@missing_deps) {
            print "  - $dep\n";
        }
        $verification_failed = 1;
    }
    
    if (@unexpected_deps) {
        print "ERROR: Unexpected dependencies found:\n";
        for my $dep (@unexpected_deps) {
            print "  + $dep $current_deps->{$dep}\n";
        }
        $verification_failed = 1;
    }
    
    if (@version_mismatches) {
        print "WARNING: Version mismatches detected (not failing verification):\n";
        for my $mismatch (@version_mismatches) {
            print "  ~ Expected: $mismatch->{expected}\n";
            print "    Current:  $mismatch->{current}\n";
        }
        print "Note: Version mismatches are warnings only and do not cause verification failure.\n";
    }
    
    if ($verification_failed) {
        print "\nDependency verification FAILED!\n";
        print "Please review the differences above and update the verification file if the changes are expected.\n";
        print "Verification file: $verification_path\n";
        exit 1;
    } else {
        print "Dependency verification PASSED!\n";
        if (@version_mismatches) {
            print "Note: There were version mismatches (see warnings above), but verification still passed.\n";
        }
    }
    
    print "=== End Dependency Verification ===\n\n";
}

# Normalize a path for version-agnostic comparison
sub normalize_path_for_version_comparison {
    my ($path) = @_;
    
    # Normalize versioned packages in opt directory
    # e.g., /opt/homebrew/opt/openssl@3.3 -> /opt/homebrew/opt/openssl@*
    # or /usr/local/opt/openssl@3.3 -> /usr/local/opt/openssl@*
    $path =~ s|($install_dir/opt/[^@]+@)\d+(\.\d+)*$|$1*|;
    
    # Remove version numbers from Cellar paths
    # e.g., /opt/homebrew/Cellar/openssl@3/3.5.2/lib -> /opt/homebrew/Cellar/openssl@3/*/lib
    $path =~ s|(/Cellar/[^/]+)/[^/]+(/.*)?$|$1/*$2|;
    
    # Remove version numbers from library filenames
    # e.g., libssl.3.dylib -> libssl.*.dylib
    $path =~ s|/lib([^/]+)\.(\d+(?:\.\d+)*)(\.dylib)$|/lib$1.*$3|;
    
    # Remove version numbers from versioned library files
    # e.g., libssl.3.0.15.dylib -> libssl.*.dylib
    $path =~ s|/lib([^/]+)\.(\d+(?:\.\d+)*(?:\.\d+)*)(\.dylib)$|/lib$1.*$3|;
    
    return $path;
}

# Parse fs_usage log and merge runtime file access with existing dependencies
sub parse_fs_usage_log {
    my ($log_file) = @_;
    
    print "Parsing fs_usage log: $log_file\n";
    
    unless (-f $log_file) {
        print "WARNING: fs_usage log file not found: $log_file\n";
        return;
    }
    
    my $fs_usage_deps_count = 0;
    my $new_deps_count = 0;
    
    open(my $fh, "<", $log_file) or do {
        print "WARNING: Cannot read fs_usage log: $!\n";
        return;
    };
    
    while (my $line = <$fh>) {
        chomp $line;
        # Parse fs_usage output format:
        if ($line =~ /\s+(open|read)\s+.*?\s+($install_dir\/\S+|\.\.\/.+?)(?:\s+\d+\.\d+\s+\S+)?$/) {
            my $file_path = $2;
            
            # Handle relative paths by removing "../" and prepending install_dir
            if ($file_path =~ m|^\.\.|) {
                $file_path =~ s|^\.\./||;
                $file_path = "$install_dir/$file_path";
            }

            # Skip directories starting with /opt/homebrew/Cellar/qemu unless -f
            next unless -f $file_path;
            
            # Count all fs_usage detected dependencies
            $fs_usage_deps_count++;
            
            # Skip if already recorded
            next if exists $deps{$file_path};
            
            # Record this new dependency
            record($file_path);
            $new_deps_count++;
            
            # Also find and record any symlinks pointing to this file
            my $links = qx(find -L $install_dir/opt -samefile $file_path 2>/dev/null);
            my @link_array = split('\n', $links);
            for my $link (@link_array) {
                chomp $link;
                next if $link eq $file_path;  # Skip the file itself
                next if exists $deps{$link};  # Skip if already recorded
                record($link);
                $new_deps_count++;
            }
        }
    }
    
    close($fh);
    unlink($log_file);
}
