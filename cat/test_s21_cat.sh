#!/bin/bash

# =================== НАСТРОЙКИ ===================
S21_CAT="./s21_cat"  # путь к вашей утилите
CAT="cat"            # системная утилита cat
TEST_DIR="test_data"
LOG_FILE="test_results.log"
TEST_COUNT=0
FAIL_COUNT=0
PASS_COUNT=0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    local cat_output="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if diff -q <(echo "$s21_output") <(echo "$cat_output") > /dev/null; then
        log_result "${GREEN}✓ PASS${NC}: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        log_result "${RED}✗ FAIL${NC}: $test_name"
        log_result "Ваш вывод:"
        log_result "$s21_output"
        log_result "Ожидаемый вывод:"
        log_result "$cat_output"
        log_result "Различия:"
        diff -u <(echo "$s21_output") <(echo "$cat_output") | tee -a "$LOG_FILE"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

run_test() {
    local test_name="$1"
    local flags="$2"
    local file="$3"
    
    print_test_header "$test_name"
    
    local s21_output
    local cat_output
    
    if [[ "$flags" == "stdin" ]]; then
        # Тестирование stdin
        local input="$file"
        s21_output=$(echo -e "$input" | $S21_CAT)
        cat_output=$(echo -e "$input" | $CAT)
    else
        # Тестирование с файлами
        s21_output=$($S21_CAT $flags "$file" 2>/dev/null)
        cat_output=$($CAT $flags "$file" 2>/dev/null)
    fi
    
    compare_outputs "$test_name" "$s21_output" "$cat_output"
}

# =================== ПОДГОТОВКА ТЕСТОВЫХ ДАННЫХ ===================

mkdir -p "$TEST_DIR"

# Создаем тестовые файлы
cat > "$TEST_DIR/file1.txt" << EOF
Line 1
Line 2
Line 3
EOF

cat > "$TEST_DIR/file2.txt" << EOF
First line
Second line
    
Third line after empty lines
    
    
Multiple empty lines
EOF

cat > "$TEST_DIR/file3.txt" << EOF



Only empty lines at start

    
Mixed empty lines

EOF

cat > "$TEST_DIR/file4.txt" << EOF
Tab here:	tab character
Control characters:
Special: $
New line test
EOF

cat > "$TEST_DIR/file5.txt" << EOF
Single line file
EOF

# Бинарный файл
printf '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f' > "$TEST_DIR/binary.bin"

# =================== ЗАПУСК ТЕСТОВ ===================

echo "Запуск интеграционных тестов для s21_cat" > "$LOG_FILE"
echo "Дата: $(date)" >> "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# =================== ТЕСТЫ БЕЗ ФЛАГОВ ===================

print_test_header "БЕЗ ФЛАГОВ"

# Один файл
run_test "Один файл" "" "$TEST_DIR/file1.txt"

# Несколько файлов
run_test "Несколько файлов" "" "$TEST_DIR/file1.txt $TEST_DIR/file2.txt"

# Стандартный ввод
run_test "Стандартный ввод" "stdin" "Hello from stdin\nSecond line"

# Файл с пустыми строками
run_test "Файл с пустыми строками" "" "$TEST_DIR/file3.txt"

# =================== ТЕСТЫ С ФЛАГОМ -b (--number-nonblank) ===================

print_test_header "ФЛАГ -b (--number-nonblank)"

# Тест с одним файлом
run_test "-b с обычным файлом" "-b" "$TEST_DIR/file2.txt"

# Тест с несколькими файлами
run_test "-b с несколькими файлами" "-b" "$TEST_DIR/file1.txt $TEST_DIR/file2.txt"

# Тест с файлом без пустых строк
run_test "-b без пустых строк" "-b" "$TEST_DIR/file5.txt"

# Тест с пустым файлом
run_test "-b с пустым файлом" "-b" "$TEST_DIR/empty.txt" 2>/dev/null || true

# Длинная опция
run_test "--number-nonblank" "--number-nonblank" "$TEST_DIR/file2.txt"

# =================== ТЕСТЫ С ФЛАГОМ -e (эквивалент -vE) ===================

print_test_header "ФЛАГ -e (эквивалент -vE)"

run_test "-e с обычным файлом" "-e" "$TEST_DIR/file4.txt"
run_test "-e с несколькими файлами" "-e" "$TEST_DIR/file1.txt $TEST_DIR/file4.txt"

# =================== ТЕСТЫ С ФЛАГОМ -E (--show-ends) ===================

print_test_header "ФЛАГ -E (--show-ends)"

run_test "-E с обычным файлом" "-E" "$TEST_DIR/file1.txt"
run_test "-E с пустыми строками" "-E" "$TEST_DIR/file3.txt"
run_test "--show-ends" "--show-ends" "$TEST_DIR/file2.txt"

# =================== ТЕСТЫ С ФЛАГОМ -n (--number) ===================

print_test_header "ФЛАГ -n (--number)"

run_test "-n с обычным файлом" "-n" "$TEST_DIR/file2.txt"
run_test "-n с пустым файлом" "-n" "$TEST_DIR/empty.txt" 2>/dev/null || true
run_test "-n с несколькими файлами" "-n" "$TEST_DIR/file1.txt $TEST_DIR/file3.txt"
run_test "--number" "--number" "$TEST_DIR/file2.txt"

# =================== ТЕСТЫ С ФЛАГОМ -s (--squeeze-blank) ===================

print_test_header "ФЛАГ -s (--squeeze-blank)"

run_test "-s с множественными пустыми строками" "-s" "$TEST_DIR/file3.txt"
run_test "-s с обычным файлом" "-s" "$TEST_DIR/file2.txt"
run_test "--squeeze-blank" "--squeeze-blank" "$TEST_DIR/file3.txt"

