import platform
import sys
import subprocess
import os
import time
import shutil
import re
import tarfile
from enum import Enum
from collections import defaultdict
from typing import List, Dict, Set, Literal

# global set used in record_dep function calls
# to check if we have already recorded a dep or not
global_seen = set()

# arch enum
class Arch(str, Enum):
    X86_64 = "x86_64"
    AARCH64 = "aarch64"

    def __str__(self) -> str:
        return self.value

def main():
    templates = get_templates_from_args()
    print("using templates: ", templates)
    
    arch = get_system_arch()
    install_dir = get_installation_dir(arch)
    print("using arch: ", arch)
    
    qemu_version = get_installed_qemu_version()
    print("using qemu version: ", qemu_version)
    
    print("recording initial deps...")
    deps = record_initial_deps(arch, install_dir, qemu_version)
    
    print("Starting fs_usage monitoring for runtime file access...")
    fs_usage_log = start_fs_usage(arch)
    time.sleep(2)

    print("Running lima templates to capture runtime file access...")
    run_lima_templates(templates)

    print("Stopping fs_usage and parsing results...")
    stop_fs_usage()
    time.sleep(2)

    print("Parsing fs_usage log...")
    parse_fs_usage_log(fs_usage_log, deps, install_dir)

    print("Verifying dependencies using verification file...")
    verify_dependencies(deps, arch, install_dir)

    print("Copying dependencies...")
    dist_path, resign_files = copy_deps(deps, arch, install_dir)

    print("Resigning files...")
    resign(resign_files)

    print("Packaging files and socket_vmnet...")
    package_files_and_socket_vmnet(deps, install_dir, dist_path)

    print("Cleaning up...")
    cleanup()

    print("Done")

def get_templates_from_args():
    default_templates = ["alpine", "default"]
    return sys.argv[1:] if len(sys.argv) > 1 else default_templates

def get_system_arch():
    machine = platform.machine()
    if not machine:
        raise RuntimeError("failed to get system arch")
    return Arch.X86_64 if "86" in machine else Arch.AARCH64

def get_installation_dir(arch: Literal[Arch.X86_64, Arch.AARCH64]):
    return "/usr/local" if arch == Arch.X86_64 else "/opt/homebrew"

def get_installed_qemu_version():
    try:
        res = subprocess.check_output("brew list --versions qemu", shell=True, text=True)
        qemu_version = res.replace("qemu", "").strip()
        if not qemu_version:
            raise RuntimeError("failed to get installed qemu version")
        return qemu_version
    except Exception as ex:
        raise RuntimeError("failed to get installed qemu version") from ex

def record_initial_deps(arch: Literal[Arch.X86_64, Arch.AARCH64], install_dir: str, qemu_version: str):
    try:
        deps: Dict[str, str] = {}
        record_dep(f"{install_dir}/bin/limactl", deps, install_dir)
        record_dep(f"{install_dir}/bin/qemu-img", deps, install_dir)
        record_dep(f"{install_dir}/bin/qemu-system-{arch}", deps, install_dir)
        record_dep(f"{install_dir}/Cellar/qemu/{qemu_version}/bin", deps, install_dir)
        deps[f"{install_dir}/share/qemu"] = f"→ {os.readlink(f'{install_dir}/share/qemu')}"
        return deps
    except Exception as ex:
        raise RuntimeError("failed to get deps") from ex

def start_fs_usage(arch: Literal[Arch.X86_64, Arch.AARCH64]):
    fs_usage_log = "/tmp/fs_usage.log"
    try:
        print("running fs_usage with sudo may prompt for password")
        subprocess.run(
            f"sudo -b fs_usage -w -f pathname limactl qemu-img qemu-system-{arch} > {fs_usage_log}",
            shell=True,
            check=True,
        )
        return fs_usage_log
    except Exception as ex:
        raise RuntimeError("failed to start fs_usage") from ex

