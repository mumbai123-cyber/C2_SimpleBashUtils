#define _POSIX_C_SOURCE 200809L

#include <getopt.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  int e_flag;
  int i_flag;
  int v_flag;
  int c_flag;
  int l_flag;
  int n_flag;
  int h_flag;
  int s_flag;
  int f_flag;
  int o_flag;
  char **patterns;
  int pattern_count;
  int pattern_capacity;
  char *pattern_file;
} grep_options_t;

void init_options(grep_options_t *opts) {
  opts->e_flag = 0;
  opts->i_flag = 0;
  opts->v_flag = 0;
  opts->c_flag = 0;
  opts->l_flag = 0;
  opts->n_flag = 0;
  opts->h_flag = 0;
  opts->s_flag = 0;
  opts->f_flag = 0;
  opts->o_flag = 0;
  opts->patterns = NULL;
  opts->pattern_count = 0;
  opts->pattern_capacity = 0;
  opts->pattern_file = NULL;
}

int ensure_capacity(grep_options_t *opts) {
  if (opts->pattern_count >= opts->pattern_capacity) {
    int new_capacity =
        opts->pattern_capacity == 0 ? 4 : opts->pattern_capacity * 2;
    char **new_patterns =
        realloc(opts->patterns, new_capacity * sizeof(char *));
    if (!new_patterns) {
      return -1;
    }
    opts->patterns = new_patterns;
    opts->pattern_capacity = new_capacity;
  }
  return 0;
}

int add_pattern(grep_options_t *opts, const char *pattern) {
  if (ensure_capacity(opts) != 0) {
    return -1;
  }

  opts->patterns[opts->pattern_count] = strdup(pattern);
  if (!opts->patterns[opts->pattern_count]) {
    return -1;
  }

  opts->pattern_count++;
  return 0;
}

int read_patterns_from_file(grep_options_t *opts, const char *filename) {
  FILE *file = fopen(filename, "r");
  if (!file) {
    return -1;
  }

  char *line = NULL;
  size_t len = 0;
  ssize_t read;

  while ((read = getline(&line, &len, file)) != -1) {
    if (read > 0 && line[read - 1] == '\n') {
      line[--read] = '\0';
    }
    if (read > 0 && line[read - 1] == '\r') {
      line[--read] = '\0';
    }

    if (add_pattern(opts, line) != 0) {
      free(line);
      fclose(file);
      return -1;
    }
  }

  free(line);
  fclose(file);
  return 0;
}

int match_line(const char *line, grep_options_t *opts) {
  regex_t regex_comp;
  int matched = 0;
  int cflags = opts->i_flag ? REG_ICASE : 0;

  for (int i = 0; i < opts->pattern_count; i++) {
    int ret = regcomp(&regex_comp, opts->patterns[i],
                      REG_EXTENDED | REG_NEWLINE | cflags);
    if (ret == 0) {
      if (regexec(&regex_comp, line, 0, NULL, 0) == 0) {
        matched = 1;
        regfree(&regex_comp);
        break;
      }
      regfree(&regex_comp);
    }
  }

  return opts->v_flag ? !matched : matched;
}

void print_matching_part(const char *line, const char *filename, int line_num,
                         grep_options_t *opts, int multiple_files) {
  regex_t regex_comp;
  regmatch_t pmatch[1];
  int cflags = opts->i_flag ? REG_ICASE : 0;

  for (int i = 0; i < opts->pattern_count; i++) {
    int ret = regcomp(&regex_comp, opts->patterns[i],
                      REG_EXTENDED | REG_NEWLINE | cflags);
    if (ret == 0) {
      const char *search_start = line;
      while (1) {
        if (regexec(&regex_comp, search_start, 1, pmatch, 0) == 0 &&
            pmatch[0].rm_so != -1) {
          if (filename && !opts->h_flag && multiple_files) {
            printf("%s:", filename);
          }
          if (opts->n_flag) {
            printf("%d:", line_num);
          }
          printf("%.*s\n", (int)(pmatch[0].rm_eo - pmatch[0].rm_so),
                 search_start + pmatch[0].rm_so);

          if (pmatch[0].rm_eo == 0) {
            search_start++;
          } else {
            search_start += pmatch[0].rm_eo;
          }
        } else {
          break;
        }
      }
      regfree(&regex_comp);
    }
  }
}

