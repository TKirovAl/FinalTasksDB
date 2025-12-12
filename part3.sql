-- Part 3: Функции получения данных
-- Скрипт содержит функции для анализа и представления данных

\c info21;

-- ============================================================================
-- Функция 1: Читаемый формат TransferredPoints
-- ============================================================================
-- Возвращает таблицу переданных баллов в человекочитаемом формате
-- Показывает сколько каждый студент получил/отдал баллов другим
-- Возвращаемые колонки: Peer1, Peer2, PointsAmount
-- PointsAmount = (баллы от Peer1 к Peer2) - (баллы от Peer2 к Peer1)

CREATE OR REPLACE FUNCTION get_transferred_points_readable()
RETURNS TABLE (
    peer1 VARCHAR,
    peer2 VARCHAR,
    pointsamount INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    -- Объединяем пары студентов и вычисляем разницу баллов
    WITH points_pairs AS (
        SELECT 
            CASE WHEN t1.checkingpeer < t1.checkedpeer 
                 THEN t1.checkingpeer 
                 ELSE t1.checkedpeer END AS p1,
            CASE WHEN t1.checkingpeer < t1.checkedpeer 
                 THEN t1.checkedpeer 
                 ELSE t1.checkingpeer END AS p2,
            -- Вычисляем разницу: сколько первый отдал второму минус сколько второй отдал первому
            COALESCE((SELECT pointsamount FROM transferredpoints 
                      WHERE checkingpeer = CASE WHEN t1.checkingpeer < t1.checkedpeer 
                                                THEN t1.checkingpeer 
                                                ELSE t1.checkedpeer END
                        AND checkedpeer = CASE WHEN t1.checkingpeer < t1.checkedpeer 
                                              THEN t1.checkedpeer 
                                              ELSE t1.checkingpeer END), 0) -
            COALESCE((SELECT pointsamount FROM transferredpoints 
                      WHERE checkingpeer = CASE WHEN t1.checkingpeer < t1.checkedpeer 
                                                THEN t1.checkedpeer 
                                                ELSE t1.checkingpeer END
                        AND checkedpeer = CASE WHEN t1.checkingpeer < t1.checkedpeer 
                                              THEN t1.checkingpeer 
                                              ELSE t1.checkedpeer END), 0) AS points_diff
        FROM transferredpoints t1
    )
    SELECT DISTINCT p1, p2, points_diff
    FROM points_pairs
    ORDER BY p1, p2;
END;
$$;

-- ============================================================================
-- Функция 2: Таблица успешных проверок с XP
-- ============================================================================
-- Возвращает информацию о студентах, успешно выполнивших задания
-- Колонки: Peer (студент), Task (задание), XP (полученный опыт)
-- Включает только проверки, где есть запись в таблице XP

CREATE OR REPLACE FUNCTION get_successful_checks_with_xp()
RETURNS TABLE (
    peer VARCHAR,
    task VARCHAR,
    xp INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.peer,
        c.task,
        x.xpamount
    FROM checks c
    JOIN xp x ON c.id = x."check"
    -- Проверяем что есть успешная P2P
    WHERE EXISTS (
        SELECT 1 FROM p2p
        WHERE "check" = c.id AND state = 'Success'
    )
    -- Если есть Verter, он тоже должен быть успешным
    AND (NOT EXISTS (SELECT 1 FROM verter WHERE "check" = c.id)
         OR EXISTS (SELECT 1 FROM verter WHERE "check" = c.id AND state = 'Success'))
    ORDER BY c.peer, c.date;
END;
$$;

-- ============================================================================
-- Функция 3: Студенты, не покидавшие кампус весь день
-- ============================================================================
-- Находит студентов, которые провели весь указанный день в кампусе
-- Параметр: check_date - дата для проверки
-- Студент не покидал кампус, если после первого входа не было выхода

CREATE OR REPLACE FUNCTION get_peers_not_left_campus(check_date DATE)
RETURNS TABLE (peer VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT t.peer
    FROM timetracking t
    WHERE t.date = check_date
      -- Проверяем, что первая запись - вход (state = 1)
      AND (SELECT state FROM timetracking 
           WHERE peer = t.peer AND date = check_date 
           ORDER BY time LIMIT 1) = 1
      -- Проверяем, что последняя запись - не выход (т.е. студент все еще в кампусе)
      -- Или что после последнего выхода был еще вход
      AND NOT EXISTS (
          SELECT 1 FROM timetracking t2
          WHERE t2.peer = t.peer 
            AND t2.date = check_date
            AND t2.state = 2  -- Выход
            AND NOT EXISTS (
                -- Нет входа после этого выхода
                SELECT 1 FROM timetracking t3
                WHERE t3.peer = t.peer 
                  AND t3.date = check_date
                  AND t3.state = 1
                  AND t3.time > t2.time
            )
      )
    ORDER BY t.peer;
END;
$$;

-- ============================================================================
-- Функция 4: Изменение peer points для каждого студента
-- ============================================================================
-- Вычисляет изменение peer points (разницу полученных/отданных баллов)
-- Положительное значение = студент получил больше, чем отдал
-- Возвращает: Peer, PointsChange

CREATE OR REPLACE FUNCTION get_peer_points_change()
RETURNS TABLE (
    peer VARCHAR,
    pointschange INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH received_points AS (
        -- Баллы, полученные студентом (когда его проверяли)
        SELECT checkedpeer AS peer, SUM(pointsamount) AS received
        FROM transferredpoints
        GROUP BY checkedpeer
    ),
    given_points AS (
        -- Баллы, отданные студентом (когда он проверял)
        SELECT checkingpeer AS peer, SUM(pointsamount) AS given
        FROM transferredpoints
        GROUP BY checkingpeer
    )
    SELECT 
        COALESCE(r.peer, g.peer) AS peer,
        COALESCE(r.received, 0) - COALESCE(g.given, 0) AS pointschange
    FROM received_points r
    FULL OUTER JOIN given_points g ON r.peer = g.peer
    ORDER BY pointschange DESC;
END;
$$;

-- ============================================================================
-- Функция 5: Изменение peer points по функции из задачи 1
-- ============================================================================
-- То же самое, но используя функцию get_transferred_points_readable
-- Демонстрирует альтернативный подход к вычислению через readable формат

CREATE OR REPLACE FUNCTION get_peer_points_change_v2()
RETURNS TABLE (
    peer VARCHAR,
    pointschange INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH readable_points AS (
        SELECT * FROM get_transferred_points_readable()
    )
    SELECT 
        p.nickname,
        -- Суммируем баллы где студент - peer1 (положительные)
        COALESCE((SELECT SUM(rp.pointsamount) FROM readable_points rp 
                  WHERE rp.peer1 = p.nickname), 0) -
        -- Вычитаем баллы где студент - peer2 (отрицательные)
        COALESCE((SELECT SUM(rp.pointsamount) FROM readable_points rp 
                  WHERE rp.peer2 = p.nickname), 0) AS pointschange
    FROM peers p
    ORDER BY pointschange DESC;
END;
$$;

-- ============================================================================
-- Функция 6: Самое проверяемое задание за день
-- ============================================================================
-- Для каждого дня определяет задание с наибольшим количеством проверок
-- Возвращает: Day, Task

CREATE OR REPLACE FUNCTION get_most_checked_task_per_day()
RETURNS TABLE (
    day DATE,
    task VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH task_counts AS (
        -- Считаем количество проверок каждого задания по дням
        SELECT 
            c.date,
            c.task,
            COUNT(*) AS check_count,
            -- Ранжируем задания по количеству проверок в каждый день
            ROW_NUMBER() OVER (PARTITION BY c.date ORDER BY COUNT(*) DESC) AS rn
        FROM checks c
        GROUP BY c.date, c.task
    )
    SELECT date, task
    FROM task_counts
    WHERE rn = 1  -- Берем только задание с максимальным количеством проверок
    ORDER BY date;
END;
$$;

-- ============================================================================
-- Функция 7: Студенты, завершившие блок заданий
-- ============================================================================
-- Находит студентов, которые успешно завершили все задания заданного блока
-- Параметр: block_name - название блока (например, 'C', 'CPP', 'DO')
-- Студент завершил блок, если последняя проверка задания блока успешна

CREATE OR REPLACE FUNCTION get_peers_completed_block(block_name VARCHAR)
RETURNS TABLE (
    peer VARCHAR,
    day DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH block_tasks AS (
        -- Выбираем все задания блока
        SELECT title FROM tasks
        WHERE title LIKE block_name || '%'
    ),
    last_checks AS (
        -- Для каждого студента берем последнюю проверку каждого задания блока
        SELECT DISTINCT ON (c.peer, c.task)
            c.peer,
            c.task,
            c.date,
            -- Определяем успешность: P2P Success и (если есть Verter, то Verter Success)
            (EXISTS (SELECT 1 FROM p2p WHERE "check" = c.id AND state = 'Success')
             AND (NOT EXISTS (SELECT 1 FROM verter WHERE "check" = c.id)
                  OR EXISTS (SELECT 1 FROM verter WHERE "check" = c.id AND state = 'Success'))
            ) AS is_success
        FROM checks c
        WHERE c.task IN (SELECT title FROM block_tasks)
        ORDER BY c.peer, c.task, c.date DESC
    )
    SELECT 
        lc.peer,
        MAX(lc.date) AS completion_day
    FROM last_checks lc
    WHERE lc.peer IN (
        -- Студенты, у которых ВСЕ задания блока успешны
        SELECT peer
        FROM last_checks
        WHERE is_success = TRUE
        GROUP BY peer
        HAVING COUNT(*) = (SELECT COUNT(*) FROM block_tasks)
    )
    GROUP BY lc.peer
    ORDER BY completion_day;
END;
$$;

-- ============================================================================
-- Функция 8: Определение рекомендованного peer для проверки
-- ============================================================================
-- Для каждого студента определяет, кого больше всего рекомендуют его друзья
-- Возвращает: Peer, RecommendedPeer

CREATE OR REPLACE FUNCTION get_recommended_peer_for_check()
RETURNS TABLE (
    peer VARCHAR,
    recommendedpeer VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH peer_friends AS (
        -- Получаем всех друзей для каждого студента
        SELECT peer1 AS peer, peer2 AS friend FROM friends
        UNION
        SELECT peer2 AS peer, peer1 AS friend FROM friends
    ),
    recommendations_from_friends AS (
        -- Считаем рекомендации от друзей (исключая самого студента)
        SELECT 
            pf.peer,
            r.recommendedpeer,
            COUNT(*) AS recommendation_count,
            ROW_NUMBER() OVER (PARTITION BY pf.peer ORDER BY COUNT(*) DESC) AS rn
        FROM peer_friends pf
        JOIN recommendations r ON pf.friend = r.peer
        WHERE r.recommendedpeer != pf.peer  -- Исключаем себя
        GROUP BY pf.peer, r.recommendedpeer
    )
    SELECT peer, recommendedpeer
    FROM recommendations_from_friends
    WHERE rn = 1  -- Берем самого рекомендуемого
    ORDER BY peer;
END;
$$;

-- ============================================================================
-- Функция 9: Процент студентов по блокам заданий
-- ============================================================================
-- Вычисляет процент студентов, начавших заданный блок 1 и заданный блок 2
-- Параметры: block1, block2 - названия блоков
-- Возвращает: StartedBlock1, StartedBlock2, StartedBothBlocks, DidntStartAnyBlock

CREATE OR REPLACE FUNCTION get_blocks_statistics(block1 VARCHAR, block2 VARCHAR)
RETURNS TABLE (
    startedblock1 INTEGER,
    startedblock2 INTEGER,
    startedbothblocks INTEGER,
    didntstartanyblock INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_peers INTEGER;
    started_b1 INTEGER;
    started_b2 INTEGER;
    started_both INTEGER;
    started_none INTEGER;
BEGIN
    -- Общее количество студентов
    SELECT COUNT(*) INTO total_peers FROM peers;
    
    -- Студенты, начавшие блок 1
    SELECT COUNT(DISTINCT peer) INTO started_b1
    FROM checks
    WHERE task LIKE block1 || '%';
    
    -- Студенты, начавшие блок 2
    SELECT COUNT(DISTINCT peer) INTO started_b2
    FROM checks
    WHERE task LIKE block2 || '%';
    
    -- Студенты, начавшие оба блока
    SELECT COUNT(*) INTO started_both
    FROM (
        SELECT peer FROM checks WHERE task LIKE block1 || '%'
        INTERSECT
        SELECT peer FROM checks WHERE task LIKE block2 || '%'
    ) AS both_blocks;
    
    -- Студенты, не начавшие ни один блок
    started_none := total_peers - 
                    (SELECT COUNT(DISTINCT peer) FROM checks 
                     WHERE task LIKE block1 || '%' OR task LIKE block2 || '%');
    
    -- Возвращаем проценты (округляем до целого)
    RETURN QUERY SELECT 
        ROUND(100.0 * started_b1 / NULLIF(total_peers, 0))::INTEGER,
        ROUND(100.0 * started_b2 / NULLIF(total_peers, 0))::INTEGER,
        ROUND(100.0 * started_both / NULLIF(total_peers, 0))::INTEGER,
        ROUND(100.0 * started_none / NULLIF(total_peers, 0))::INTEGER;
END;
$$;

-- ============================================================================
-- Функция 10: Процент успешных/неуспешных проверок в день рождения
-- ============================================================================
-- Вычисляет процент успешных и неуспешных проверок у студентов в их день рождения
-- Возвращает: SuccessfulChecks, UnsuccessfulChecks (в процентах)

CREATE OR REPLACE FUNCTION get_birthday_checks_statistics()
RETURNS TABLE (
    successfulchecks INTEGER,
    unsuccessfulchecks INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_checks INTEGER;
    successful_count INTEGER;
    unsuccessful_count INTEGER;
BEGIN
    -- Проверки в день рождения
    WITH birthday_checks AS (
        SELECT c.id
        FROM checks c
        JOIN peers p ON c.peer = p.nickname
        WHERE EXTRACT(MONTH FROM c.date) = EXTRACT(MONTH FROM p.birthday)
          AND EXTRACT(DAY FROM c.date) = EXTRACT(DAY FROM p.birthday)
    )
    SELECT COUNT(*) INTO total_checks FROM birthday_checks;
    
    -- Успешные проверки (P2P Success и Verter Success если есть)
    WITH birthday_checks AS (
        SELECT c.id
        FROM checks c
        JOIN peers p ON c.peer = p.nickname
        WHERE EXTRACT(MONTH FROM c.date) = EXTRACT(MONTH FROM p.birthday)
          AND EXTRACT(DAY FROM c.date) = EXTRACT(DAY FROM p.birthday)
    )
    SELECT COUNT(*) INTO successful_count
    FROM birthday_checks bc
    WHERE EXISTS (SELECT 1 FROM p2p WHERE "check" = bc.id AND state = 'Success')
      AND (NOT EXISTS (SELECT 1 FROM verter WHERE "check" = bc.id)
           OR EXISTS (SELECT 1 FROM verter WHERE "check" = bc.id AND state = 'Success'));
    
    unsuccessful_count := total_checks - successful_count;
    
    -- Возвращаем проценты
    IF total_checks > 0 THEN
        RETURN QUERY SELECT 
            ROUND(100.0 * successful_count / total_checks)::INTEGER,
            ROUND(100.0 * unsuccessful_count / total_checks)::INTEGER;
    ELSE
        RETURN QUERY SELECT 0, 0;
    END IF;
END;
$$;

-- ============================================================================
-- Функция 11: Суммарное XP студентов
-- ============================================================================
-- Возвращает общее количество XP, полученное каждым студентом
-- Колонки: Peer, XP

CREATE OR REPLACE FUNCTION get_total_xp_by_peer()
RETURNS TABLE (
    peer VARCHAR,
    xp BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.peer,
        COALESCE(SUM(x.xpamount), 0)::BIGINT AS total_xp
    FROM peers p
    LEFT JOIN checks c ON p.nickname = c.peer
    LEFT JOIN xp x ON c.id = x."check"
    GROUP BY c.peer
    HAVING c.peer IS NOT NULL
    ORDER BY total_xp DESC;
END;
$$;

-- ============================================================================
-- Функция 12: Студенты, выполнившие задания 1, 2, но не 3
-- ============================================================================
-- Находит студентов, которые успешно выполнили task1 и task2, но не task3
-- Параметры: task1, task2, task3 - названия заданий

CREATE OR REPLACE FUNCTION get_peers_with_specific_tasks(
    task1 VARCHAR,
    task2 VARCHAR, 
    task3 VARCHAR
)
RETURNS TABLE (peer VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    -- Студенты, выполнившие task1 и task2
    SELECT DISTINCT c.peer
    FROM checks c
    WHERE c.task = task1
      -- Проверка успешна
      AND EXISTS (SELECT 1 FROM p2p WHERE "check" = c.id AND state = 'Success')
      AND (NOT EXISTS (SELECT 1 FROM verter WHERE "check" = c.id)
           OR EXISTS (SELECT 1 FROM verter WHERE "check" = c.id AND state = 'Success'))
      -- Есть успешная проверка task2
      AND EXISTS (
          SELECT 1 FROM checks c2
          WHERE c2.peer = c.peer AND c2.task = task2
            AND EXISTS (SELECT 1 FROM p2p WHERE "check" = c2.id AND state = 'Success')
            AND (NOT EXISTS (SELECT 1 FROM verter WHERE "check" = c2.id)
                 OR EXISTS (SELECT 1 FROM verter WHERE "check" = c2.id AND state = 'Success'))
      )
      -- НЕТ успешной проверки task3
      AND NOT EXISTS (
          SELECT 1 FROM checks c3
          WHERE c3.peer = c.peer AND c3.task = task3
            AND EXISTS (SELECT 1 FROM p2p WHERE "check" = c3.id AND state = 'Success')
            AND (NOT EXISTS (SELECT 1 FROM verter WHERE "check" = c3.id)
                 OR EXISTS (SELECT 1 FROM verter WHERE "check" = c3.id AND state = 'Success'))
      )
    ORDER BY c.peer;
END;
$$;

-- ============================================================================
-- Функция 13: Количество предыдущих заданий для каждого
-- ============================================================================
-- Используя рекурсивный CTE, находит количество предшествующих заданий
-- Возвращает: Task, PrevCount

CREATE OR REPLACE FUNCTION get_task_hierarchy_count()
RETURNS TABLE (
    task VARCHAR,
    prevcount INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE task_hierarchy AS (
        -- Базовый случай: задания без родителя (корневые)
        SELECT 
            title,
            0 AS level
        FROM tasks
        WHERE parenttask IS NULL
        
        UNION ALL
        
        -- Рекурсивный случай: добавляем дочерние задания
        SELECT 
            t.title,
            th.level + 1
        FROM tasks t
        JOIN task_hierarchy th ON t.parenttask = th.title
    )
    SELECT title, level
    FROM task_hierarchy
    ORDER BY title;
END;
$$;

-- ============================================================================
-- Функция 14: Дни с наибольшим количеством XP
-- ============================================================================
-- Находит N дней с максимальной суммой полученного XP
-- Параметр: n - количество дней для вывода

CREATE OR REPLACE FUNCTION get_top_xp_days(n INTEGER)
RETURNS TABLE (
    day DATE,
    totalxp BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.date,
        SUM(x.xpamount)::BIGINT AS total_xp
    FROM checks c
    JOIN xp x ON c.id = x."check"
    GROUP BY c.date
    ORDER BY total_xp DESC
    LIMIT n;
END;
$$;

-- ============================================================================
-- Функция 15: Студенты, зашедшие раньше заданного времени N раз
-- ============================================================================
-- Находит студентов, которые заходили в кампус раньше указанного времени
-- минимум N раз за всю историю
-- Параметры: entry_time - время, n - минимальное количество раз

CREATE OR REPLACE FUNCTION get_early_entry_peers(entry_time TIME, n INTEGER)
RETURNS TABLE (peer VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT t.peer
    FROM timetracking t
    WHERE t.state = 1  -- Вход
      AND t.time < entry_time
    GROUP BY t.peer
    HAVING COUNT(*) >= n
    ORDER BY t.peer;
END;
$$;

-- ============================================================================
-- Функция 16: Студенты, выходившие более N раз за последние M дней
-- ============================================================================
-- Находит студентов, которые покидали кампус более N раз
-- в течение последних M дней (от текущей даты)
-- Параметры: n - количество выходов, m - количество дней

CREATE OR REPLACE FUNCTION get_frequent_exit_peers(n INTEGER, m INTEGER)
RETURNS TABLE (peer VARCHAR)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT t.peer
    FROM timetracking t
    WHERE t.state = 2  -- Выход
      AND t.date >= CURRENT_DATE - m
    GROUP BY t.peer
    HAVING COUNT(*) > n
    ORDER BY t.peer;
END;
$$;

-- ============================================================================
-- Функция 17: Процент ранних входов по месяцам для каждого студента
-- ============================================================================
-- Для каждого месяца определяет процент дней, когда студент пришел до 12:00
-- Возвращает: Month, EarlyEntriesPercentage

CREATE OR REPLACE FUNCTION get_early_entries_percentage()
RETURNS TABLE (
    month TEXT,
    earlyentriespercentage INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH birthday_months AS (
        -- Месяцы рождения студентов
        SELECT DISTINCT TO_CHAR(birthday, 'Month') AS month_name,
                       EXTRACT(MONTH FROM birthday) AS month_num
        FROM peers
    ),
    early_entries AS (
        -- Первые входы до 12:00 в месяцы рождения
        SELECT 
            p.nickname,
            TO_CHAR(p.birthday, 'Month') AS month_name,
            COUNT(DISTINCT t.date) AS early_days
        FROM peers p
        JOIN timetracking t ON p.nickname = t.peer
        WHERE t.state = 1
          AND t.time < '12:00:00'
          AND EXTRACT(MONTH FROM t.date) = EXTRACT(MONTH FROM p.birthday)
          AND t.time = (
              -- Первый вход в этот день
              SELECT MIN(time) FROM timetracking t2
              WHERE t2.peer = t.peer AND t2.date = t.date AND t2.state = 1
          )
        GROUP BY p.nickname, TO_CHAR(p.birthday, 'Month')
    ),
    total_entries AS (
        -- Все дни входа в месяцы рождения
        SELECT 
            p.nickname,
            TO_CHAR(p.birthday, 'Month') AS month_name,
            COUNT(DISTINCT t.date) AS total_days
        FROM peers p
        JOIN timetracking t ON p.nickname = t.peer
        WHERE t.state = 1
          AND EXTRACT(MONTH FROM t.date) = EXTRACT(MONTH FROM p.birthday)
        GROUP BY p.nickname, TO_CHAR(p.birthday, 'Month')
    )
    SELECT 
        bm.month_name,
        COALESCE(ROUND(100.0 * SUM(ee.early_days) / NULLIF(SUM(te.total_days), 0))::INTEGER, 0)
    FROM birthday_months bm
    LEFT JOIN early_entries ee ON bm.month_name = ee.month_name
    LEFT JOIN total_entries te ON bm.month_name = te.month_name
    GROUP BY bm.month_name, bm.month_num
    ORDER BY bm.month_num;
END;
$$;
