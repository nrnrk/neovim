Contributing to Neovim
======================

Getting started
---------------

If you want to help but don't know where to start, here are some
low-risk/isolated tasks:

- [Merge a Vim patch].
- Try a [good first issue](../../labels/good-first-issue) or [complexity:low] issue.
- Fix bugs found by [Clang](#clang-scan-build), [PVS](#pvs-studio) or
  [Coverity](#coverity).

Reporting problems
------------------

- [Check the FAQ][wiki-faq].
- [Search existing issues][github-issues] (including closed!)
- Update Neovim to the latest version to see if your problem persists.
- Disable plugins incrementally, to narrow down the cause of the issue.
- When reporting a crash, [include a stacktrace](https://github.com/neovim/neovim/wiki/FAQ#backtrace-linux).
- Use [ASAN/UBSAN](#clang-sanitizers-asan-and-ubsan) to get detailed errors for segfaults and undefined behavior.
- [Bisect][git-bisect] to the cause of a regression, if you are able. This is _extremely_ helpful.
- Check `$NVIM_LOG_FILE`, if it exists.
- Include `cmake --system-information` for build-related issues.

Developer guidelines
--------------------

- Nvim contributors should read `:help dev`.
- External UI developers should read `:help dev-ui`.
- API client developers should read `:help dev-api-client`.
- Nvim developers are _strongly encouraged_ to install `ninja` for faster builds.
  ```
  sudo apt-get install ninja-build
  make distclean
  make  # Nvim build system uses ninja automatically, if available.
  ```
- [Improve documentation][wiki-contribute-help]

Pull requests (PRs)
---------------------

- To avoid duplicate work, create a draft pull request as soon as possible.
- Your PR must include **test coverage.** See [test/README.md][run-tests].
- Avoid cosmetic changes to unrelated files in the same commit.
- Use a [feature branch][git-feature-branch] instead of the master branch.
- Use a **rebase workflow** for small PRs.
  - After addressing review comments, it's fine to rebase and force-push.
- Use a **merge workflow** for big, high-risk PRs.
  - Merge `master` into your PR when there are conflicts or when master
    introduces breaking changes.
  - Use the `ri` git alias:
    ```
    [alias]
    ri = "!sh -c 't=\"${1:-master}\"; s=\"${2:-HEAD}\"; mb=\"$(git merge-base \"$t\" \"$s\")\"; if test \"x$mb\" = x ; then o=\"$t\"; else lm=\"$(git log -n1 --merges \"$t..$s\" --pretty=%H)\"; if test \"x$lm\" = x ; then o=\"$mb\"; else o=\"$lm\"; fi; fi; test $# -gt 0 && shift; test $# -gt 0 && shift; git rebase --interactive \"$o\" \"$@\"'"
    ```
    This avoids unnecessary rebases yet still allows you to combine related
    commits, separate monolithic commits, etc.
  - Do not edit commits that come before the merge commit.
- During a squash/fixup, use `exec make -C build unittest` between each
  pick/edit/reword.

### Stages: Draft and Ready for review

Pull requests have two stages: Draft and Ready for review.

1. [Create a Draft PR][pr-draft] while you are _not_ requesting feedback as
  you are still working on the PR.
2. [Change your PR to ready][pr-ready] when the PR is ready for review.

You can convert the state of your PR back to Draft (or Ready for review) at any
time. You can also skip the Draft stage if your PR is ready for review from the
beginning.

Do __not__ add any labels like `[RFC]` or `[WIP]` in the title to indicate the
state of your PR: this just adds noise. Non-Draft PRs are assumed to be open
for comments by default; if you want feedback from specific people, `@`-ping
them in a comment.

### Commit messages

Follow the [conventional commits guidelines][conventional_commits] to *make reviews easier* and to make
the VCS/git logs more valuable. The general structure of a commit message is as follows:

```
<type>([optional scope]): <description>

[optional body]

[optional footer(s)]
```

- Prefix the commit subject with one of the following _types_:
    - `build`: all changes related to the build system (involving scripts, configurations or tools) and package dependencies.
    - `ci`: all changes related to the continuous integration and deployment system - involving scripts, configurations or tools.
    - `docs`: all documentation changes. This includes both external documentation for users as well as internal documentation for developers.
    - `feat`: new abilities or functionality.
    - `fix`: a bug fix.
    - `perf`: performance improvements.
    - `refactor`: modification of the code base which neither adds a feature nor fixes a bug - such as removing redundant code, simplifying code, renaming variables, etc.
    - `revert`: revert previous commits.
    - `test`: all changes related to tests such as refactoring existing tests or adding new tests.
    - `vim-patch`: all patches from upstream Vim. The commit messages for patches has [slightly different rules](https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-Vim#pull-requests) as not to interfere with existing scripts.
    - `chore`: Lastly, if none of the types above fits you may use `chore` as the type.

- Append optional scope to _type_ such as `(lsp)`, `(treesitter)`, `(float)`, ...

- The _description_ shouldn't start with a capital letter or end in a period.

- Try to keep the first line under 72 characters.

- A blank line must separate the subject from the description.

- A breaking API change must be indicated by appending `!` after the type/scope and at the very beginning of the footer with a **BREAKING CHANGE**.

    Example:

    ```
    refactor(provider)!: drop support for Python 2

    BREAKING CHANGE: refactor to use Python 3 features since Python 2 is no longer supported.
    ```

- Use the _imperative voice_: "Fix bug" rather than "Fixed bug" or "Fixes bug."

### Automated builds (CI)

Each pull request must pass the automated builds on [Travis CI], [sourcehut]
and [AppVeyor].

- CI builds are compiled with [`-Werror`][gcc-warnings], so compiler warnings
  will fail the build.
- If any tests fail, the build will fail.
  See [test/README.md#running-tests][run-tests] to run tests locally.
  Passing locally doesn't guarantee passing the CI build, because of the
  different compilers and platforms tested against.
- CI runs [ASan] and other analyzers.
    - To run valgrind locally: `VALGRIND=1 make test`
    - To run Clang ASan/UBSan locally: `CC=clang make CMAKE_FLAGS="-DCLANG_ASAN_UBSAN=ON"`
- The [lint](#lint) build checks modified lines _and their immediate
  neighbors_, to encourage incrementally updating the legacy style to meet our
  [style](#style). (See [#3174][3174] for background.)
- CI for freebsd and openbsd runs on [sourcehut].
    - To get a backtrace on freebsd (after connecting via ssh):
      ```sh
      sudo pkg install tmux  # If you want tmux.
      lldb build/bin/nvim -c nvim.core

      # To get a full backtrace:
      #   1. Rebuild with debug info.
      rm -rf nvim.core build
      gmake CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_EXTRA_FLAGS="-DCI_BUILD=ON -DMIN_LOG_LEVEL=3" nvim
      #   2. Run the failing test to generate a new core file.
      TEST_FILE=test/functional/foo.lua gmake functionaltest
      lldb build/bin/nvim -c nvim.core
      ```

### Clang scan-build

View the [Clang report] to see potential bugs found by the Clang
[scan-build](https://clang-analyzer.llvm.org/scan-build.html) analyzer.

- Search the Neovim commit history to find examples:
  ```
  git log --oneline --no-merges --grep clang
  ```
- To verify a fix locally, run `scan-build` like this:
  ```
  rm -rf build/
  scan-build --use-analyzer=/usr/bin/clang make
  ```

### PVS-Studio

View the [PVS report](https://neovim.io/doc/reports/pvs/PVS-studio.html.d/) to
see potential bugs found by [PVS Studio](https://www.viva64.com/en/pvs-studio/).

- Use this format for commit messages (where `{id}` is the PVS warning-id)):
  ```
  PVS/V{id}: {description}
  ```
- Search the Neovim commit history to find examples:
  ```
  git log --oneline --no-merges --grep PVS
  ```
- Try `./scripts/pvscheck.sh` to run PVS locally.

### Coverity

[Coverity](https://scan.coverity.com/projects/neovim-neovim) runs against the
master build. To view the defects, just request access; you will be approved.

- Use this format for commit messages (where `{id}` is the CID (Coverity ID);
  ([example](https://github.com/neovim/neovim/pull/804))):
  ```
  coverity/{id}: {description}
  ```
- Search the Neovim commit history to find examples:
  ```
  git log --oneline --no-merges --grep coverity
  ```
  
### Clang sanitizers (ASAN and UBSAN)

  ASAN/UBSAN can be used to detect memory errors and other common forms of undefined behavior at runtime in debug builds.
  To build neovim with sanitizers enabled, use
  ```
  rm -rf build && CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=clang -DCLANG_ASAN_UBSAN=1" make
  ```
  When running neovim, use
  ```
  UBSAN_OPTIONS=print_stacktrace=1 ASAN_OPTIONS=log_path=/tmp/nvim_asan nvim args...
  ```
  If neovim exits unexpectedly, check `/tmp/nvim_asan.{PID}` (or your preferred `log_path`) for log files with error messages.
  

Coding
------

### Lint

You can run the linter locally by:

    make lint

The lint step downloads the [master error list] and excludes them, so only lint
errors related to the local changes are reported.

You can lint a single file (but this will _not_ exclude legacy errors):

    ./src/clint.py src/nvim/ops.c

### Style

The repo includes a `.clang-format` config file which (mostly) matches the
[style-guide].  You can use `clang-format` to format code with the `gq`
operator in Nvim:

    if !empty(findfile('.clang-format', ';'))
      setlocal formatprg=clang-format\ -style=file
    endif

### Navigate

- Use **[universal-ctags](https://github.com/universal-ctags/ctags).**
  ("Exuberant ctags", the typical `ctags` binary provided by your distro, is
  unmaintained and won't recognize many function signatures in Neovim source.)
- Explore the source code [on the web](https://sourcegraph.com/github.com/neovim/neovim).


Reviewing
---------

To help review pull requests, start with [this checklist][review-checklist].

Reviewing can be done on GitHub, but you may find it easier to do locally.
Using [`hub`][hub], you can create a new branch with the contents of a pull
request, e.g. [#1820][1820]:

    hub checkout https://github.com/neovim/neovim/pull/1820

Use [`git log -p master..FETCH_HEAD`][git-history-filtering] to list all
commits in the feature branch which aren't in the `master` branch; `-p`
shows each commit's diff. To show the whole surrounding function of a change
as context, use the `-W` argument as well.

[gcc-warnings]: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
[git-bisect]: http://git-scm.com/book/en/v2/Git-Tools-Debugging-with-Git
[git-feature-branch]: https://www.atlassian.com/git/tutorials/comparing-workflows
[git-history-filtering]: https://www.atlassian.com/git/tutorials/git-log/filtering-the-commit-history
[git-history-rewriting]: http://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
[git-rebasing]: http://git-scm.com/book/en/v2/Git-Branching-Rebasing
[github-issues]: https://github.com/neovim/neovim/issues
[1820]: https://github.com/neovim/neovim/pull/1820
[hub]: https://hub.github.com/
[conventional_commits]: https://www.conventionalcommits.org
[style-guide]: http://neovim.io/develop/style-guide.xml
[ASan]: http://clang.llvm.org/docs/AddressSanitizer.html
[run-tests]: https://github.com/neovim/neovim/blob/master/test/README.md#running-tests
[wiki-faq]: https://github.com/neovim/neovim/wiki/FAQ
[review-checklist]: https://github.com/neovim/neovim/wiki/Code-review-checklist
[3174]: https://github.com/neovim/neovim/issues/3174
[Travis CI]: https://travis-ci.org/neovim/neovim
[sourcehut]: https://builds.sr.ht/~jmk
[AppVeyor]: https://ci.appveyor.com/project/neovim/neovim
[Merge a Vim patch]: https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-Vim
[Clang report]: https://neovim.io/doc/reports/clang/
[complexity:low]: https://github.com/neovim/neovim/issues?q=is%3Aopen+is%3Aissue+label%3Acomplexity%3Alow
[master error list]: https://raw.githubusercontent.com/neovim/doc/gh-pages/reports/clint/errors.json
[wiki-contribute-help]: https://github.com/neovim/neovim/wiki/contribute-%3Ahelp
[pr-draft]: https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
[pr-ready]: https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/changing-the-stage-of-a-pull-request
