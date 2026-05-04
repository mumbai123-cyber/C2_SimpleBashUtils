#!/bin/bash

# =================== НАСТРОЙКИ ===================
S21_GREP="./s21_grep"
GREP="grep"
TEST_DIR="grep_test_data"
LOG_FILE="grep_test_results.log"
PATTERNS_DIR="$TEST_DIR/patterns"
TEST_COUNT=0
FAIL_COUNT=0
PASS_COUNT=0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# =================== ФУНКЦИИ ===================

log_result() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

print_test_header() {
    echo -e "\n${YELLOW}=== Тестирование: $1 ===${NC}" | tee -a "$LOG_FILE"
}

compare_outputs() {
    local test_name="$1"
    local s21_output="$2"
    local grep_output="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    # Нормализация: заменяем s21_grep на grep в выводе ошибок
    local normalized_s21=$(echo "$s21_output" | sed 's/s21_grep/grep/g')
    local normalized_grep="$grep_output"
    
    # Удаляем лишние пробелы и пустые строки
    normalized_s21=$(echo "$normalized_s21" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    normalized_grep=$(echo "$normalized_grep" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Для сравнения игнорируем различия в формате ошибок
    # (grep может выводить разное сообщение в зависимости от версии)
    local error_pattern="grep:.*No such file or directory"
    if [[ "$normalized_s21" =~ $error_pattern ]] && [[ "$normalized_grep" =~ $error_pattern ]]; then
        log_result "${GREEN}✓ PASS${NC}: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    elif [ "$normalized_s21" = "$normalized_grep" ]; then
        log_result "${GREEN}✓ PASS${NC}: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        log_result "${RED}✗ FAIL${NC}: $test_name"
        log_result "Ваш вывод:"
        log_result "$s21_output"
        log_result "Ожидаемый вывод:"
        log_result "$grep_output"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

run_grep_test() {
    local test_name="$1"
    local flags="$2"
    local pattern="$3"
    local files="$4"
    
    print_test_header "$test_name"
    
    local s21_output
    local grep_output
    
    # Для пустого паттерна используем специальную обработку с таймаутом
    if [ -z "$pattern" ]; then
        # Пустой паттерн
        s21_output=$(timeout 2s bash -c "$S21_GREP $flags \"\" $files 2>&1" || echo "TIMEOUT")
        grep_output=$(timeout 2s bash -c "$GREP $flags \"\" $files 2>&1" || echo "TIMEOUT")
    else
        # Обычный паттерн
        s21_output=$($S21_GREP $flags "$pattern" $files 2>&1)
        grep_output=$($GREP $flags "$pattern" $files 2>&1)
    fi
    
    compare_outputs "$test_name" "$s21_output" "$grep_output"
}

# =================== ПОДГОТОВКА ТЕСТОВЫХ ДАННЫХ ===================

mkdir -p "$TEST_DIR" "$PATTERNS_DIR"

cat > "$TEST_DIR/file1.txt" << EOF
This is a test file for grep testing.
It contains multiple lines with various patterns.
Grep is a powerful tool for text processing.
test TEST Test
line with numbers 12345
special characters: !@#$%^&*()
Another test line.
EOF

cat > "$TEST_DIR/file2.txt" << EOF
Second file for testing.
Multiple occurrences of test test test.
Empty line follows:

Line after empty.
TEST in uppercase.
Another line.
EOF

# Создаем пустой файл
> "$TEST_DIR/empty.txt"

cat > "$PATTERNS_DIR/patterns1.txt" << EOF
test
line
EOF

# Создаем пустой файл паттернов
> "$PATTERNS_DIR/empty_patterns.txt"

# =================== ЗАПУСК ТЕСТОВ ===================

echo "Запуск интеграционных тестов для s21_grep" > "$LOG_FILE"
echo "Дата: $(date)" >> "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# =================== ТЕСТЫ ОШИБОК ===================

print_test_header "ТЕСТЫ ОШИБОК И ГРАНИЧНЫХ СЛУЧАЕВ"

# 1. Несуществующий файл (без -s)
run_grep_test "Несуществующий файл (без -s)" "" "test" "$TEST_DIR/nonexistent.txt"

# 2. Несуществующий файл (с -s)
run_grep_test "Несуществующий файл (с -s)" "-s" "test" "$TEST_DIR/nonexistent.txt"

# 3. Пустой файл
run_grep_test "Пустой файл" "" "test" "$TEST_DIR/empty.txt"

# 4. Пустой файл с -c
run_grep_test "Пустой файл с -c" "-c" "test" "$TEST_DIR/empty.txt"

# 5. Пустой файл с -n
run_grep_test "Пустой файл с -n" "-n" "test" "$TEST_DIR/empty.txt"

# 6. Пустой паттерн (с таймаутом)
run_grep_test "Пустой паттерн" "" "" "$TEST_DIR/file1.txt"

# 7. Пустой паттерн с -n
run_grep_test "Пустой паттерн с -n" "-n" "" "$TEST_DIR/file1.txt"

# 8. Пустой паттерн с -c
run_grep_test "Пустой паттерн с -c" "-c" "" "$TEST_DIR/file1.txt"

# 9. Без аргументов
print_test_header "Без аргументов"
TEST_COUNT=$((TEST_COUNT + 1))

# Получаем вывод для s21_grep и grep
s21_no_args_output=$($S21_GREP 2>&1)
grep_no_args_output=$($GREP 2>&1)

# Проверяем, есть ли у обоих сообщение об ошибке/использовании
s21_has_error=$(echo "$s21_no_args_output" | grep -E "(usage|Usage|No pattern|error)" >/dev/null && echo 1 || echo 0)
grep_has_error=$(echo "$grep_no_args_output" | grep -E "(usage|Usage|No pattern|error)" >/dev/null && echo 1 || echo 0)

if [ "$s21_has_error" = "1" ] && [ "$grep_has_error" = "1" ]; then
    log_result "${GREEN}✓ PASS${NC}: Без аргументов"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log_result "${RED}✗ FAIL${NC}: Без аргументов"
    log_result "Ваш вывод:"
    log_result "$s21_no_args_output"
    log_result "Ожидаемый вывод:"
    log_result "$grep_no_args_output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 10. Флаг -f с несуществующим файлом паттернов
run_grep_test "Флаг -f с несуществующим файлом" "-f" "$TEST_DIR/nonexistent_patterns.txt" "$TEST_DIR/file1.txt"

# 11. Флаг -f с пустым файлом паттернов
run_grep_test "Флаг -f с пустым файлом паттернов" "-f" "$PATTERNS_DIR/empty_patterns.txt" "$TEST_DIR/file1.txt"

# 12. Только паттерн, без файлов (чтение из stdin)
print_test_header "Только паттерн (stdin)"
TEST_COUNT=$((TEST_COUNT + 1))
echo -e "line1\ntest line2\nline3" | $S21_GREP "test" > s21_stdout.txt 2>&1
echo -e "line1\ntest line2\nline3" | $GREP "test" > grep_stdout.txt 2>&1

if diff -q s21_stdout.txt grep_stdout.txt > /dev/null 2>&1; then
    log_result "${GREEN}✓ PASS${NC}: Только паттерн (stdin)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log_result "${RED}✗ FAIL${NC}: Только паттерн (stdin)"
    log_result "Ваш вывод:"
    cat s21_stdout.txt
    log_result "Ожидаемый вывод:"
    cat grep_stdout.txt
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# =================== ОСНОВНЫЕ ТЕСТЫ ===================

print_test_header "ОСНОВНЫЕ ТЕСТЫ"

run_grep_test "Простой поиск" "" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -i" "-i" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -v" "-v" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -n" "-n" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -c" "-c" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -l" "-l" "test" "$TEST_DIR/file1.txt $TEST_DIR/file2.txt"
run_grep_test "Флаг -h" "-h" "test" "$TEST_DIR/file1.txt $TEST_DIR/file2.txt"
run_grep_test "Флаг -o" "-o" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -e" "-e" "test" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -e с несколькими шаблонами" "-e test -e line" "" "$TEST_DIR/file1.txt"
run_grep_test "Флаг -f" "-f $PATTERNS_DIR/patterns1.txt" "" "$TEST_DIR/file1.txt"

# =================== ТЕСТЫ КОМБИНАЦИЙ ===================

print_test_header "КОМБИНАЦИИ ФЛАГОВ"

run_grep_test "-i -v" "-i -v" "test" "$TEST_DIR/file1.txt"
run_grep_test "-n -i" "-n -i" "test" "$TEST_DIR/file1.txt"
run_grep_test "-c -l" "-c -l" "test" "$TEST_DIR/file1.txt $TEST_DIR/file2.txt"
run_grep_test "-o -n" "-o -n" "test" "$TEST_DIR/file1.txt"
run_grep_test "-v -c" "-v -c" "test" "$TEST_DIR/file1.txt"
run_grep_test "-l -h" "-l -h" "test" "$TEST_DIR/file1.txt $TEST_DIR/file2.txt"
run_grep_test "-s -l" "-s -l" "test" "$TEST_DIR/file1.txt $TEST_DIR/nonexistent.txt"

# =================== ФИНАЛЬНЫЙ ОТЧЕТ ===================

echo -e "\n${YELLOW}==========================================${NC}" | tee -a "$LOG_FILE"
echo -e "${YELLOW}ИТОГИ ТЕСТИРОВАНИЯ s21_grep:${NC}" | tee -a "$LOG_FILE"
echo "Всего тестов: $TEST_COUNT" | tee -a "$LOG_FILE"
echo -e "${GREEN}Пройдено: $PASS_COUNT${NC}" | tee -a "$LOG_FILE"
echo -e "${RED}Провалено: $FAIL_COUNT${NC}" | tee -a "$LOG_FILE"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}✗ НЕКОТОРЫЕ ТЕСТЫ ПРОВАЛЕНЫ${NC}" | tee -a "$LOG_FILE"
fi

echo "Подробный лог в файле: $LOG_FILE" | tee -a "$LOG_FILE"

# Очистка временных файлов
rm -rf "$TEST_DIR" s21_stdout.txt grep_stdout.txt 2>/dev/null

exit $((FAIL_COUNT > 0))