# =================== ТЕСТЫ С ФЛАГОМ -t (эквивалент -vT) ===================

print_test_header "ФЛАГ -t (эквивалент -vT)"

run_test "-t с табами" "-t" "$TEST_DIR/file4.txt"
run_test "-t с бинарными данными" "-t" "$TEST_DIR/binary.bin"

# =================== ТЕСТЫ С ФЛАГОМ -T (--show-tabs) ===================

print_test_header "ФЛАГ -T (--show-tabs)"

run_test "-T с табами" "-T" "$TEST_DIR/file4.txt"
run_test "-T без табов" "-T" "$TEST_DIR/file1.txt"
run_test "--show-tabs" "--show-tabs" "$TEST_DIR/file4.txt"

# =================== ТЕСТЫ С ФЛАГОМ -v (--show-nonprinting) ===================

print_test_header "ФЛАГ -v (--show-nonprinting)"

run_test "-v с control characters" "-v" "$TEST_DIR/file4.txt"
run_test "-v с бинарным файлом" "-v" "$TEST_DIR/binary.bin"
run_test "--show-nonprinting" "--show-nonprinting" "$TEST_DIR/file4.txt"

# =================== ТЕСТЫ С ФЛАГОМ --show-all (эквивалент -vET) ===================

print_test_header "ФЛАГ --show-all (эквивалент -vET)"

run_test "--show-all" "--show-all" "$TEST_DIR/file4.txt"

# =================== ТЕСТЫ КОМБИНАЦИЙ ФЛАГОВ ===================

print_test_header "КОМБИНАЦИИ ФЛАГОВ"

# Комбинация -b и -s
run_test "-b -s" "-b -s" "$TEST_DIR/file3.txt"

# Комбинация -n и -E
run_test "-n -E" "-n -E" "$TEST_DIR/file2.txt"

# Комбинация -s -n -E
run_test "-s -n -E" "-s -n -E" "$TEST_DIR/file3.txt"

# Комбинация -b и -n (должен превалировать -b)
run_test "-b -n (приоритет -b)" "-b -n" "$TEST_DIR/file2.txt"

# Комбинация -v -T
run_test "-v -T" "-v -T" "$TEST_DIR/file4.txt"

# Комбинация -e -T
run_test "-e -T" "-e -T" "$TEST_DIR/file4.txt"

# =================== СПЕЦИАЛЬНЫЕ ТЕСТЫ ===================

print_test_header "СПЕЦИАЛЬНЫЕ ТЕСТЫ"

# Тест с несуществующим файлом
echo "Тест с несуществующим файлом:"
$S21_CAT "$TEST_DIR/nonexistent.txt" 2>&1 | grep -q "Error" && echo -e "${GREEN}✓ PASS${NC}: Корректная обработка ошибки" || echo -e "${RED}✗ FAIL${NC}: Некорректная обработка ошибки"

# Тест с дефисом (stdin)
echo -e "Input from stdin\nSecond line" | $S21_CAT - "$TEST_DIR/file1.txt" > s21_output.txt
echo -e "Input from stdin\nSecond line" | $CAT - "$TEST_DIR/file1.txt" > cat_output.txt
compare_outputs "Дефис как stdin" "$(cat s21_output.txt)" "$(cat cat_output.txt)"

# Тест с двойным дефисом (окончание флагов)
$S21_CAT -- -file1.txt 2>/dev/null || true
$CAT -- -file1.txt 2>/dev/null || true

# =================== БИНАРНЫЕ ТЕСТЫ ===================

print_test_header "БИНАРНЫЕ ТЕСТЫ"

# Тест с бинарными данными
run_test "-v с бинарными данными" "-v" "$TEST_DIR/binary.bin"
run_test "-t с бинарными данными" "-t" "$TEST_DIR/binary.bin"
run_test "-e с бинарными данными" "-e" "$TEST_DIR/binary.bin"

# =================== ПРОВЕРКА ГРАНИЧНЫХ СЛУЧАЕВ ===================

print_test_header "ГРАНИЧНЫЕ СЛУЧАИ"

# Очень длинная строка
python3 -c "print('A' * 10000)" > "$TEST_DIR/longline.txt"
run_test "Очень длинная строка" "-n" "$TEST_DIR/longline.txt"

# Файл только с \n
echo -e "\n\n\n" > "$TEST_DIR/onlynewlines.txt"
run_test "Только новые строки" "-s" "$TEST_DIR/onlynewlines.txt"

# Файл без \n в конце
printf "No newline at end" > "$TEST_DIR/nonewline.txt"
run_test "Без новой строки в конце" "" "$TEST_DIR/nonewline.txt"

# =================== ФИНАЛЬНЫЙ ОТЧЕТ ===================

echo -e "\n${YELLOW}==========================================${NC}" | tee -a "$LOG_FILE"
echo -e "${YELLOW}ИТОГИ ТЕСТИРОВАНИЯ:${NC}" | tee -a "$LOG_FILE"
echo "Всего тестов: $TEST_COUNT" | tee -a "$LOG_FILE"
echo -e "${GREEN}Пройдено: $PASS_COUNT${NC}" | tee -a "$LOG_FILE"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}Провалено: 0${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}Провалено: $FAIL_COUNT${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}✗ НЕКОТОРЫЕ ТЕСТЫ ПРОВАЛЕНЫ${NC}" | tee -a "$LOG_FILE"
fi

echo "Подробный лог в файле: $LOG_FILE" | tee -a "$LOG_FILE"

# Очистка временных файлов
rm -rf "$TEST_DIR" s21_output.txt cat_output.txt 2>/dev/null

# Возвращаем код ошибки если есть проваленные тесты
exit $((FAIL_COUNT > 0))