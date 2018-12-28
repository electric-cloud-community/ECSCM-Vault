# Copyright (c) 2010 Electric Cloud, Inc.
# All rights reserved

SRCTOP = ..
include $(SRCTOP)/build/vars.mak

build: package
unittest:
systemtest: test-setup test-run
scmtest:
	$(MAKE) NTESTFILES="systemtest/Vault.ntest" RUNSCMTESTS=1 test-setup test-run

NTESTFILES ?= systemtest

test-setup:
	$(EC_PERL) ../ECSCM/systemtest/setup.pl $(TEST_SERVER) $(PLUGINS_ARTIFACTS)

test-run: systemtest-run

include $(SRCTOP)/build/rules.mak