int process_file(const char *filename, grep_options_t *opts,
                 int multiple_files) {
  FILE *file = stdin;
  if (filename != NULL) {
    file = fopen(filename, "r");
    if (!file) {
      if (!opts->s_flag) {
        fprintf(stderr, "s21_grep: %s: No such file or directory\n", filename);
      }
      return -1;
    }
  }

  char *line = NULL;
  size_t len = 0;
  ssize_t read;
  int line_num = 0;
  int matches_found = 0;
  int file_has_match = 0;

  while ((read = getline(&line, &len, file)) != -1) {
    line_num++;

    if (read > 0 && line[read - 1] == '\n') {
      line[--read] = '\0';
    }
    if (read > 0 && line[read - 1] == '\r') {
      line[--read] = '\0';
    }

    int is_match = match_line(line, opts);

    if (is_match) {
      matches_found++;
      file_has_match = 1;

      if (opts->l_flag) {
      } else if (opts->c_flag) {
      } else if (opts->o_flag) {
        print_matching_part(line, filename, line_num, opts, multiple_files);
      } else {
        if (filename && !opts->h_flag && multiple_files) {
          printf("%s:", filename);
        }
        if (opts->n_flag) {
          printf("%d:", line_num);
        }
        printf("%s\n", line);
      }
    }
  }

  free(line);
  if (filename != NULL) {
    fclose(file);
  }

  if (opts->c_flag && !opts->l_flag) {
    if (filename && !opts->h_flag && multiple_files) {
      printf("%s:", filename);
    }
    printf("%d\n", matches_found);
  }

  if (opts->l_flag && file_has_match) {
    if (filename) {
      printf("%s\n", filename);
    } else {
      printf("(standard input)\n");
    }
  }

  return matches_found > 0 ? 1 : 0;
}

void free_options(grep_options_t *opts) {
  if (opts->patterns) {
    for (int i = 0; i < opts->pattern_count; i++) {
      free(opts->patterns[i]);
    }
    free(opts->patterns);
  }
  free(opts->pattern_file);
}

int main(int argc, char *argv[]) {
  grep_options_t opts;
  init_options(&opts);

  int unknown_flag_seen = 0;

  int opt;
  while ((opt = getopt(argc, argv, ":e:ivclnhsof:")) != -1) {
    switch (opt) {
      case 'e':
        if (add_pattern(&opts, optarg) != 0) {
          fprintf(stderr, "Error adding pattern\n");
          free_options(&opts);
          return 1;
        }
        opts.e_flag = 1;
        break;
      case 'i':
        opts.i_flag = 1;
        break;
      case 'v':
        opts.v_flag = 1;
        break;
      case 'c':
        opts.c_flag = 1;
        break;
      case 'l':
        opts.l_flag = 1;
        break;
      case 'n':
        opts.n_flag = 1;
        break;
      case 'h':
        opts.h_flag = 1;
        break;
      case 's':
        opts.s_flag = 1;
        break;
      case 'o':
        opts.o_flag = 1;
        break;
      case 'f':
        opts.f_flag = 1;
        opts.pattern_file = strdup(optarg);
        if (!opts.pattern_file) {
          fprintf(stderr, "Error allocating memory\n");
          free_options(&opts);
          return 1;
        }
        break;
      case '?':
        // игнорируем неизвестный флаг
        unknown_flag_seen = 1;
        break;
    }
  }

  if (!unknown_flag_seen && !opts.e_flag && !opts.f_flag && optind < argc) {
    if (add_pattern(&opts, argv[optind]) != 0) {
      fprintf(stderr, "Error adding pattern\n");
      free_options(&opts);
      return 1;
    }
    optind++;
  }

  if (opts.f_flag && opts.pattern_file) {
    if (read_patterns_from_file(&opts, opts.pattern_file) != 0) {
      fprintf(stderr, "s21_grep: %s: No such file or directory\n",
              opts.pattern_file);
      free_options(&opts);
      return 1;
    }
  }

  if (opts.pattern_count == 0) {
    if (opts.f_flag && opts.pattern_file) {
      free_options(&opts);
      return 0;
    } else {
      fprintf(stderr, "No pattern specified\n");
      free_options(&opts);
      return 1;
    }
  }

  int file_count = argc - optind;

  if (file_count == 0) {
    int result = process_file(NULL, &opts, 0);
    free_options(&opts);
    return result > 0 ? 0 : 1;
  }

  int any_matches = 0;

  for (int i = optind; i < argc; i++) {
    int file_result = process_file(argv[i], &opts, file_count > 1);
    if (file_result > 0) {
      any_matches = 1;
    }
  }

  free_options(&opts);

  return any_matches ? 0 : 1;
}