def stop_fs_usage():
    try:
        subprocess.run("sudo pkill fs_usage", shell=True, check=True)
    except Exception as ex:
        raise RuntimeError("failed to stop fs_usage") from ex

# we used to perform a check for limactl version <= 1.0.0-alpha.0
# we no longer need to do that
def run_lima_templates(templates: List[str]):
    lima_repo_root = os.path.join(os.getcwd(), 'src', 'lima')
    lima_template_dir = os.path.join(lima_repo_root, 'templates')
    for template in templates:
        template_yaml = os.path.join(lima_template_dir, f"{template}.yaml")
        if not os.path.exists(template_yaml):
            raise RuntimeError(f"{template_yaml} does not exist in {lima_template_dir}")
        run_lima_template(template, template_yaml)

def run_lima_template(template_name: str, template_yaml: str):
    try:
        home_dir = os.getenv("HOME")
        if not home_dir:
            raise RuntimeError("failed to get home dir")
        if os.path.exists(os.path.join(home_dir, ".lima", template_name)):
            subprocess.run(f"limactl delete -f {template_name}", shell=True, check=True)
        
        subprocess.run(f"limactl start --tty=false --vm-type=qemu {template_yaml}", shell=True, check=True)
        subprocess.run(f"limactl shell {template_name} uname", shell=True, check=True)
        subprocess.run(f"limactl stop {template_name}", shell=True, check=True)
        subprocess.run(f"limactl delete {template_name}", shell=True, check=True)
    except Exception as ex:
        raise RuntimeError(f"failed to run lima template '{template_name}'") from ex

def copy_deps(deps: Dict[str, str], arch: Literal[Arch.X86_64, Arch.AARCH64], install_dir: str):
    resign_files: Set[str] = set()
    dist_path = "/tmp/lima-and-qemu"
    shutil.rmtree(dist_path, ignore_errors=True)
    
    for file_path in deps.keys():
        copy_path = file_path.replace(install_dir, dist_path)   
        os.makedirs(os.path.dirname(copy_path), exist_ok=True)
        
        if file_path.startswith(f"{install_dir}/bin/"):
            # symlinks in the bin directory are replaced by the target file because in
            # macOS Monterey @executable_path refers to the symlink target and not the
            # symlink location itself, breaking the dylib lookup.
            subprocess.run(f"cp {file_path} {copy_path}", shell=True)
        else:
            # do not set check=True here because "cp -R" ignores errors
            subprocess.run(f"cp -R {file_path} {copy_path}", shell=True)
            if os.path.islink(file_path): continue
        
        # if the file is not a mac os executable, skip the otool run for the file
        try:
            if 'Mach-O' not in subprocess.check_output(f"file {copy_path}", shell=True, text=True): continue
        except Exception as ex:
            print(f"WARNING: failed to run file command on {copy_path}: ", ex)
            continue
        
        try:
            print("using otool to find all dylib references")
            res = subprocess.check_output(f"otool -L {file_path}", shell=True, text=True)
            print(f"otool output: {res}")
        except Exception as ex:
            raise RuntimeError(f"failed to run otool command on {file_path}") from ex
        
        # skip the first line as it lists the binary iteself
        # this is not done in the perl script and yet it somehow works
        for line in res.splitlines()[1:]:
            line = line.strip()
            match = re.search(rf'{install_dir}/(\S+)', line)
            if not match: continue
            dylib = match.group(1)
            print(f"otool found dylib -> {dylib}")
            
            grep_filter = ""
            if file_path.endswith(f'bin/qemu-system-{arch}'):
                # qemu-system-* is already signed with an entitlement to use the hypervisor framework
                grep_filter = "| grep -v 'will invalidate the code signature'"
                resign_files.add(copy_path)
            if arch == Arch.AARCH64:
                resign_files.add(copy_path)
            
            try:
                install_name_tool_cmd = f"install_name_tool -change {install_dir}/{dylib} @executable_path/../{dylib} {copy_path} 2>&1 {grep_filter}"
                res = subprocess.check_output(install_name_tool_cmd, text=True, shell=True)
                print("install_name_tool output: ", res)
            except Exception as ex:
                print("WARNING: failed to run install_name_tool: ", ex)

    # Replace invalidated signatures
    return dist_path, resign_files

