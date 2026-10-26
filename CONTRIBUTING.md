# Contributing Guide

- [Contributing Guide](#contributing-guide)
  - [Participating in the Project](#participating-in-the-project)
    - [Community Participant](#community-participant)
    - [Contributor](#contributor)
    - [Maintainer](#maintainer)
  - [Ways to Contribute](#ways-to-contribute)
  - [Find an Issue](#find-an-issue)
  - [Ask for Help](#ask-for-help)
  - [Pull Request Lifecycle](#pull-request-lifecycle)
  - [Development Environment Setup](#development-environment-setup)
    - [Build](#build)
    - [E2E Testing](#e2e-testing)
  - [Sign Your Commits](#sign-your-commits)
    - [DCO](#dco)
  - [Pull Request Checklist](#pull-request-checklist)
    - [Build](#build-1)
    - [Testing](#testing)
      - [E2E Testing](#e2e-testing-1)

Welcome! We are glad that you want to contribute to our project! 💖

As you get started, you are in the best position to give us feedback on areas of
our project that we need help with including:

* Problems found during setting up a new developer environment
* Bugs in our automation scripts

If anything doesn't make sense, or doesn't work when you run it, please open a
bug report and let us know!

## Participating in the Project

There are a number of ways to participate in this project. As the project evolves and grows, we will define a more formal governance model. For now, this document describes various ways community members might participate.

### Community Participant

A Community Participant engages with the project and its community, contributing their time, thoughts, etc. Community participants are usually users who have stopped being anonymous and started being active in project discussions.

### Contributor

A Contributor contributes directly to the project. Contributions need not be code. People at the Contributor level may be new contributors, or they may only contribute occasionally.

### Maintainer

Maintainers are established contributors who are responsible for the entire project. As such, they have the ability to approve PRs against any area of the project, and are expected to participate in making decisions about the strategy and priorities of the project.

## Ways to Contribute

We welcome many different types of contributions including:

* New features
* Builds, CI/CD
* Bug fixes
* Documentation
* Issue Triage
* Communications / Social Media / Blog Posts
* Release management

## Find an Issue

We have good first issues for new contributors and help wanted issues suitable
for any contributor. [good first issue](TODO) has extra information to
help you make your first contribution. [help wanted](TODO) are issues
suitable for someone who isn't a core maintainer and is good to move onto after
your first pull request.

Sometimes there won’t be any issues with these labels. That’s ok! There is
likely still something for you to work on. If you want to contribute but you
don’t know where to start or have an idea, feel free to open a new issue in Github for brainstorming.

Once you see an issue that you'd like to work on, please post a comment saying
that you want to work on it. Something like "I want to work on this" is fine.

## Ask for Help

The best way to reach us with a question when contributing is to ask on the original github issue.

## Pull Request Lifecycle

Generally a comment should be resolved by the one who leaves the comment.

For PR authors, if a comment is not left by you, please do not resolve it even after applying the changes suggested by it. This is to make sure that the changes do address the concern of the PR reviewer as there could be misunderstanding between PR authors and PR reviewers. However, if the PR reviewer is not responding to the comment for whatever reason, the project maintainers can help resolve the comment to unblock the PR author.

For PR reviewers, after a comment left by you is acted upon, it is encouraged to either reply to it or resolve it in a timely manner to unblock the PR author because all the comments are required to be resolved before a PR can be merged. For project maintainers, please target handling unresolved comments within 2 working days.

We feel spelling these norms out is better than assuming them, and we all acknowledge life happens and these are guidelines, not strict rules.

## Development Environment Setup

This section describes how one can develop Finch Core locally on macOS, build it, and then run it to test out the changes.

### Build

After cloning the repo, run the following instructions to build the project.

Recursively fetch git submodules.

```
git submodule update --init --recursive
```

Fetch and install dependencies first. Note that QEMU is used in the install, but we build a pinned version.

```
brew update
brew install go qemu bash coreutils autoconf automake cpanm
brew upgrade
sudo cpanm install JSON
curl -OL https://bitbucket.org/objective-see/deploy/downloads/FileMonitor_1.3.0.zip
rm -rf /Applications/FileMonitor.app
unzip FileMonitor_1.3.0.zip -d /Applications
```

#### Build core

Build project locally. Ensure that your terminal has full disk access as required by `FileMonitor`.

```
make install-deps
```

#### Untar built dependencies to output directory
```
mkdir -p _output/lima
tar vxf ./src/lima/lima-and-qemu.macos-<arch>.<timestamp>.tar.gz -C ./_output/lima
```

#### Start Lima virtual machine

```
./_output/lima/bin/limactl start ./lima-template/fedora.yaml --tty=false
```

### Run commands

Run and test any command you wish with the following.
```
./_output/lima/bin/limactl shell fedora nerdctl ...
```

### E2E Testing

Note that the vm instance is NOT expected to exist before running the tests, please ensure it is removed before running the tests.
```
./_output/lima/bin/limactl stop fedora
./_output/lima/bin/limactl remove fedora
```
And finally, run the tests with:
```
make test-e2e
```

## Sign Your Commits

### DCO
Licensing is important to open source projects. It provides some assurances that
the software will continue to be available based under the terms that the
author(s) desired. We require that contributors sign off on commits submitted to
our project's repositories. The [Developer Certificate of Origin
(DCO)](https://probot.github.io/apps/dco/) is a way to certify that you wrote and
have the right to contribute the code you are submitting to the project.

You sign-off by adding the following to your commit messages. Your sign-off must
match the git user and email associated with the commit.

    This is my commit message

    Signed-off-by: Your Name <your.name@example.com>

Git has a `-s` command line option to do this automatically:

    git commit -s -m 'This is my commit message'

If you forgot to do this and have not yet pushed your changes to the remote
repository, you can amend your commit with the sign-off by running

    git commit --amend -s

## Pull Request Checklist

When you submit your pull request, or you push new commits to it, our automated
systems will run some checks on your new code. We require that your pull request
passes these checks, but we also have more criteria than just that before we can
accept and merge it. We recommend that you check the following things locally
before you submit your code:

### Build

```make install-deps```

### Testing

#### E2E Testing

```make test-e2e```

See `test-e2e` section in [`Makefile`](./Makefile) for more reference.

If the e2e test scenarios you are going to contribute

- are in generic container development workflow
- can be shared by finch-core by replacing test subject from "finch" to "limactl ..."
- E.g.: pull, push, build, run, etc.

implement them in common-tests repo and then import them in [`./e2e/e2e_test.go`](./e2e/e2e_test.go) in finch CLI and finch-core. The detailed flow can be found [here](https://github.com/runfinch/common-tests#sync-between-tests-and-code).

Otherwise, it means that the scenarios are specific to finch core, and you should implement them under `./e2e/` and import them in `./e2e/e2e_test.go`.

## Merge dependabot PRs

If you have write access to the repository, and all the checks have passed, feel free to merge the PR.

If you're the only approver of the PR, and the PR branch has been outdated, please comment `@dependabot rebase` on the PR to update it.

If you [directly use GitHub UI to update the PR branch](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/keeping-your-pull-request-in-sync-with-the-base-branch), then you will be the author of the merge commit, and since we [require the approver not to be the last pusher of the PR](https://github.blog/changelog/2022-10-20-new-branch-protections-last-pusher-and-locked-branch/), you won't be able to merge the PR unless someone else with write access approves the PR.
