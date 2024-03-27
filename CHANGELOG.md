# Changelog

## [0.2.0](https://github.com/runfinch/finch-core/compare/v0.1.2...v0.2.0) (2024-03-27)


### Features

* add windows targets in makefile ([#192](https://github.com/runfinch/finch-core/issues/192)) ([9bc03a0](https://github.com/runfinch/finch-core/commit/9bc03a08cf312f99077cad1be30efeca6b69748c))
* **make:** support Windows ([#134](https://github.com/runfinch/finch-core/issues/134)) ([bdd30e6](https://github.com/runfinch/finch-core/commit/bdd30e63c7fa5e1fd1b977d6b1dfb014958b6a19))
* rootfs - build/upload action and Dockerfile ([#125](https://github.com/runfinch/finch-core/issues/125)) ([865cbfe](https://github.com/runfinch/finch-core/commit/865cbfeff9c8ba5e0b67b03910c5dcec894f3913))
* update infrastructure to use macOS 14 ([#210](https://github.com/runfinch/finch-core/issues/210)) ([eb14219](https://github.com/runfinch/finch-core/commit/eb14219b382bd1233ca6261e782fd4ecf2c1f08a))


### Bug Fixes

* aarch64 OS image improperly generated ([#277](https://github.com/runfinch/finch-core/issues/277)) ([1deaace](https://github.com/runfinch/finch-core/commit/1deaace0fd93bf38ad9012992bf7563c098f8c0f))
* add ecr authentication ([#129](https://github.com/runfinch/finch-core/issues/129)) ([91b4f65](https://github.com/runfinch/finch-core/commit/91b4f65235ec2ef7e09db17acdeadb7eaf5e652f))
* add timestep stamp to generating rootfs ([#130](https://github.com/runfinch/finch-core/issues/130)) ([2fc49cd](https://github.com/runfinch/finch-core/commit/2fc49cd7451e3825a823417f87fff9a6a71a0d02))
* Change rootfs compression to gzip ([#142](https://github.com/runfinch/finch-core/issues/142)) ([3353d02](https://github.com/runfinch/finch-core/commit/3353d029bebcd6af38d3a6a549350eeca633691a))
* e2e tests ([#143](https://github.com/runfinch/finch-core/issues/143)) ([0ab8035](https://github.com/runfinch/finch-core/commit/0ab8035a44b2cd99c7668a0cf8739f848153d07b))
* properly checkout lima tags and pin all actions ([#248](https://github.com/runfinch/finch-core/issues/248)) ([ed994e1](https://github.com/runfinch/finch-core/commit/ed994e1ad3f73d5db38a82814d7d768dd1db5ad2))
* properly checkout submodule tags ([#250](https://github.com/runfinch/finch-core/issues/250)) ([ad0fd8d](https://github.com/runfinch/finch-core/commit/ad0fd8d5aa411170fdad74e8ea7e3330762b1724))
* quote recursive calls to make ([#133](https://github.com/runfinch/finch-core/issues/133)) ([1b7aeb2](https://github.com/runfinch/finch-core/commit/1b7aeb2a8e168db640c89dc8dbcd1642efba501a))
* setup local registry before trying to run tests ([#284](https://github.com/runfinch/finch-core/issues/284)) ([180e3bf](https://github.com/runfinch/finch-core/commit/180e3bfc13fcb17227db634b07c149c991fc5256))
* setup-go in CI to resolve cache warnings ([#120](https://github.com/runfinch/finch-core/issues/120)) ([2ab5503](https://github.com/runfinch/finch-core/commit/2ab550381e8a06654138d8d60e210f18e806b69e))
* use --recursive and correct pathing in update rootfs ([#132](https://github.com/runfinch/finch-core/issues/132)) ([0741eeb](https://github.com/runfinch/finch-core/commit/0741eeb9ea5a5fc7393b52ef5635ef69cf42af97))


### Performance Improvements

* add lima dependency pkgs to speed up VM boot ([#157](https://github.com/runfinch/finch-core/issues/157)) ([2f63058](https://github.com/runfinch/finch-core/commit/2f63058f4d0340eaa584216e189e16f915565c3f))

## [0.1.2](https://github.com/runfinch/finch-core/compare/v0.1.1...v0.1.2) (2023-01-26)


### Bug Fixes

* Add command to fetch remote tags ([#26](https://github.com/runfinch/finch-core/issues/26)) ([71787b5](https://github.com/runfinch/finch-core/commit/71787b5399db4881855ee660c2888eb1d10acd9d))
* properly set socket_vmnet version ([#38](https://github.com/runfinch/finch-core/issues/38)) ([a87d6ac](https://github.com/runfinch/finch-core/commit/a87d6ac36ca502bece808e5a5eb7355c84d027d1))

## [0.1.1](https://github.com/runfinch/finch-core/compare/v0.1.0...v0.1.1) (2022-12-06)


### Bug Fixes

* Change checksum format to support macos 10.15 build ([#16](https://github.com/runfinch/finch-core/issues/16)) ([33de22a](https://github.com/runfinch/finch-core/commit/33de22a9cfe1c847f0513711b813a8dd739df849))
