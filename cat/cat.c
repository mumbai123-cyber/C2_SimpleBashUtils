#define _POSIX_C_SOURCE 200809L

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void print_file(char *name_file, char *flags);
void flags_analyzer(char *flags, int argc, char **argv, int *index);
void add_flags(char *flags, char flag);
void add_flag(char *flags, char flag);
void execut_flags(int c, int *prev, char *flags, int *index, bool *empty_line);

int main(int argc, char **argv) {
  if (argc < 2) {
    print_file("-", "");
    return 0;
  }

  char flags[7] = "\0";
  int index_end_flags = 0;
  flags_analyzer(flags, argc, argv, &index_end_flags);

  int start_index = index_end_flags + 1;
  if (start_index <= 1) start_index = 1;

  for (int i = start_index; i < argc; i++) {
    print_file(argv[i], flags);
  }

  return 0;
}

void print_file(char *name_file, char *flags) {
  FILE *file;
  if (strcmp(name_file, "-") == 0) {
    file = stdin;
  } else {
    file = fopen(name_file, "r");
    if (file == NULL) {
      fprintf(stderr, "Error file.\n");
      return;
    }
  }

  int index = 0;
  bool empty_line = 0;
  int c = fgetc(file), prev = '\n';
  while (c != EOF) {
    execut_flags(c, &prev, flags, &index, &empty_line);
    c = fgetc(file);
  }

  if (file != stdin) {
    fclose(file);
  }
}

void flags_analyzer(char *flags, int argc, char **argv, int *index) {
  for (int i = 1; i < argc; i++) {
    if (argv[i][0] != '-' || strcmp(argv[i], "--") == 0) {
      if (strcmp(argv[i], "--") == 0) *index = i;
      break;
    }
    if (strcmp(argv[i], "-") == 0) {
      break;
    }

    if (strncmp(argv[i], "--", 2) == 0) {
      if (strcmp(argv[i], "--number-nonblank") == 0) {
        add_flags(flags, 'b');
      } else if (strcmp(argv[i], "--show-ends") == 0) {
        add_flags(flags, 'E');
      } else if (strcmp(argv[i], "--number") == 0) {
        add_flags(flags, 'n');
      } else if (strcmp(argv[i], "--squeeze-blank") == 0) {
        add_flags(flags, 's');
      } else if (strcmp(argv[i], "--show-tabs") == 0) {
        add_flags(flags, 'T');
      } else if (strcmp(argv[i], "--show-nonprinting") == 0) {
        add_flags(flags, 'v');
      } else if (strcmp(argv[i], "--show-all") == 0) {
        add_flags(flags, 'e');
        add_flags(flags, 't');
      }
      *index = i;

    } else if (argv[i][0] == '-') {
      *index = i;
      for (size_t k = 1; k < strlen(argv[i]); k++) {
        add_flags(flags, argv[i][k]);
      }
    }
  }
}

struct s_flags_option {
  char flag;
  char *equivalent_flags;
};

void add_flags(char *flags, char flag) {
  struct s_flags_option flags_option[8] = {{'b', "b"},  {'E', "E"}, {'e', "Ev"},
                                           {'n', "n"},  {'s', "s"}, {'T', "T"},
                                           {'t', "Tv"}, {'v', "v"}};

  for (int i = 0; i < 8; i++) {
    if (flags_option[i].flag == flag) {
      for (size_t k = 0; k < strlen(flags_option[i].equivalent_flags); k++) {
        add_flag(flags, flags_option[i].equivalent_flags[k]);
      }

      return;
    }
  }
}

void add_flag(char *flags, char flag) {
  if (strchr(flags, flag) == NULL) {
    char temp[2];
    temp[0] = flag;
    temp[1] = '\0';
    strcat(flags, temp);
  }
}

void execut_flags(int c, int *prev, char *flags, int *index, bool *empty_line) {
  unsigned char uc = (unsigned char)c;

  if (!(strchr(flags, 's') != NULL && *prev == '\n' && c == '\n' &&
        *empty_line)) {
    if (*prev == '\n' && c == '\n')
      *empty_line = 1;
    else
      *empty_line = 0;

    if (((strchr(flags, 'n') != NULL && strchr(flags, 'b') == NULL) ||
         (strchr(flags, 'b') != NULL && c != '\n')) &&
        *prev == '\n') {
      *index += 1;
      printf("%6d\t", *index);
    }

    if (strchr(flags, 'E') != NULL && c == '\n') {
      printf("$");
    }

    if (strchr(flags, 'T') != NULL && c == '\t') {
      printf("^I");
      *prev = c;
      return;
    }

    if (strchr(flags, 'v') != NULL) {
      if (uc < 32 && c != '\n' && c != '\t') {
        printf("^%c", uc + 64);
        *prev = c;
        return;
      }
      if (uc == 127) {
        printf("^?");
        *prev = c;
        return;
      }
      if (uc >= 128 && uc <= 159) {
        printf("M-^%c", (uc - 128) + 64);
        *prev = c;
        return;
      }
    }

    fputc(c, stdout);
  }
  *prev = c;
}