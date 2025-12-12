-- Part 2: Процедуры изменения данных и триггеры
-- Скрипт содержит процедуры для добавления P2P проверок, Verter проверок и триггеры

\c info21;

-- ============================================================================
-- Процедура 1: Добавление P2P проверки
-- ============================================================================
-- Добавляет новую запись P2P проверки
-- Если это начало проверки (Start), создает новую запись в Checks
-- Параметры:
--   - checked_peer: никнейм проверяемого студента
--   - checking_peer: никнейм проверяющего студента
--   - task_name: название задания
--   - check_state: статус проверки (Start/Success/Failure)
--   - check_time: время проверки

CREATE OR REPLACE PROCEDURE add_p2p_check(
    checked_peer VARCHAR,
    checking_peer VARCHAR, 
    task_name VARCHAR,
    check_state check_status,
    check_time TIME
)
LANGUAGE plpgsql
AS $$
DECLARE
    check_id BIGINT;  -- ID проверки (новой или существующей)
BEGIN
    -- Если состояние Start, создаем новую проверку
    IF check_state = 'Start' THEN
        -- Вставляем новую проверку в таблицу Checks
        INSERT INTO checks (peer, task, date)
        VALUES (checked_peer, task_name, CURRENT_DATE)
        RETURNING id INTO check_id;
        
        -- Вставляем запись P2P с начальным статусом
        INSERT INTO p2p ("check", checkingpeer, state, time)
        VALUES (check_id, checking_peer, check_state, check_time);
        
    ELSE
        -- Для Success/Failure ищем последнюю начатую проверку
        -- Находим проверку, которая была начата (Start), но еще не завершена
        SELECT c.id INTO check_id
        FROM checks c
        JOIN p2p p ON c.id = p."check"
        WHERE c.peer = checked_peer 
          AND c.task = task_name
          AND p.checkingpeer = checking_peer
          AND p.state = 'Start'
          AND NOT EXISTS (
              -- Проверяем, что нет записи Success или Failure для этой проверки
              SELECT 1 FROM p2p p2
              WHERE p2."check" = p."check"
                AND p2.state IN ('Success', 'Failure')
          )
        ORDER BY c.date DESC, p.time DESC
        LIMIT 1;
        
        -- Если проверка найдена, добавляем финальный статус
        IF check_id IS NOT NULL THEN
            INSERT INTO p2p ("check", checkingpeer, state, time)
            VALUES (check_id, checking_peer, check_state, check_time);
        ELSE
            -- Если не найдена начатая проверка, выбрасываем ошибку
            RAISE EXCEPTION 'Не найдена начатая P2P проверка для завершения';
        END IF;
    END IF;
END;
$$;

-- ============================================================================
-- Процедура 2: Добавление проверки Verter
-- ============================================================================
-- Добавляет запись автоматической проверки Verter
-- Verter проверяет код только после успешной P2P проверки
-- Параметры:
--   - checked_peer: никнейм проверяемого студента
--   - task_name: название задания
--   - verter_state: статус Verter проверки (Start/Success/Failure)
--   - verter_time: время проверки

CREATE OR REPLACE PROCEDURE add_verter_check(
    checked_peer VARCHAR,
    task_name VARCHAR,
    verter_state check_status,
    verter_time TIME
)
LANGUAGE plpgsql
AS $$
DECLARE
    check_id BIGINT;  -- ID проверки с успешной P2P
BEGIN
    -- Ищем последнюю проверку с успешной P2P
    -- Verter запускается только после успешного прохождения P2P
    SELECT c.id INTO check_id
    FROM checks c
    JOIN p2p p ON c.id = p."check"
    WHERE c.peer = checked_peer 
      AND c.task = task_name
      AND p.state = 'Success'  -- Только успешные P2P проверки
      AND NOT EXISTS (
          -- Проверяем, что Verter еще не запускался для этой проверки
          SELECT 1 FROM verter v
          WHERE v."check" = c.id
      )
    ORDER BY c.date DESC, p.time DESC
    LIMIT 1;
    
    -- Если найдена подходящая проверка, добавляем запись Verter
    IF check_id IS NOT NULL THEN
        INSERT INTO verter ("check", state, time)
        VALUES (check_id, verter_state, verter_time);
    ELSE
        -- Если не найдена успешная P2P проверка, выбрасываем ошибку
        RAISE EXCEPTION 'Не найдена успешная P2P проверка для Verter';
    END IF;
END;
$$;

-- ============================================================================
-- Триггер 1: Аудит изменений в таблице P2P
-- ============================================================================
-- Триггер отслеживает все изменения (INSERT/UPDATE/DELETE) в таблице P2P
-- Создает отдельную таблицу для логирования изменений

-- Создаем таблицу для хранения истории изменений P2P
CREATE TABLE IF NOT EXISTS p2p_audit (
    operation_type VARCHAR(10),     -- Тип операции: INSERT, UPDATE, DELETE
    operation_time TIMESTAMP,        -- Время операции
    old_data JSONB,                 -- Старые данные (для UPDATE/DELETE)
    new_data JSONB                  -- Новые данные (для INSERT/UPDATE)
);

