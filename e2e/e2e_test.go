// Copyright Amazon.com, Inc. or its affiliates.
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
	"github.com/runfinch/common-tests/command"
	"github.com/runfinch/common-tests/option"
	"github.com/runfinch/common-tests/tests"
)

func TestE2e(t *testing.T) {
	description := "Finch Core E2E Tests"

	limaRelativePath := "./../_output/bin/"
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
	subject := "limactl"
	vmConfigFile := filepath.Join(wd, "./../_output/lima-template/fedora.yaml")
	vmName := "fedora"
	limaOpt, err := option.New([]string{subject})
	nerdctlOpt, err := option.New([]string{subject, "shell", "fedora", "sudo", "-E", "nerdctl"})
	if err != nil {
		t.Fatalf("failed to initialize a testing option: %v", err)
	}

	ginkgo.SynchronizedBeforeSuite(func() []byte {
		command.New(limaOpt, "start", vmConfigFile).WithTimeoutInSeconds(600).Run()
		tests.SetupLocalRegistry(nerdctlOpt)
		return nil
	}, func(bytes []byte) {})

	ginkgo.SynchronizedAfterSuite(func() {
		command.New(limaOpt, "stop", vmName).WithTimeoutInSeconds(90).Run()
		command.New(limaOpt, "remove", vmName).WithTimeoutInSeconds(60).Run()
	}, func() {})

	ginkgo.Describe(description, func() {
		// TODO: add more e2e tests and make them work.
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
	})

	gomega.RegisterFailHandler(ginkgo.Fail)
	ginkgo.RunSpecs(t, description)
}
