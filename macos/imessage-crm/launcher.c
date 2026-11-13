/*
 * imessage-crm-read: the launcher of the texts reader, and the only program that gets Full Disk Access.
 *
 * macOS checks Full Disk Access against the program launchd starts, and every process that program
 * starts inherits the grant. So this launcher runs one command, `python3 -I -S <script> read`, with a
 * fixed environment. It ignores its own arguments and environment. It refuses to run when code
 * running as Troy could change the script: the script and every folder above it must belong to root
 * and be writable by no one else. install-reader.sh builds it, signs it and copies it into place.
 *
 * It starts python as a child and waits, rather than replacing itself with python. A replaced process
 * would be python to macOS, which has no grant.
 */
#include <errno.h>
#include <pwd.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef LIBEXEC
#define LIBEXEC "/usr/local/libexec/imessage-crm"
#endif
#define SCRIPT LIBEXEC "/imessage-crm-sync.py"
#define PYTHON "/usr/bin/python3"

/* Whether path is a file (or a folder, when dir is set), not a link, owned by root and writable only by root. */
static int root_only(const char *path, int dir) {
  struct stat st;
  if (lstat(path, &st) != 0)
    return 0;
  if (dir ? !S_ISDIR(st.st_mode) : !S_ISREG(st.st_mode))
    return 0;
  return st.st_uid == 0 && (st.st_mode & (S_IWGRP | S_IWOTH)) == 0;
}

int main(void) {
  char path[] = SCRIPT;
  if (!root_only(path, 0)) {
    fprintf(stderr, "imessage-crm-read: %s must be a file that belongs to root and only root can change. "
                    "Run install-reader.sh.\n", SCRIPT);
    return 1;
  }
  /* Each folder above the script, up to /. */
  for (char *slash = strrchr(path, '/'); slash; slash = strrchr(path, '/')) {
    if (slash == path) {
      slash[1] = '\0';
    } else {
      *slash = '\0';
    }
    if (!root_only(path, 1)) {
      fprintf(stderr, "imessage-crm-read: %s must be a folder that belongs to root and only root can change.\n", path);
      return 1;
    }
    if (slash == path)
      break;
  }

  /* The environment comes from the user database, never from the caller. */
  struct passwd *pw = getpwuid(getuid());
  if (!pw) {
    fprintf(stderr, "imessage-crm-read: no user record for uid %d\n", (int)getuid());
    return 1;
  }
  char home[1024], user[256], logname[256];
  if (snprintf(home, sizeof home, "HOME=%s", pw->pw_dir) >= (int)sizeof home ||
      snprintf(user, sizeof user, "USER=%s", pw->pw_name) >= (int)sizeof user ||
      snprintf(logname, sizeof logname, "LOGNAME=%s", pw->pw_name) >= (int)sizeof logname) {
    fprintf(stderr, "imessage-crm-read: home folder or user name too long\n");
    return 1;
  }
  char *env[] = {home, user, logname, "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LC_CTYPE=UTF-8", NULL};
  /* -I: ignore PYTHON* variables, the user's site-packages and the current folder. -S: no site module. */
  char *argv[] = {PYTHON, "-I", "-S", SCRIPT, "read", NULL};

  pid_t pid;
  int err = posix_spawn(&pid, PYTHON, NULL, NULL, argv, env);
  if (err) {
    fprintf(stderr, "imessage-crm-read: can't start %s: %s\n", PYTHON, strerror(err));
    return 1;
  }
  int status;
  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR)
      return 1;
  }
  return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
