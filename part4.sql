-- Part 4: Работа с метаданными базы данных
-- Скрипт содержит процедуры для управления структурой БД и получения метаинформации

\c info21;

-- ============================================================================
-- Процедура 1: Удаление всех таблиц в текущей базе данных
-- ============================================================================
-- Процедура удаляет все таблицы, начинающиеся с 'table'
-- Используется для очистки базы данных от таблиц с определенным префиксом
-- Использует динамический SQL для генерации и выполнения DROP TABLE команд

CREATE OR REPLACE PROCEDURE drop_tables_by_prefix()
LANGUAGE plpgsql
AS $$
DECLARE
    table_record RECORD;  -- Запись для итерации по таблицам
    drop_query TEXT;      -- SQL запрос для удаления таблицы
BEGIN
    -- Цикл по всем таблицам в текущей схеме, начинающимся с 'table'
    FOR table_record IN 
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'  -- Только таблицы в схеме public
          AND tablename LIKE 'table%' -- Фильтр по префиксу
    LOOP
        -- Формируем запрос на удаление таблицы с CASCADE
        -- CASCADE удаляет зависимые объекты (внешние ключи, представления и т.д.)
        drop_query := 'DROP TABLE IF EXISTS ' || quote_ident(table_record.tablename) || ' CASCADE';
        
        -- Выполняем динамический SQL
        EXECUTE drop_query;
        
        -- Логируем удаление таблицы
        RAISE NOTICE 'Dropped table: %', table_record.tablename;
    END LOOP;
END;
$$;

-- ============================================================================
-- Процедура 2: Вывод списка скалярных функций с параметрами
-- ============================================================================
-- Процедура выводит список всех пользовательских скалярных SQL функций
-- Скалярные функции - функции, возвращающие одно значение (не таблицы)
-- Выводит: название функции, тип возвращаемого значения, список параметров

CREATE OR REPLACE PROCEDURE list_scalar_functions()
LANGUAGE plpgsql
AS $$
DECLARE
    func_record RECORD;  -- Запись для итерации по функциям
BEGIN
    -- Выводим заголовок
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Scalar SQL Functions';
    RAISE NOTICE '========================================';
    
    -- Цикл по всем скалярным функциям
    FOR func_record IN
        SELECT 
            p.proname AS function_name,                    -- Имя функции
            pg_catalog.pg_get_function_result(p.oid) AS return_type,  -- Возвращаемый тип
            pg_catalog.pg_get_function_arguments(p.oid) AS parameters -- Параметры
        FROM pg_catalog.pg_proc p
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'                         -- Только public схема
          AND p.prokind = 'f'                              -- Только функции (не процедуры)
          AND pg_catalog.pg_function_is_visible(p.oid)     -- Видимые функции
          -- Проверяем, что функция возвращает скалярное значение (не таблицу)
          AND p.prorettype NOT IN (
              SELECT oid FROM pg_type WHERE typtype = 'c'  -- Исключаем composite types
          )
          AND p.proretset = FALSE                          -- Не возвращает множество строк
        ORDER BY function_name
    LOOP
        -- Выводим информацию о функции
        RAISE NOTICE 'Function: %', func_record.function_name;
        RAISE NOTICE '  Return Type: %', func_record.return_type;
        RAISE NOTICE '  Parameters: %', COALESCE(func_record.parameters, 'none');
        RAISE NOTICE '----------------------------------------';
    END LOOP;
END;
$$;

-- ============================================================================
-- Процедура 3: Удаление всех DML триггеров
-- ============================================================================
-- DML триггеры - триггеры на INSERT, UPDATE, DELETE операции
-- Процедура удаляет все DML триггеры с вывода информации о каждом удалении
-- Сохраняет системные триггеры и DDL триггеры

