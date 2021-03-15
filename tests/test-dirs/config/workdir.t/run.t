We need to set the MERLIN_LOG env variable for Merlin to log events prior
to the reading of the configuration.
  $ export MERLIN_LOG=-

% We check that:
%   workdir = $TESTCASE_ROOT/src
%   startdir = $TESTCASE_ROOT
%  (because the project is not built dune fails to find a configuration
%  and Merlin retries with an absolute path)
  $ ocamlmerlin single dump-configuration -log-section Mconfig_dot -filename src/main.ml < src/main.ml > /dev/null
  # 0.01 New_merlin - run
  No working directory specified
  # 0.01 Mconfig_dot - get_config
  Starting dune configuration provider from dir $TESTCASE_ROOT.
  # 0.01 Mconfig_dot - get_config
  Querying dune (inital cwd: $TESTCASE_ROOT) for file: src/main.ml.
  Workdir: $TESTCASE_ROOT/src
  # 0.01 Mconfig_dot - get_config
  Querying dune (inital cwd: $TESTCASE_ROOT) for file: $TESTCASE_ROOT/src/main.ml.
  Workdir: $TESTCASE_ROOT/src

% Same for dot-merlin-reader except here the workdir and the starting dir should
be the same ($TESTCASE_ROOT/src)
  $ touch .merlin
  $ ocamlmerlin single dump-configuration -log-section Mconfig_dot -filename src/main.ml < src/main.ml > /dev/null
  # 0.01 New_merlin - run
  No working directory specified
  # 0.01 Mconfig_dot - get_config
  Starting dot-merlin-reader configuration provider from dir $TESTCASE_ROOT.
  # 0.01 Mconfig_dot - get_config
  Querying dot-merlin-reader (inital cwd: $TESTCASE_ROOT) for file: $TESTCASE_ROOT/src/main.ml.
  Workdir: $TESTCASE_ROOT/src
