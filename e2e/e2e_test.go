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
	vmConfigFile := filepath.Join(wd, "./../lima-template/fedora.yaml")
	vmName := "fedora"
	o, err := option.New([]string{subject})

	ginkgo.SynchronizedBeforeSuite(func() []byte {
		command.New(o, "start", vmConfigFile).WithTimeoutInSeconds(600).Run()
		return nil
	}, func(bytes []byte) {})

	ginkgo.SynchronizedAfterSuite(func() {
		command.New(o, "stop", vmName).WithTimeoutInSeconds(90).Run()
		command.New(o, "remove", vmName).WithTimeoutInSeconds(60).Run()
	}, func() {})

	opt, err := option.New([]string{subject, "shell", "fedora", "sudo", "-E", "nerdctl"})
	if err != nil {
		t.Fatalf("failed to initialize a testing option: %v", err)
	}

	ginkgo.Describe(description, func() {
		// TODO: add more e2e tests and make them work.
		tests.Save(opt)
		tests.Load(opt)
		tests.Pull(opt)
		tests.Rm(opt)
		tests.Rmi(opt)
		tests.Start(opt)
		tests.Stop(opt)
		tests.Cp(opt)
		tests.Tag(opt)
		tests.Build(opt)
		tests.Push(opt)
		tests.Images(opt)
		tests.ComposeBuild(opt)
		tests.ComposeDown(opt)
		tests.ComposeKill(opt)
		tests.ComposePs(opt)
		tests.ComposePull(opt)
		tests.ComposeLogs(opt)
		tests.Create(opt)
		tests.Port(opt)
		tests.Kill(opt)
		tests.Stats(opt)
		tests.BuilderPrune(opt)
		tests.Exec(opt)
		tests.Logs(opt)
		tests.Login(opt)
		tests.Logout(opt)
		tests.VolumeCreate(opt)
		tests.VolumeInspect(opt)
		tests.VolumeLs(opt)
		tests.VolumeRm(opt)
		tests.VolumePrune(opt)
		tests.ImageHistory(opt)
		tests.ImageInspect(opt)
		tests.ImagePrune(opt)
		tests.Info(opt)
		tests.Events(opt)
		tests.Inspect(opt)
		tests.NetworkCreate(opt)
		tests.NetworkInspect(opt)
		tests.NetworkLs(opt)
		tests.NetworkRm(opt)
	})

	gomega.RegisterFailHandler(ginkgo.Fail)
	ginkgo.RunSpecs(t, description)
}
