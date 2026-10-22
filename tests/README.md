# Docker Autoheal Tests

`tests.sh` starts the stack in `docker-compose.yml` and watches Docker restart events for it:

- `should-keep-restarting` is unhealthy and labelled, it must be restarted twice;
- `shouldnt-restart-healthy` is healthy;
- `shouldnt-restart-no-label` is unhealthy but not labelled;
- `shouldnt-restart-opted-out` is labelled but opts out with `autoheal=false`.

Any restart of a `shouldnt-*` container, or fewer than two restarts within 120 seconds, fails the run.

## Run tests
```bash
./tests/tests.sh
```

## Run tests in CI
```bash
AUTOHEAL_CONTAINER_LABEL=autoheal-123456 ./tests/tests.sh autoheal-test-123456
```

A unique compose project name and label keep the run from touching other containers on the host.
