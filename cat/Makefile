CC=gcc
CFLAGS=-std=c11 -Wall -Wextra -Werror -pedantic

s21_cat: cat.o
	$(CC) cat.o -o s21_cat

cat.o: cat.c
	$(CC) $(CFLAGS) -c cat.c

clean:
	rm -rf *.o s21_cat

rebuild: clean s21_cat

.PHONY: all clean rebuild