def resign(resign_files: Set[str]):
    for file_path in resign_files:
        try:
            res = subprocess.check_output(
                f"codesign --sign - --force --preserve-metadata=entitlements {file_path}",
                shell=True,
                text=True
            )
            print(f"codesign output: {res}")
        except Exception as ex:
            raise RuntimeError(f"failed to resign {file_path}") from ex

def package_files_and_socket_vmnet(deps: Dict[str, str], install_dir: str, dist_path: str):
    tar_files = [path.removeprefix(f"{install_dir}/") for path in deps.keys()]
    
    # Package socket_vmnet
    socket_vmnet_dest = f"{dist_path}/socket_vmnet"
    if os.path.exists(socket_vmnet_dest):
        raise RuntimeError(f"{socket_vmnet_dest} already exists")
    
    try:
        socket_vmnet_src = "/opt/socket_vmnet/bin/socket_vmnet"
        if os.path.isfile(socket_vmnet_src):
            os.makedirs(f"{socket_vmnet_dest}/bin", exist_ok=True)
            shutil.copy(socket_vmnet_src, f"{socket_vmnet_dest}/bin/socket_vmnet")
            tar_files.append("socket_vmnet/bin/socket_vmnet")
    except Exception as ex:
        raise RuntimeError("failed to package socket_vmnet") from ex

    # Ensure all files are writable by the owner; this is required for Squirrel.Mac
    # to remove the quarantine xattr when applying updates.
    try:
        subprocess.run(f"chmod -R u+w {dist_path}", shell=True, check=True)
    except Exception as ex:
        raise RuntimeError("failed to chmod files before packaging") from ex

    try:
        lima_repo_root = os.path.join(os.getcwd(), 'src', 'lima')
        tarball_path = f"{lima_repo_root}/lima-and-qemu.tar.gz"
        if os.path.exists(tarball_path):
            os.unlink(tarball_path)
        with tarfile.open(tarball_path, "w:gz") as tar:
            for file in tar_files:
                print(f"adding {dist_path}/{file} to tarball")
                tar.add(f"{dist_path}/{file}", arcname=file)
    except Exception as ex:
        raise RuntimeError("failed to package files") from ex

# File references may involve multiple symlinks that need to be recorded as well, e.g.
#
#   /usr/local/opt/libssh/lib/libssh.4.dylib
#
# turns into 2 symlinks and one file:
#
#   /usr/local/opt/libssh → ../Cellar/libssh/0.9.5_1
#   /usr/local/Cellar/libssh/0.9.5_1/lib/libssh.4.dylib → libssh.4.8.6.dylib
#   /usr/local/Cellar/libssh/0.9.5_1/lib/libssh.4.8.6.dylib [394K]
def record_dep(dep: str, deps: Dict[str, str], install_dir: str):
    if not dep: return
    if dep in global_seen: return
    global_seen.add(dep)

    if not os.path.isabs(dep):
        raise RuntimeError(f"{dep} is not an absolute path")
    
    dep = dep[1:]
    filename = ""
    dep_segments = dep.split("/")
    while dep_segments:
        segment = dep_segments.pop(0).strip()
        name = f"{filename}/{segment}"
        link = None
        if os.path.islink(name):
            try:
                link = os.readlink(name)
            except Exception as ex:
                raise RuntimeError(f"{name} is a link but failed to indirect it") from ex
        
        # symlinks in the bin directory are replaced by the target, and the symlinks are not
        # recorded (see above). However, at least "share/qemu" needs to remain a symlink to
        # "../Cellar/qemu/6.0.0/share/qemu" so qemu will still find its data files. Therefore
        # symlinks are still recorded for all other files.
        if link and not name.startswith(f"{install_dir}/bin"):
            # Record the symlink itself with the link target as the comment
            deps[name] = f"→ {link}"
            if os.path.isabs(link):
                # Can't support absolute links pointing outside /usr/local
                if not link.startswith(install_dir):
                    raise RuntimeError(f"{link} is not in {install_dir}")
                link = '/'.join([link] + dep_segments)
            else:
                link = '/'.join([filename, link] + dep_segments)

            # Re-parse from the start because the link may contain ".." segments
            record_dep(link, deps, install_dir)
            return
        
        if segment == "..":
            filename = os.path.dirname(filename)
        else:
            filename = name
    
    try:
        size = subprocess.check_output(f"ls -lh {filename}", shell=True, text=True).split()[4]
        deps[filename] = f"[{size}]"
    except Exception as ex:
        raise RuntimeError(f"failed to get size of {filename}") from ex