-- Функция триггера для логирования изменений
CREATE OR REPLACE FUNCTION audit_p2p_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Для INSERT записываем только новые данные
    IF TG_OP = 'INSERT' THEN
        INSERT INTO p2p_audit (operation_type, operation_time, old_data, new_data)
        VALUES ('INSERT', NOW(), NULL, row_to_json(NEW)::jsonb);
        RETURN NEW;
        
    -- Для UPDATE записываем старые и новые данные
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO p2p_audit (operation_type, operation_time, old_data, new_data)
        VALUES ('UPDATE', NOW(), row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;
        
    -- Для DELETE записываем только старые данные
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO p2p_audit (operation_type, operation_time, old_data, new_data)
        VALUES ('DELETE', NOW(), row_to_json(OLD)::jsonb, NULL);
        RETURN OLD;
    END IF;
END;
$$;

-- Создаем триггер на таблице P2P
CREATE TRIGGER p2p_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON p2p
FOR EACH ROW EXECUTE FUNCTION audit_p2p_changes();

-- ============================================================================
-- Триггер 2: Валидация XP
-- ============================================================================
-- Триггер проверяет корректность добавляемого XP:
-- 1. XP не превышает максимально допустимое для задания
-- 2. Проверка должна быть успешной (P2P Success и, если есть, Verter Success)

CREATE OR REPLACE FUNCTION validate_xp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    max_xp INTEGER;          -- Максимальное XP для задания
    p2p_success BOOLEAN;     -- Флаг успешности P2P
    verter_exists BOOLEAN;   -- Флаг наличия Verter проверки
    verter_success BOOLEAN;  -- Флаг успешности Verter
    task_name VARCHAR;       -- Название задания
BEGIN
    -- Получаем название задания и максимальное XP
    SELECT t.title, t.maxxp INTO task_name, max_xp
    FROM checks c
    JOIN tasks t ON c.task = t.title
    WHERE c.id = NEW."check";
    
    -- Проверка 1: XP не должно превышать максимум
    IF NEW.xpamount > max_xp THEN
        RAISE EXCEPTION 'XP amount % exceeds maximum % for task %', 
            NEW.xpamount, max_xp, task_name;
    END IF;
    
    -- Проверка 2: P2P проверка должна быть успешной
    SELECT EXISTS(
        SELECT 1 FROM p2p 
        WHERE "check" = NEW."check" AND state = 'Success'
    ) INTO p2p_success;
    
    IF NOT p2p_success THEN
        RAISE EXCEPTION 'Cannot assign XP: P2P check not successful';
    END IF;
    
    -- Проверка 3: Если есть Verter, он тоже должен быть успешным
    SELECT EXISTS(
        SELECT 1 FROM verter WHERE "check" = NEW."check"
    ) INTO verter_exists;
    
    IF verter_exists THEN
        SELECT EXISTS(
            SELECT 1 FROM verter 
            WHERE "check" = NEW."check" AND state = 'Success'
        ) INTO verter_success;
        
        IF NOT verter_success THEN
            RAISE EXCEPTION 'Cannot assign XP: Verter check not successful';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Создаем триггер на таблице XP
-- Срабатывает перед вставкой (BEFORE INSERT)
CREATE TRIGGER xp_validation_trigger
BEFORE INSERT ON xp
FOR EACH ROW EXECUTE FUNCTION validate_xp();

-- ============================================================================
-- Триггер 3: Автоматическое начисление TransferredPoints
-- ============================================================================
-- При добавлении P2P проверки со статусом Start автоматически начисляется
-- один балл от проверяемого студента проверяющему

CREATE OR REPLACE FUNCTION update_transferred_points()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    checked_peer_name VARCHAR;  -- Имя проверяемого студента
BEGIN
    -- Триггер срабатывает только на начало проверки (Start)
    IF NEW.state = 'Start' THEN
        -- Получаем имя проверяемого студента из таблицы Checks
        SELECT peer INTO checked_peer_name
        FROM checks
        WHERE id = NEW."check";
        
        -- Проверяем, есть ли уже запись о передаче баллов между этими студентами
        IF EXISTS (
            SELECT 1 FROM transferredpoints
            WHERE checkingpeer = NEW.checkingpeer 
              AND checkedpeer = checked_peer_name
        ) THEN
            -- Если запись есть, увеличиваем количество баллов на 1
            UPDATE transferredpoints
            SET pointsamount = pointsamount + 1
            WHERE checkingpeer = NEW.checkingpeer 
              AND checkedpeer = checked_peer_name;
        ELSE
            -- Если записи нет, создаем новую с 1 баллом
            INSERT INTO transferredpoints (checkingpeer, checkedpeer, pointsamount)
            VALUES (NEW.checkingpeer, checked_peer_name, 1);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Создаем триггер на таблице P2P
-- Срабатывает после вставки (AFTER INSERT)
CREATE TRIGGER transferred_points_trigger
AFTER INSERT ON p2p
FOR EACH ROW EXECUTE FUNCTION update_transferred_points();
