// Copyright Amazon.com, Inc. or its affiliates.
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"testing"

	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
	"github.com/runfinch/common-tests/command"
	"github.com/runfinch/common-tests/option"
	"github.com/runfinch/common-tests/tests"
)

func TestE2e(t *testing.T) {
	description := "Finch Core E2E Tests"

	limaRelativePath := "./../_output/lima/bin/"
	limaAbsPath, err := filepath.Abs(limaRelativePath)
	if err != nil {
		t.Fatalf("Error getting absolute path: %v", err)
	}
	// Add custom qemu to path
	currentPath := os.Getenv("PATH")

	// Put ./../_output/bin first on path to override other installations of lima and qemu
	newPath := limaAbsPath + string(os.PathListSeparator) + currentPath
	err = os.Setenv("PATH", newPath)
	if err != nil {
		t.Fatalf("Error setting PATH: %v", err)
	}

	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get the current working directory: %v", err)
	}

	configFileName := "macos.yaml"
	if runtime.GOOS == "windows" {
		configFileName = "windows.yaml"
	}
	vmConfigFile := filepath.Join(wd, "./../_output/lima-template/", configFileName)

	subject := "limactl"
	limaOpt, err := option.New([]string{subject})
	if err != nil {
		t.Fatalf("failed to initialize a testing option: %v", err)
	}

	vmName := "finch"

	nerdctlMods := []option.Modifier{option.WithNoEnvironmentVariablePassthrough()}
	if runtime.GOOS == "windows" {
		// On Windows, file paths must be translated to WSL compatible paths.
		nerdctlMods = append(nerdctlMods, option.WithWindowsHostPathTranslation())
	}

	nerdctlOpt, err := option.New(
		[]string{subject, "shell", vmName, "sudo", "-E", "nerdctl"},
		nerdctlMods...,
	)
	if err != nil {
		t.Fatalf("failed to initialize a testing option: %v", err)
	}

	vmType := os.Getenv("VM_TYPE")
	if vmType == "" {
		// Virtualization framework is the default Finch launch type on macOS.
		vmType = "vz"
	}

	var runOpt *tests.RunOption
	switch runtime.GOOS {
	case "windows":
		runOpt = &tests.RunOption{
			BaseOpt: nerdctlOpt,
			CGMode:  tests.Hybrid,
		}
	case "darwin":
		runOpt = &tests.RunOption{
			BaseOpt: nerdctlOpt,
			CGMode:  tests.Unified,
			// See https://lima-vm.io/docs/config/network/user/.
			DefaultHostGatewayIP: "192.168.5.2",
		}
	}

	ginkgo.SynchronizedBeforeSuite(func() []byte {
		limactlStartOpts := []string{"start", vmConfigFile, "--name", vmName, "--vm-type", vmType}
		if vmType == "vz" {
			limactlStartOpts = append(limactlStartOpts, "--set", ".ssh.overVsock=false")
		}
		command.New(limaOpt, limactlStartOpts...).WithTimeoutInSeconds(600).Run()
		tests.SetupLocalRegistry(nerdctlOpt)

		// Get the WSL host gateway ip using netsh. This is only available when a
		// WSL VM instance is running.
		if runtime.GOOS == "windows" {
			n, err := exec.Command("netsh", "interface", "ipv4", "show", "addresses", "vEthernet (WSL (Hyper-V firewall))").CombinedOutput()
			gomega.Expect(err).Should(gomega.BeNil(), "netsh output: %s", string(n))
			runOpt.DefaultHostGatewayIP = extractIPAddress(string(n))
		}

		// Finch CLI rewrites `--add-host <host>:host-gateway` to the host
		// IP before invoking nerdctl. Our subject runs nerdctl theough lima directly, so nerdctl
		// will fall back to its own default (the guest's own IP).
		// Configure the guest's nerdctl.toml so nerdctl resolves host-gateway to the host IP.
		if runOpt != nil && runOpt.DefaultHostGatewayIP != "" {
			script := fmt.Sprintf(
				"mkdir -p /etc/nerdctl && printf 'host_gateway_ip = \"%s\"\\n' > /etc/nerdctl/nerdctl.toml",
				runOpt.DefaultHostGatewayIP,
			)
			command.New(limaOpt, "shell", vmName, "sudo", "sh", "-c", script).Run()
		}
		return nil
	}, func(bytes []byte) {})

	ginkgo.SynchronizedAfterSuite(func() {
		printLimaLogs(vmName)
		command.New(limaOpt, "stop", vmName).WithTimeoutInSeconds(90).Run()
		command.New(limaOpt, "remove", vmName).WithTimeoutInSeconds(60).Run()
	}, func() {})

	ginkgo.Describe(description, func() {
		if runOpt != nil {
			tests.Run(runOpt)
		}
		tests.Ps(nerdctlOpt)
		tests.Restart(nerdctlOpt)
		tests.Save(nerdctlOpt)
		tests.Load(nerdctlOpt)
		tests.Pull(nerdctlOpt)
		tests.Rm(nerdctlOpt)
		tests.Rmi(nerdctlOpt)
		tests.Start(nerdctlOpt)
		tests.Stop(nerdctlOpt)
		tests.Cp(nerdctlOpt)
		tests.Tag(nerdctlOpt)
		tests.Build(nerdctlOpt)
		tests.Push(nerdctlOpt)
		tests.Images(nerdctlOpt)
		tests.ComposeBuild(nerdctlOpt)
		tests.ComposeDown(nerdctlOpt)
		tests.ComposeKill(nerdctlOpt)
		tests.ComposePs(nerdctlOpt)
		tests.ComposePull(nerdctlOpt)
		tests.ComposeLogs(nerdctlOpt)
		tests.Create(nerdctlOpt)
		tests.Port(nerdctlOpt)
		tests.Kill(nerdctlOpt)
		tests.Stats(nerdctlOpt)
		tests.BuilderPrune(nerdctlOpt)
		tests.Exec(nerdctlOpt)
		tests.Logs(nerdctlOpt)
		tests.Login(nerdctlOpt)
		tests.Logout(nerdctlOpt)
		tests.VolumeCreate(nerdctlOpt)
		tests.VolumeInspect(nerdctlOpt)
		tests.VolumeLs(nerdctlOpt)
		tests.VolumeRm(nerdctlOpt)
		tests.VolumePrune(nerdctlOpt)
		tests.ImageHistory(nerdctlOpt)
		tests.ImageInspect(nerdctlOpt)
		tests.ImagePrune(nerdctlOpt)
		tests.Info(nerdctlOpt)
		tests.Events(nerdctlOpt)
		tests.Inspect(nerdctlOpt)
		tests.NetworkCreate(nerdctlOpt)
		tests.NetworkInspect(nerdctlOpt)
		tests.NetworkLs(nerdctlOpt)
		tests.NetworkRm(nerdctlOpt)
		tests.HealthCheck(nerdctlOpt)
	})

	gomega.RegisterFailHandler(ginkgo.Fail)
	ginkgo.RunSpecs(t, description)
}

func extractIPAddress(data string) string {
	re := regexp.MustCompile(`IP Address:\s+(\d+\.\d+\.\d+\.\d+)`)
	match := re.FindStringSubmatch(data)

	if match != nil {
		return match[1]
	}
	return ""
}

func printLimaLogs(vmName string) {
	userHomeDir := os.Getenv("HOME")
	if userHomeDir == "" {
		return
	}

	stdoutLog := filepath.Join(userHomeDir, ".lima", vmName, "ha.stdout.log")
	stderrLog := filepath.Join(userHomeDir, ".lima", vmName, "ha.stderr.log")

	if stdout, err := os.ReadFile(stdoutLog); err == nil {
		ginkgo.GinkgoWriter.Printf("\n=== Lima stdout log ===\n%s\n", string(stdout))
	}

	if stderr, err := os.ReadFile(stderrLog); err == nil {
		ginkgo.GinkgoWriter.Printf("\n=== Lima stderr log ===\n%s\n", string(stderr))
	}
}