def parse_fs_usage_log(log_file: str, deps: Dict[str, str], install_dir: str):
    if not os.path.isfile(log_file):
        print(f"WARNING: fs_usage log file not found: ${log_file}")
        return
    
    fs_usage_deps_count = 0
    new_deps_count = 0
    with open(log_file, "r") as f:
        for line in f:
            line = line.strip()
            
            # Parse fs_usage output format:
            match = re.search(rf'\s+(open|read)\s+.*?\s+({re.escape(install_dir)}/\S+|\.\./\S+?)(?:\s+\d+\.\d+\s+\S+)?$', line)
            if not match: continue
            
            file_path = match.group(2)
            # Handle relative paths by removing "../" and prepending install_dir
            if file_path.startswith(".."):
                file_path = file_path.removeprefix("../")
                file_path = f"{install_dir}/{file_path}"
            
            # Skip directories starting with /opt/homebrew/Cellar/qemu unless -f
            if not os.path.isfile(file_path): continue
            
            # Count all fs_usage detected dependencies
            fs_usage_deps_count += 1
            
            # Skip if already recorded
            if file_path in deps: continue
            
            # Record this new dependency
            record_dep(file_path, deps, install_dir)
            new_deps_count += 1

            # Also find and record any symlinks pointing to this file
            res = subprocess.check_output(
                f"find -L {install_dir}/opt -samefile {file_path} 2>/dev/null", 
                shell=True,
                text=True,
            )
            for link in res.splitlines():
                link = link.strip()
                # Skip the file itself
                if link == file_path: continue
                # Skip if already recorded
                if link in deps: continue
                record_dep(link, deps, install_dir)
                new_deps_count += 1

    os.unlink(log_file)

