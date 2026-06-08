#!/bin/bash
# emacs -Q --batch -l ert.el -l cui-async1.el \
#   -l ./tests/cui-tests-async1.el -f ert-run-tests-batch-and-exit || exit 1
# Timers
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-timers.el \
   -l ./tests/cui-tests-timers.el -f ert-run-tests-batch-and-exit || exit 1
# block
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el \
   -l ./tests/cui-tests-block.el -f ert-run-tests-batch-and-exit || exit 1
# block-msgs
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el -l cui-block-tags.el \
   -l ./tests/cui-tests-msgs.el -f ert-run-tests-batch-and-exit || exit 1
# block-tags
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l ../emacs-org-links/org-links.el \
      -l cui-block.el -l cui-block-msgs.el -l cui-block-tags.el \
   -l ./tests/cui-tests-block-tags.el -f ert-run-tests-batch-and-exit || exit 1
# restapi
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el -l cui-block-tags.el \
      -l cui-timers.el -l cui-async1.el -l cui-restapi.el \
      -l ./tests/cui-tests-restapi.el -f ert-run-tests-batch-and-exit || exit 1
# optional
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-optional.el \
    -l ./tests/cui-tests-optional.el -f ert-run-tests-batch-and-exit || exit 1
# prompt
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el \
      -l cui-block-tags.el -l cui-timers.el -l cui-async1.el -l cui-restapi.el -l cui-prompt.el \
    -l ./tests/cui-tests-prompt.el -f ert-run-tests-batch-and-exit || exit 1
# cui
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el \
      -l cui-block-tags.el -l cui-timers.el -l cui-async1.el -l cui-restapi.el -l cui-prompt.el -l ../emacs-org-links/org-links.el -l cui.el \
    -l ./tests/cui-tests-cui.el -f ert-run-tests-batch-and-exit || exit 1
# integ
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el \
      -l cui-block-tags.el -l cui-timers.el -l cui-async1.el -l cui-restapi.el -l cui-prompt.el -l cui.el -l ./tests/cui-tests-block.el \
    -l ./tests/cui-tests-integ.el -f ert-run-tests-batch-and-exit || exit 1
# integllm
emacs -Q --batch --no-site-file -l ert.el -l cui-debug.el -l cui-block.el -l cui-block-msgs.el \
      -l cui-block-tags.el -l cui-timers.el -l cui-async1.el -l cui-restapi.el -l cui-prompt.el -l cui.el \
    -l ./tests/cui-tests-integllm.el -f ert-run-tests-batch-and-exit || exit 1
