SHELL := /bin/bash

# components repos
GODWOKEN_REPO := https://github.com/jjyr/godwoken.git
GODWOKEN_SCRIPTS_REPO := https://github.com/jjyr/godwoken-scripts.git
POLYJUICE_REPO := https://github.com/jjyr/godwoken-polyjuice.git
OMNI_LOCK_REPO := https://github.com/nervosnetwork/ckb-production-scripts

# components tags
GODWOKEN_REF := feat-omni-rollup-cell-lock
GODWOKEN_SCRIPTS_REF := compatibility-breaking-changes
POLYJUICE_REF := compatibility-breaking-changes
OMNI_LOCK_REF := rc_lock

define prepare_repo
	if [ -d "build/$(3)" ]; then\
		cd build/$(3);\
		git reset --hard;\
		git fetch --all;\
		git checkout $(2);\
		git submodule update --init --recursive --depth=1;\
	else\
		git clone --depth=1 --recursive $(1) -b $(2) build/$(3);\
	fi
endef

prepare-repos:
	mkdir -p build
	$(call prepare_repo,$(GODWOKEN_REPO),$(GODWOKEN_REF),godwoken)
	$(call prepare_repo,$(GODWOKEN_SCRIPTS_REPO),$(GODWOKEN_SCRIPTS_REF),godwoken-scripts)
	$(call prepare_repo,$(POLYJUICE_REPO),$(POLYJUICE_REF),godwoken-polyjuice)
	$(call prepare_repo,$(OMNI_LOCK_REPO),$(OMNI_LOCK_REF),ckb-production-scripts)

build-components: prepare-repos
	cd build/godwoken-polyjuice && make dist && cd -
	cd build/godwoken-scripts && cd c && make && cd .. && capsule build --release --debug-output && cd ../..
	cd build/ckb-production-scripts && make all-via-docker

build-push:
	make build-components
	@read -p "Please Enter New Image Tag: " VERSION ; \
	docker build . -t nervos/godwoken-prebuilds:$$VERSION ; \
	docker push nervos/godwoken-prebuilds:$$VERSION

test:
	make build-components
	docker build . -t nervos/godwoken-prebuilds:latest-test
	mkdir -p `pwd`/test-result/scripts
	mkdir -p `pwd`/test-result/bin 
	docker run -it -d --name dummy nervos/godwoken-prebuilds:latest-test 
	docker cp dummy:/scripts/. `pwd`/test-result/scripts
	docker cp dummy:/bin/godwoken `pwd`/test-result/bin
	docker cp dummy:/bin/gw-tools `pwd`/test-result/bin
	docker rm -f dummy
	make test-files

test-files:
	echo "start checking build result..."
# compare scripts files
	make test-scripts-files
	make test-polyjuice-files
# compare bin files
	cd `pwd`/test-result/bin && ./godwoken --version && ./gw-tools --version
	[ -e "test-result" ] && rm -rf test-result

test-scripts-files:
	source tool.sh && check_scripts_files_exists

test-polyjuice-files:
	source tool.sh && check_polyjuice_files_exists 