def verify_dependencies(current_deps: Dict[str, str], arch: Literal[Arch.X86_64, Arch.AARCH64], install_dir: str):
    print("=== Dependency Verification ===")
    
    # Determine verification file based on architecture
    verification_file = "deps-verification-x86.txt" if arch == Arch.X86_64 else "deps-verification-arm64.txt"
    verification_path = os.path.join(os.getcwd(), verification_file)
    
    if not os.path.isfile(verification_path):
        print(f"WARNING: Verification file {verification_path} not found. Skipping dependency verification.")
        return
    
    print(f"Verifying dependencies against {verification_file} (ignoring version mismatches)...")
    
    # Load expected dependencies from verification file
    expected_deps = {}
    with open(verification_path) as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            
            # Parse line format: "/path/to/file [size]" or "/path/to/file → target"
            match = re.match(r'^(\S+)\s+(.+)$', line)
            if match:
                path, info = match.groups()
                expected_deps[path] = info
            else:
                # Handle lines that are just paths without additional info
                expected_deps[line] = ""
    
    print(f"Expected dependencies: {len(expected_deps)}")
    print(f"Current dependencies: {len(current_deps)}")
    
    print("--- Expected Dependencies ---")
    for path in sorted(expected_deps.keys()):
        print(f"  {path} {expected_deps[path]}")
    
    print("--- Current Dependencies ---")
    for path in sorted(current_deps.keys()):
        print(f"  {path} {current_deps[path]}")
    print()
    
    # Create version-agnostic lookup for expected dependencies
    expected_normalized = defaultdict(list)
    for path in expected_deps:
        normalized = normalize_path_for_version_comparison(path, install_dir)
        expected_normalized[normalized].append(path)
    
    # Create version-agnostic lookup for current dependencies
    current_normalized = defaultdict(list)
    for path in current_deps:
        normalized = normalize_path_for_version_comparison(path, install_dir)
        current_normalized[normalized].append(path)
    
    missing_deps = []
    unexpected_deps = []
    version_mismatches = []
    
    # Check for missing dependencies (ignoring versions)
    for normalized_expected in expected_normalized:
        if normalized_expected not in current_normalized:
            # No matching dependency found at all
            missing_deps.extend(expected_normalized[normalized_expected])
        else:
            # Check version mismatches
            for expected_path in expected_normalized[normalized_expected]:
                # If paths don't match exactly, it's a version mismatch
                if expected_path not in current_deps:
                    current_path = current_normalized[normalized_expected][0] if current_normalized[normalized_expected] else "unknown"
                    version_mismatches.append({"expected": expected_path, "current": current_path})
    
    # Check for unexpected dependencies (ignoring versions)
    for normalized_current in current_normalized:
        if normalized_current not in expected_normalized:
            unexpected_deps.extend(current_normalized[normalized_current])
    
    verification_failed = False
    if missing_deps:
        print("ERROR: Missing expected dependencies:")
        for dep in missing_deps:
            print(f"  - {dep}")
        verification_failed = True
    
    if unexpected_deps:
        print("ERROR: Unexpected dependencies found:")
        for dep in unexpected_deps:
            print(f"  + {dep} {current_deps[dep]}")
        verification_failed = True
    
    if version_mismatches:
        print("WARNING: Version mismatches detected (not failing verification):")
        for mismatch in version_mismatches:
            print(f"  ~ Expected: {mismatch['expected']}")
            print(f"    Current:  {mismatch['current']}")
        print("Note: Version mismatches are warnings only and do not cause verification failure.")
    
    if verification_failed:
        print("Dependency verification FAILED!")
        print("Please review the differences above and update the verification file if the changes are expected.")
        print(f"Verification file: {verification_path}")
        raise RuntimeError("Dependency verification FAILED!")
    else:
        print("Dependency verification PASSED!")
        if version_mismatches:
            print("Note: There were version mismatches (see warnings above), but verification still passed.")
    
    print("=== End Dependency Verification ===\n")

def normalize_path_for_version_comparison(path: str, install_dir: str):
    # Normalize versioned packages in opt directory
    # e.g., /opt/homebrew/opt/openssl@3.3 -> /opt/homebrew/opt/openssl@*
    # or /usr/local/opt/openssl@3.3 -> /usr/local/opt/openssl@*
    path = re.sub(rf'({re.escape(install_dir)}/opt/[^@]+@)\d+(\.\d+)*$', r'\1*', path)

    # Remove version numbers from Cellar paths
    # e.g., /opt/homebrew/Cellar/openssl@3/3.5.2/lib -> /opt/homebrew/Cellar/openssl@3/*/lib
    path = re.sub(r'(/Cellar/[^/]+)/[^/]+(/.*)?$', r'\1/*\2', path)

    # Remove version numbers from library filenames
    # e.g., libssl.3.dylib -> libssl.*.dylib
    path = re.sub(r'/lib([^/]+)\.(\d+(?:\.\d+)*)(\.dylib)$', r'/lib\1.*\3', path)

    # Remove version numbers from versioned library files
    # e.g., libssl.3.0.15.dylib -> libssl.*.dylib
    path = re.sub(r'/lib([^/]+)\.(\d+(?:\.\d+)*(?:\.\d+)*)(\.dylib)$', r'/lib\1.*\3', path)
    
    return path

def cleanup():
    # no need to check for failures here
    subprocess.run("sudo pkill fs_usage", shell=True)

main()