CREATE OR REPLACE PROCEDURE drop_all_dml_triggers()
LANGUAGE plpgsql
AS $$
DECLARE
    trigger_record RECORD;  -- Запись для итерации по триггерам
    drop_query TEXT;        -- SQL запрос для удаления триггера
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Dropping DML Triggers';
    RAISE NOTICE '========================================';
    
    -- Цикл по всем триггерам в текущей схеме
    FOR trigger_record IN
        SELECT 
            t.tgname AS trigger_name,           -- Имя триггера
            c.relname AS table_name             -- Имя таблицы
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'              -- Только public схема
          AND NOT t.tgisinternal                -- Исключаем внутренние триггеры
          -- Проверяем, что это DML триггер (INSERT, UPDATE, DELETE)
          AND (t.tgtype & 1) > 0                -- INSERT trigger
           OR (t.tgtype & 2) > 0                -- DELETE trigger
           OR (t.tgtype & 4) > 0                -- UPDATE trigger
    LOOP
        -- Формируем запрос на удаление триггера
        drop_query := 'DROP TRIGGER IF EXISTS ' || 
                      quote_ident(trigger_record.trigger_name) || 
                      ' ON ' || 
                      quote_ident(trigger_record.table_name) ||
                      ' CASCADE';
        
        -- Выполняем удаление
        EXECUTE drop_query;
        
        -- Логируем удаление
        RAISE NOTICE 'Dropped trigger: % on table %', 
                     trigger_record.trigger_name, 
                     trigger_record.table_name;
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'All DML triggers dropped';
    RAISE NOTICE '========================================';
END;
$$;

-- ============================================================================
-- Процедура 4: Поиск объектов по строке в описании
-- ============================================================================
-- Процедура ищет все объекты базы данных, содержащие заданную строку
-- в названии или описании
-- Ищет среди: функций, процедур, таблиц, представлений, триггеров
-- Параметр: search_string - строка для поиска

CREATE OR REPLACE PROCEDURE search_objects_by_string(search_string VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    object_record RECORD;  -- Запись для итерации по объектам
    found_count INTEGER := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Searching for objects containing: "%"', search_string;
    RAISE NOTICE '========================================';
    
    -- Поиск среди функций и процедур
    RAISE NOTICE 'FUNCTIONS AND PROCEDURES:';
    FOR object_record IN
        SELECT 
            'Function/Procedure' AS object_type,
            p.proname AS object_name,
            obj_description(p.oid, 'pg_proc') AS description
        FROM pg_catalog.pg_proc p
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND (
              p.proname ILIKE '%' || search_string || '%'  -- Поиск в имени
              OR obj_description(p.oid, 'pg_proc') ILIKE '%' || search_string || '%'  -- Поиск в описании
          )
    LOOP
        found_count := found_count + 1;
        RAISE NOTICE '  Type: %', object_record.object_type;
        RAISE NOTICE '  Name: %', object_record.object_name;
        RAISE NOTICE '  Description: %', COALESCE(object_record.description, 'No description');
        RAISE NOTICE '  ----';
    END LOOP;
    
    -- Поиск среди таблиц
    RAISE NOTICE 'TABLES:';
    FOR object_record IN
        SELECT 
            'Table' AS object_type,
            c.relname AS object_name,
            obj_description(c.oid, 'pg_class') AS description
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind = 'r'  -- Только таблицы
          AND (
              c.relname ILIKE '%' || search_string || '%'
              OR obj_description(c.oid, 'pg_class') ILIKE '%' || search_string || '%'
          )
    LOOP
        found_count := found_count + 1;
        RAISE NOTICE '  Type: %', object_record.object_type;
        RAISE NOTICE '  Name: %', object_record.object_name;
        RAISE NOTICE '  Description: %', COALESCE(object_record.description, 'No description');
        RAISE NOTICE '  ----';
    END LOOP;
    
    -- Поиск среди представлений
    RAISE NOTICE 'VIEWS:';
    FOR object_record IN
        SELECT 
            'View' AS object_type,
            c.relname AS object_name,
            obj_description(c.oid, 'pg_class') AS description
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind = 'v'  -- Только представления
          AND (
              c.relname ILIKE '%' || search_string || '%'
              OR obj_description(c.oid, 'pg_class') ILIKE '%' || search_string || '%'
          )
    LOOP
        found_count := found_count + 1;
        RAISE NOTICE '  Type: %', object_record.object_type;
        RAISE NOTICE '  Name: %', object_record.object_name;
        RAISE NOTICE '  Description: %', COALESCE(object_record.description, 'No description');
        RAISE NOTICE '  ----';
    END LOOP;
    
    -- Поиск среди триггеров
    RAISE NOTICE 'TRIGGERS:';
    FOR object_record IN
        SELECT 
            'Trigger' AS object_type,
            t.tgname AS object_name,
            c.relname AS table_name
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND NOT t.tgisinternal
          AND t.tgname ILIKE '%' || search_string || '%'
    LOOP
        found_count := found_count + 1;
        RAISE NOTICE '  Type: %', object_record.object_type;
        RAISE NOTICE '  Name: %', object_record.object_name;
        RAISE NOTICE '  Table: %', object_record.table_name;
        RAISE NOTICE '  ----';
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total objects found: %', found_count;
    RAISE NOTICE '========================================';
END;
$$;

-- ============================================================================
-- Дополнительная процедура: Создание тестовых таблиц
-- ============================================================================
-- Вспомогательная процедура для тестирования процедуры удаления таблиц
-- Создает несколько тестовых таблиц с префиксом 'table'

CREATE OR REPLACE PROCEDURE create_test_tables()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Создаем тестовые таблицы
    CREATE TABLE IF NOT EXISTS table_test1 (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100)
    );
    
    CREATE TABLE IF NOT EXISTS table_test2 (
        id SERIAL PRIMARY KEY,
        value INTEGER
    );
    
    CREATE TABLE IF NOT EXISTS table_sample (
        id SERIAL PRIMARY KEY,
        data TEXT
    );
    
    RAISE NOTICE 'Test tables created: table_test1, table_test2, table_sample';
