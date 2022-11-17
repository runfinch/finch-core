// Copyright Amazon.com, Inc. or its affiliates.
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
	"github.com/runfinch/common-tests/option"
	"github.com/runfinch/common-tests/tests"
)

func TestE2e(t *testing.T) {
	description := "Finch Core e2e Tests"

	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get the current working directory: %v", err)
	}
	limactl := filepath.Join(wd, "../_output/lima/bin/limactl")

	o, err := option.New([]string{limactl, "shell", "fedora", "nerdctl"})
	if err != nil {
		t.Fatalf("failed to initialize a testing option: %v", err)
	}

	ginkgo.Describe(description, func() {
		// TODO: add more e2e tests and make them work.
		tests.Pull(o)
	})

	gomega.RegisterFailHandler(ginkgo.Fail)
	ginkgo.RunSpecs(t, description)
}
