# Assignment 3- CI/CD with GitHub Actions

A small Bash application with automated linting, tests and a Docker
build/smoke-test, wired into a three-stage GitHub Actions pipeline.
Everything runs locally or on GitHub's runners; there is **no cloud deployment**.

## Repository layout

```
assignment-3/
├── README.md
├── app/app.sh                 # the application
├── scripts/
│   ├── lint.sh                # required files + bash -n (+ ShellCheck if installed)
│   └── build.sh               # docker build + smoke tests
├── tests/test.sh              # 13 automated tests
├── .github/workflows/ci.yml   # validate -> test -> docker
├── Dockerfile
├── compose.yaml
├── .dockerignore
└── grade.sh                   # local grading script
```

## Installation / setup

Requirements: Linux, Bash 4+, Git; Docker for the image build.

```bash
git clone <your-repository-url>
cd <repository>
chmod +x grade.sh app/*.sh scripts/*.sh tests/*.sh
```

## Usage

```bash
./app/app.sh system-info
./app/app.sh check-host <host>
./app/app.sh check-port <host> <port>
./app/app.sh help
```

| Exit code | Meaning                                                    |
|-----------|------------------------------------------------------------|
| 0         | success                                                    |
| 1         | check failed (host does not resolve / port closed)         |
| 2         | invalid command or input (missing host, bad port, unknown command) |

With Docker:

```bash
docker build -t devops-tool .
docker run --rm devops-tool help
docker run --rm devops-tool system-info
docker run --rm devops-tool check-port localhost 80
docker compose run --rm app help
```

## Testing

```bash
./scripts/lint.sh     # required files, bash -n, ShellCheck (optional)
./tests/test.sh       # 13 tests: help, system-info, invalid/no command,
                      # missing/invalid/valid host, missing/non-numeric/0/65536/negative port
./scripts/build.sh    # docker build + smoke tests (help, system-info, invalid command)
./grade.sh            # everything above, plus workflow and Git checks
```

## CI pipeline

`.github/workflows/ci.yml` runs on every **push** and **pull_request**:

```
validate  ──►  test  ──►  docker
(lint.sh)      (test.sh)  (build.sh)
```

`test` uses `needs: validate` and `docker` uses `needs: test`, so a later stage
never runs if an earlier one fails.

## CI failure demonstration

Steps used to show that the pipeline really stops on errors:

```bash
git checkout -b demo/ci-failure

# 1. introduce a deliberate syntax error (missing "fi" / stray "then")
echo 'if true; then' >> app/app.sh
git commit -am "test: introduce syntax error to demonstrate CI failure"
git push -u origin demo/ci-failure     # -> validate fails, test and docker are skipped

# 2. fix it
git revert HEAD --no-edit              # or edit the file and commit the fix
git push                               # -> validate, test and docker all pass

# 3. merge the fixed branch into main
git checkout main && git merge demo/ci-failure && git push
```

### Evidence

| Step                  | Result                | Run link                  |
|-----------------------|-----------------------|---------------------------|
| Broken commit pushed  | `validate` failed     | _paste GitHub Actions run URL_ |
| Fix pushed            | all three jobs passed | _paste GitHub Actions run URL_ |
| Final `main` workflow | all three jobs passed | _paste GitHub Actions run URL_ |

## Assumptions

- Docker and network access are only needed for the Docker job and for
  resolving external hostnames; `localhost` works offline.
- ShellCheck is optional locally (it is preinstalled on GitHub's Ubuntu runners).
- Exit code `1` is used for a failed check on valid input, `2` for invalid input.
- No secrets, tokens or machine-specific paths are committed.

## Git workflow

Developed on feature branches with small commits, then merged into `main`.