END;
$$;

-- ============================================================================
-- Дополнительная процедура: Получение статистики базы данных
-- ============================================================================
-- Выводит общую статистику по объектам в базе данных

CREATE OR REPLACE PROCEDURE get_database_statistics()
LANGUAGE plpgsql
AS $$
DECLARE
    table_count INTEGER;
    function_count INTEGER;
    procedure_count INTEGER;
    trigger_count INTEGER;
    view_count INTEGER;
BEGIN
    -- Считаем количество таблиц
    SELECT COUNT(*) INTO table_count
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r';
    
    -- Считаем функции
    SELECT COUNT(*) INTO function_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f';
    
    -- Считаем процедуры
    SELECT COUNT(*) INTO procedure_count
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'p';
    
    -- Считаем триггеры
    SELECT COUNT(*) INTO trigger_count
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'public' AND NOT t.tgisinternal;
    
    -- Считаем представления
    SELECT COUNT(*) INTO view_count
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'v';
    
    -- Выводим статистику
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Database Statistics (public schema)';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Tables: %', table_count;
    RAISE NOTICE 'Functions: %', function_count;
    RAISE NOTICE 'Procedures: %', procedure_count;
    RAISE NOTICE 'Triggers: %', trigger_count;
    RAISE NOTICE 'Views: %', view_count;
    RAISE NOTICE '========================================';
END;
$$;

-- ============================================================================
-- ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ ПРОЦЕДУР
-- ============================================================================

-- Раскомментируйте для тестирования:

-- -- Создать тестовые таблицы
-- CALL create_test_tables();

-- -- Получить статистику базы данных
-- CALL get_database_statistics();

-- -- Вывести все скалярные функции
-- CALL list_scalar_functions();

-- -- Удалить все таблицы с префиксом 'table'
-- CALL drop_tables_by_prefix();

-- -- Удалить все DML триггеры
-- CALL drop_all_dml_triggers();

-- -- Найти объекты, содержащие 'peer' в названии
-- CALL search_objects_by_string('peer');

-- -- Найти объекты, содержащие 'check' в названии
-- CALL search_objects_by_string('check');
