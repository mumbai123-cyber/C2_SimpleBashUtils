CC=gcc
CFLAGS=-std=c11 -Wall -Wextra -Werror -pedantic

s21_grep: grep.o
	$(CC) grep.o -o s21_grep

grep.o: grep.c
	$(CC) $(CFLAGS) -c grep.c

clean:
	rm -rf *.o s21_grep

rebuild: clean s21_grep

.PHONY: all clean rebuild