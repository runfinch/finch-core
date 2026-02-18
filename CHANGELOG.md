# Changelog

## 1.0.0 (2026-02-18)


### Features

* add container runtime archive configuration ([#476](https://github.com/runfinch/finch-core/issues/476)) ([fb8861c](https://github.com/runfinch/finch-core/commit/fb8861cd1acd7884a2e51a0a37378d885a0d6409))
* add finch daemon credential helper support to finch ([#639](https://github.com/runfinch/finch-core/issues/639)) ([1a0e535](https://github.com/runfinch/finch-core/commit/1a0e535da30235f38cda2f9e90435636e3b26e5b))
* add windows targets in makefile ([#192](https://github.com/runfinch/finch-core/issues/192)) ([9bc03a0](https://github.com/runfinch/finch-core/commit/9bc03a08cf312f99077cad1be30efeca6b69748c))
* Add workflow to update windows hash and filename ([#446](https://github.com/runfinch/finch-core/issues/446)) ([a301558](https://github.com/runfinch/finch-core/commit/a301558b6da0768b68af0be941d966c0e4e57169))
* **make:** support Windows ([#134](https://github.com/runfinch/finch-core/issues/134)) ([bdd30e6](https://github.com/runfinch/finch-core/commit/bdd30e63c7fa5e1fd1b977d6b1dfb014958b6a19))
* Migrate to fs_usage from file_monitor ([#696](https://github.com/runfinch/finch-core/issues/696)) ([d5157dc](https://github.com/runfinch/finch-core/commit/d5157dc6b3be6a5f65f1e0bbf5e240623f7821e0))
* Override Runc Version ([#737](https://github.com/runfinch/finch-core/issues/737)) ([83e39bd](https://github.com/runfinch/finch-core/commit/83e39bd3c729ce4da9e7ff21841544c8e89ae235))
* rootfs - build/upload action and Dockerfile ([#125](https://github.com/runfinch/finch-core/issues/125)) ([865cbfe](https://github.com/runfinch/finch-core/commit/865cbfeff9c8ba5e0b67b03910c5dcec894f3913))
* update container runtime full archive to nerdctl v2.0.2-1735857497 ([#472](https://github.com/runfinch/finch-core/issues/472)) ([49ebd39](https://github.com/runfinch/finch-core/commit/49ebd39b0846f77f4f6db597d59a215b60578998))
* update infrastructure to use macOS 14 ([#210](https://github.com/runfinch/finch-core/issues/210)) ([eb14219](https://github.com/runfinch/finch-core/commit/eb14219b382bd1233ca6261e782fd4ecf2c1f08a))
* update lima to 2.0.3 ([#844](https://github.com/runfinch/finch-core/issues/844)) ([6079a63](https://github.com/runfinch/finch-core/commit/6079a63e17c4f8935de188c3ca25e97aefa47251))
* Upgrade runc to v1.3.3 ([#752](https://github.com/runfinch/finch-core/issues/752)) ([e31389f](https://github.com/runfinch/finch-core/commit/e31389fb3425104ee7b9611eb8a66b713fab2b27))
* Upgrade windows rootfs to fedora 42 ([#718](https://github.com/runfinch/finch-core/issues/718)) ([b052750](https://github.com/runfinch/finch-core/commit/b0527505933fadd4dce04347bb66c5f46508cad1))


### Bug Fixes

* aarch64 OS image improperly generated ([#277](https://github.com/runfinch/finch-core/issues/277)) ([1deaace](https://github.com/runfinch/finch-core/commit/1deaace0fd93bf38ad9012992bf7563c098f8c0f))
* add ecr authentication ([#129](https://github.com/runfinch/finch-core/issues/129)) ([91b4f65](https://github.com/runfinch/finch-core/commit/91b4f65235ec2ef7e09db17acdeadb7eaf5e652f))
* add exectuable permission on docker-credential-osxkeychain ([#814](https://github.com/runfinch/finch-core/issues/814)) ([fdc2416](https://github.com/runfinch/finch-core/commit/fdc241651f01f6b58efeba22f26c652bf6d9332b))
* add timestep stamp to generating rootfs ([#130](https://github.com/runfinch/finch-core/issues/130)) ([2fc49cd](https://github.com/runfinch/finch-core/commit/2fc49cd7451e3825a823417f87fff9a6a71a0d02))
* apply lima patch ([#687](https://github.com/runfinch/finch-core/issues/687)) ([701ebea](https://github.com/runfinch/finch-core/commit/701ebea541562ada46346b1c08fbbe89d0c07755))
* build rootfs workflow for S3 upload ([#344](https://github.com/runfinch/finch-core/issues/344)) ([d7e0600](https://github.com/runfinch/finch-core/commit/d7e060055b10ba47807ca278c207f4ef3efdec6c))
* build rootfs workflow not uploading the artifacts to S3 ([#345](https://github.com/runfinch/finch-core/issues/345)) ([19274d9](https://github.com/runfinch/finch-core/commit/19274d91ed7e2982371bde9ceea7357568326f45))
* build script incorrect path ([#426](https://github.com/runfinch/finch-core/issues/426)) ([5ab4908](https://github.com/runfinch/finch-core/commit/5ab4908db325dca6557ab7971ad9f81a66155f6f))
* Change rootfs compression to gzip ([#142](https://github.com/runfinch/finch-core/issues/142)) ([3353d02](https://github.com/runfinch/finch-core/commit/3353d029bebcd6af38d3a6a549350eeca633691a))
* **ci:** fix linux dependencies workflow permissions ([#783](https://github.com/runfinch/finch-core/issues/783)) ([648f650](https://github.com/runfinch/finch-core/commit/648f65070a700830d51d2f107c996214ef642a0f))
* **ci:** fix permission of submodulesync workflow ([#792](https://github.com/runfinch/finch-core/issues/792)) ([273eb63](https://github.com/runfinch/finch-core/commit/273eb638e12e1862309c63b4529fcdf6e3e333c7))
* **ci:** Fix Update Ubutu Deps Workflow ([#764](https://github.com/runfinch/finch-core/issues/764)) ([07a543a](https://github.com/runfinch/finch-core/commit/07a543a7ab70508f57eb867beedcc127064a9825))
* clean make target ([#497](https://github.com/runfinch/finch-core/issues/497)) ([0841b5b](https://github.com/runfinch/finch-core/commit/0841b5bdc7947b48c43b97fcedd7161284cfb649))
* codesign make target was removed ([#427](https://github.com/runfinch/finch-core/issues/427)) ([99515a8](https://github.com/runfinch/finch-core/commit/99515a8d73262c4e2090964d58f3882661052be1))
* container runtime full archive upstream update ([#508](https://github.com/runfinch/finch-core/issues/508)) ([69b5a96](https://github.com/runfinch/finch-core/commit/69b5a960c7a8612cf3d26b275dbc881f17681d9d))
* docker file to run update for builds ([#367](https://github.com/runfinch/finch-core/issues/367)) ([b3a0826](https://github.com/runfinch/finch-core/commit/b3a0826b617f4c3bb9b92c5ad13c7d423db8798f))
* e2e tests ([#143](https://github.com/runfinch/finch-core/issues/143)) ([0ab8035](https://github.com/runfinch/finch-core/commit/0ab8035a44b2cd99c7668a0cf8739f848153d07b))
* lima dependencies on macOS ([#337](https://github.com/runfinch/finch-core/issues/337)) ([91c52d7](https://github.com/runfinch/finch-core/commit/91c52d70a32789143103070d65b87cb1c59f05e5))
* make install.dependencies on Windows ([#340](https://github.com/runfinch/finch-core/issues/340)) ([fd03c02](https://github.com/runfinch/finch-core/commit/fd03c02b85908b89edda6cad8334e311c3cca115))
* properly checkout lima tags and pin all actions ([#248](https://github.com/runfinch/finch-core/issues/248)) ([ed994e1](https://github.com/runfinch/finch-core/commit/ed994e1ad3f73d5db38a82814d7d768dd1db5ad2))
* properly checkout submodule tags ([#250](https://github.com/runfinch/finch-core/issues/250)) ([ad0fd8d](https://github.com/runfinch/finch-core/commit/ad0fd8d5aa411170fdad74e8ea7e3330762b1724))
* qemu and build issues ([#662](https://github.com/runfinch/finch-core/issues/662)) ([52b68fe](https://github.com/runfinch/finch-core/commit/52b68feb6b619597b8b3f0177eee517477f5e2a0))
* quote recursive calls to make ([#133](https://github.com/runfinch/finch-core/issues/133)) ([1b7aeb2](https://github.com/runfinch/finch-core/commit/1b7aeb2a8e168db640c89dc8dbcd1642efba501a))
* Revert qemu version to 8.x ([#723](https://github.com/runfinch/finch-core/issues/723)) ([386cb47](https://github.com/runfinch/finch-core/commit/386cb475158afc3bb73441b7b468015272f0520b))
* revert to finch-daemon 0.17.2 ([#655](https://github.com/runfinch/finch-core/issues/655)) ([a941e39](https://github.com/runfinch/finch-core/commit/a941e39d970d12f50428615ffa04bf0d3f0dffc9))
* root path for symlinks ([#702](https://github.com/runfinch/finch-core/issues/702)) ([81d707b](https://github.com/runfinch/finch-core/commit/81d707b28b1eb5c064e3ce823a840e03f3edc4ad))
* setup local registry before trying to run tests ([#284](https://github.com/runfinch/finch-core/issues/284)) ([180e3bf](https://github.com/runfinch/finch-core/commit/180e3bfc13fcb17227db634b07c149c991fc5256))
* setup-go in CI to resolve cache warnings ([#120](https://github.com/runfinch/finch-core/issues/120)) ([2ab5503](https://github.com/runfinch/finch-core/commit/2ab550381e8a06654138d8d60e210f18e806b69e))
* sha512 digest ([#443](https://github.com/runfinch/finch-core/issues/443)) ([8d6ecb7](https://github.com/runfinch/finch-core/commit/8d6ecb7f65cdad7487069cf35cf6d173c40461c1))
* typo in install script preventing MSYS Windows ([#341](https://github.com/runfinch/finch-core/issues/341)) ([772bd43](https://github.com/runfinch/finch-core/commit/772bd430d58b907239a92c09ed8d94ef7790a827))
* update Finch on Windows rootfs update workflow ([#343](https://github.com/runfinch/finch-core/issues/343)) ([394363b](https://github.com/runfinch/finch-core/commit/394363b70c094b3fba3d9856703ecc76d6626749))
* Update go mod to fix CVE-2024-45338 ([#464](https://github.com/runfinch/finch-core/issues/464)) ([ef0dde5](https://github.com/runfinch/finch-core/commit/ef0dde5214ded5674c37f4552787e7b86b5db6aa))
* use --recursive and correct pathing in update rootfs ([#132](https://github.com/runfinch/finch-core/issues/132)) ([0741eeb](https://github.com/runfinch/finch-core/commit/0741eeb9ea5a5fc7393b52ef5635ef69cf42af97))
* windows init file not found error ([#630](https://github.com/runfinch/finch-core/issues/630)) ([3541dbd](https://github.com/runfinch/finch-core/commit/3541dbdcedc1fd1f0ae04d4ca366af899af987f1))
* write artifact basename to configuration in update dependencies ([#347](https://github.com/runfinch/finch-core/issues/347)) ([1e33e28](https://github.com/runfinch/finch-core/commit/1e33e286fc7130711a3c8c299db806e97adba419))


### Performance Improvements

* add lima dependency pkgs to speed up VM boot ([#157](https://github.com/runfinch/finch-core/issues/157)) ([2f63058](https://github.com/runfinch/finch-core/commit/2f63058f4d0340eaa584216e189e16f915565c3f))


### Reverts

* "bump submodules ([#423](https://github.com/runfinch/finch-core/issues/423))" ([#432](https://github.com/runfinch/finch-core/issues/432)) ([64ab39c](https://github.com/runfinch/finch-core/commit/64ab39c235dc7c555f5b9f6c779a233f402aed43))
* revert "[create-pull-request] automated change ([#647](https://github.com/runfinch/finch-core/issues/647))" ([#659](https://github.com/runfinch/finch-core/issues/659)) ([bbfc2d4](https://github.com/runfinch/finch-core/commit/bbfc2d4bc9bd092e5bd1fb65cba64812748a1d24))

## [0.1.2](https://github.com/runfinch/finch-core/compare/v0.1.1...v0.1.2) (2023-01-26)


### Bug Fixes

* Add command to fetch remote tags ([#26](https://github.com/runfinch/finch-core/issues/26)) ([71787b5](https://github.com/runfinch/finch-core/commit/71787b5399db4881855ee660c2888eb1d10acd9d))
* properly set socket_vmnet version ([#38](https://github.com/runfinch/finch-core/issues/38)) ([a87d6ac](https://github.com/runfinch/finch-core/commit/a87d6ac36ca502bece808e5a5eb7355c84d027d1))

## [0.1.1](https://github.com/runfinch/finch-core/compare/v0.1.0...v0.1.1) (2022-12-06)


### Bug Fixes

* Change checksum format to support macos 10.15 build ([#16](https://github.com/runfinch/finch-core/issues/16)) ([33de22a](https://github.com/runfinch/finch-core/commit/33de22a9cfe1c847f0513711b813a8dd739df849))
