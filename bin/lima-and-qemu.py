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
    arch = get_system_arch()
    install_dir = get_installation_dir(arch)
    qemu_version = get_installed_qemu_version()
    print("using templates: ", templates)
    print("using arch", arch)
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

    print("parsing fs_usage log...")
    parse_fs_usage_log(fs_usage_log, deps, install_dir)

    print("Verifying dependencies...")
    verify_dependencies(deps, arch, install_dir)

    print("Copying dependencies and resigning...")
    dist_path = copy_deps_and_resign(deps, arch, install_dir)

    print("Packaging files and socket_vmnet...")
    package_files_and_socket_vmnet(deps, install_dir, dist_path)

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
        # TODO: cleanup
        # atexit.register(lambda: subprocess.run("sudo pkill fs_usage", shell=True))
        return fs_usage_log
    except Exception as ex:
        raise RuntimeError("failed to start fs_usage") from ex

def stop_fs_usage():
    try:
        subprocess.run("sudo pkill fs_usage", shell=True, check=True)
    except Exception as ex:
        raise RuntimeError("failed to stop fs_usage") from ex

# TODO: do we really need to still check if limactl version is <= 1.0.0-alpha.0?
def run_lima_templates(templates: List[str]):
    lima_repo_root = os.path.join(os.getcwd(), "..", 'src', 'lima')
    lima_template_dir = os.path.join(lima_repo_root, 'templates')
    for template in templates:
        template_yaml = os.path.join(lima_template_dir, f"{template}.yaml")
        if not os.path.exists(template_yaml):
            raise RuntimeError(f"template {template} does not exist in {lima_template_dir}")
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
        raise RuntimeError(f"failed to run lima template {template_name}") from ex

# TODO: error handling
def copy_deps_and_resign(deps: Dict[str, str], arch: Literal[Arch.X86_64, Arch.AARCH64], install_dir: str):
    resign_files = set()
    dist_path = "/tmp/lima-and-qemu"
    shutil.rmtree(dist_path, ignore_errors=True)
    
    for file_path in deps.keys():
        copy_path = file_path.replace(install_dir, dist_path)   
        os.makedirs(os.path.dirname(copy_path), exist_ok=True)
        
        if file_path.startswith(f'{install_dir}/bin/'):
            shutil.copy(file_path, copy_path, follow_symlinks=True)
        else:
            shutil.copy(file_path, copy_path, follow_symlinks=False)
            if os.path.islink(file_path):
                continue
        
        # if the file is not a mac os executable, skip the otool run for the file
        if 'Mach-O' not in subprocess.check_output(f"file {copy_path}", shell=True, text=True):
            continue
        
        res = subprocess.run(f"otool -L {file_path}", shell=True, capture_output=True, text=True, check=True)
        for line in res.stdout.splitlines():
            match = re.search(rf'{install_dir}/(\S+)', line)
            if not match: continue
            dylib = match.group(1)
            
            grep_filter = ""
            if file_path.endswith(f'bin/qemu-system-{arch}'):
                grep_filter = "| grep -v 'will invalidate the code signature'"
                resign_files.add(copy_path)
            if arch == Arch.AARCH64:
                resign_files.add(copy_path)
            
            install_name_tool_cmd = f"install_name_tool -change {install_dir}/{dylib} @executable_path/../{dylib} {copy_path} 2>&1 {grep_filter}"
            subprocess.run(install_name_tool_cmd, shell=True, check=True)

    resign(resign_files)
    return dist_path

def resign(resign_files: Set[str]):
    for file_path in resign_files:
        subprocess.run(
            f"codesign --sign - --force --preserve-metadata=entitlements {file_path}",
            shell=True,
            check=True
        )

# TODO: error handling
def package_files_and_socket_vmnet(deps: Dict[str, str], install_dir: str, dist_path: str):
    tar_files = [path.removeprefix(f"{install_dir}/") for path in deps.keys()]

    # Package socket_vmnet
    socket_vmnet_dest = f"{dist_path}/socket_vmnet"
    if os.path.exists(socket_vmnet_dest):
        raise RuntimeError(f"{socket_vmnet_dest} already exists")
    socket_vmnet_src = "/opt/socket_vmnet/bin/socket_vmnet"
    if os.path.isfile(socket_vmnet_src):
        os.makedirs(f"{socket_vmnet_dest}/bin", exist_ok=True)
        shutil.copy(socket_vmnet_src, f"{socket_vmnet_dest}/bin/socket_vmnet")
        tar_files.append("socket_vmnet/bin/socket_vmnet")

    # Ensure all files are writable by the owner; this is required for Squirrel.Mac
    # to remove the quarantine xattr when applying updates.
    subprocess.run(f"chmod -R u+w {dist_path}", shell=True, check=True)

    lima_repo_root = os.path.join(os.getcwd(), "..", 'src', 'lima')
    tarball_path = f"{lima_repo_root}/lima-and-qemu.tar.gz"
    if os.path.exists(tarball_path):
        os.unlink(tarball_path)
    with tarfile.open(tarball_path, "w:gz") as tar:
        for file in tar_files:
            tar.add(f"{dist_path}/{file}", arcname=file)

# TODO: error handling
def record_dep(dep: str, deps: Dict[str, str], install_dir: str):
    if dep in global_seen:
        return
    global_seen.add(dep)

    if not os.path.isabs(dep):
        raise RuntimeError(f"{dep} is not an absolute path")
    
    dep = dep[1:]
    filename = ""
    dep_segments = dep.split("/")
    while dep_segments:
        segment = dep_segments.pop(0)
        name = f"{filename}/{segment}"
        link = os.readlink(name)
        if link and not name.startswith(f"{install_dir}/bin"):
            deps[name] = f"→ {link}"
            if os.path.isabs(link):
                if not link.startswith(install_dir):
                    raise RuntimeError(f"{link} is not in {install_dir}")
                link = '/'.join([link] + dep_segments)
            else:
                link = '/'.join([filename, link] + dep_segments)
    
            record_dep(link, deps, install_dir)
            return
        
        if segment == "..":
            filename = os.path.dirname(filename)
        else:
            filename = name
    
    size = subprocess.check_output(f"ls -lh {filename}", shell=True, text=True).split()[4]
    deps[filename] = f"[{size}]"

def parse_fs_usage_log(log_file: str, deps: Dict[str, str], install_dir: str):
    if not os.path.isfile(log_file):
        print(f"WARNING: fs_usage log file not found: ${log_file}")
        return
    
    fs_usage_deps_count = 0
    new_deps_count = 0
    with open(log_file, "r") as f:
        for line in f:
            line = line.strip()
            match = re.search(rf'\s+(open|read)\s+.*?\s+({re.escape(install_dir)}/\S+|\.\./\S+?)(?:\s+\d+\.\d+\s+\S+)?$', line)
            if not match: continue
            
            file_path = match.group(2)
            # Handle relative paths by removing "../" and prepending install_dir
            if file_path.startswith(".."):
                file_path = file_path.removeprefix("../")
                file_path = f"{install_dir}/{file_path}"
            if not os.path.isfile(file_path): continue
            fs_usage_deps_count += 1
            if file_path in deps: continue
            # Record this new dependency
            record_dep(file_path, deps, install_dir)
            new_deps_count += 1

            res = subprocess.run(
                f"find -L {install_dir}/opt -samefile {file_path} 2>/dev/null", 
                shell=True,
                capture_output=True, 
                text=True,
                check=True
            )
            links= res.stdout.strip().split('\n')
            for link in links:
                link = link.strip()
                if link == file_path: continue
                if link in deps: continue
                record_dep(link, deps, install_dir)
                new_deps_count += 1

    os.unlink(log_file)

def verify_dependencies(current_deps: Dict[str, str], arch: Literal[Arch.X86_64, Arch.AARCH64], install_dir: str):
    print("=== Dependency Verification ===")
    
    verification_file = "deps-verification-x86.txt" if arch == Arch.X86_64 else "deps-verification-arm64.txt"
    verification_path = os.path.join(os.getcwd(), "..", verification_file)
    
    if not os.path.isfile(verification_path):
        print(f"WARNING: Verification file {verification_path} not found. Skipping dependency verification.")
        return
    
    print(f"Verifying dependencies against {verification_file} (ignoring version mismatches)...")
    
    # Load expected dependencies
    expected_deps = {}
    with open(verification_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            match = re.match(r'^(\S+)\s+(.+)$', line)
            if match:
                path, info = match.groups()
                expected_deps[path] = info
            else:
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
    
    # Create normalized lookups
    expected_normalized = defaultdict(list)
    for path in expected_deps:
        normalized = normalize_path_for_version_comparison(path, install_dir)
        expected_normalized[normalized].append(path)
    
    current_normalized = defaultdict(list)
    for path in current_deps:
        normalized = normalize_path_for_version_comparison(path, install_dir)
        current_normalized[normalized].append(path)
    
    missing_deps = []
    unexpected_deps = []
    version_mismatches = []
    
    # Check for missing dependencies
    for normalized_expected in expected_normalized:
        if normalized_expected not in current_normalized:
            missing_deps.extend(expected_normalized[normalized_expected])
        else:
            # Check version mismatches
            for expected_path in expected_normalized[normalized_expected]:
                if expected_path not in current_deps:
                    current_path = current_normalized[normalized_expected][0] if current_normalized[normalized_expected] else "unknown"
                    version_mismatches.append({"expected": expected_path, "current": current_path})
    
    # Check for unexpected dependencies
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
    path = re.sub(rf'({re.escape(install_dir)}/opt/[^@]+@)\d+(\.\d+)*$', r'\1*', path)
    path = re.sub(r'(/Cellar/[^/]+)/[^/]+(/.*)?$', r'\1/*\2', path)
    path = re.sub(r'/lib([^/]+)\.(\d+(?:\.\d+)*)(\.dylib)$', r'/lib\1.*\3', path)
    path = re.sub(r'/lib([^/]+)\.(\d+(?:\.\d+)*(?:\.\d+)*)(\.dylib)$', r'/lib\1.*\3', path)
    return path

main()