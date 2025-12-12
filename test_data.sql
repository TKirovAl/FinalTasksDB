-- Тестовые данные для базы данных Info21
-- Этот скрипт заполняет базу данных примерами для тестирования функций

\c info21;

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ PEERS
-- ============================================================================
-- Добавляем студентов School 21

INSERT INTO peers (nickname, birthday) VALUES
('alex_s', '2000-03-15'),
('maria_k', '1999-07-22'),
('ivan_p', '2001-01-10'),
('olga_v', '2000-11-05'),
('dmitry_b', '1998-09-18'),
('anna_m', '2001-04-30'),
('sergey_l', '1999-12-25'),
('elena_r', '2000-06-14');

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ TASKS
-- ============================================================================
-- Создаем иерархию заданий по блокам (C, CPP, DO)

-- Блок C
INSERT INTO tasks (title, parenttask, maxxp) VALUES
('C1_SimpleBashUtils', NULL, 250),
('C2_s21_string', 'C1_SimpleBashUtils', 500),
('C3_s21_decimal', 'C2_s21_string', 350),
('C4_s21_math', 'C3_s21_decimal', 300),
('C5_s21_matrix', 'C4_s21_math', 200),
('C6_s21_string+', 'C5_s21_matrix', 500);

-- Блок CPP
INSERT INTO tasks (title, parenttask, maxxp) VALUES
('CPP1_s21_matrix+', 'C6_s21_string+', 300),
('CPP2_s21_containers', 'CPP1_s21_matrix+', 350),
('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600);

-- Блок DO (DevOps)
INSERT INTO tasks (title, parenttask, maxxp) VALUES
('DO1_Linux', NULL, 300),
('DO2_LinuxNetwork', 'DO1_Linux', 250),
('DO3_LinuxMonitoring_v1.0', 'DO2_LinuxNetwork', 350);

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ CHECKS
-- ============================================================================
-- Добавляем проверки заданий

INSERT INTO checks (peer, task, date) VALUES
-- alex_s проходит C1 и C2
(1, 'C1_SimpleBashUtils', '2024-01-15'),
(1, 'C2_s21_string', '2024-02-10'),
-- maria_k проходит C1, C2, C3
(2, 'C1_SimpleBashUtils', '2024-01-20'),
(2, 'C2_s21_string', '2024-02-15'),
(2, 'C3_s21_decimal', '2024-03-10'),
-- ivan_p проходит DO блок
(3, 'DO1_Linux', '2024-01-25'),
(3, 'DO2_LinuxNetwork', '2024-02-20'),
-- olga_v проходит C1
(4, 'C1_SimpleBashUtils', '2024-01-18'),
-- dmitry_b проходит C1, C2
(5, 'C1_SimpleBashUtils', '2024-01-22'),
(5, 'C2_s21_string', '2024-02-18');

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ P2P
-- ============================================================================
-- Добавляем P2P проверки (Start и Success/Failure)

-- alex_s - C1 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(1, 'maria_k', 'Start', '10:00:00'),
(1, 'maria_k', 'Success', '10:45:00');

-- alex_s - C2 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(2, 'ivan_p', 'Start', '14:00:00'),
(2, 'ivan_p', 'Success', '15:30:00');

-- maria_k - C1 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(3, 'alex_s', 'Start', '11:00:00'),
(3, 'alex_s', 'Success', '11:50:00');

-- maria_k - C2 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(4, 'olga_v', 'Start', '13:00:00'),
(4, 'olga_v', 'Success', '14:20:00');

-- maria_k - C3 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(5, 'dmitry_b', 'Start', '15:00:00'),
(5, 'dmitry_b', 'Success', '16:30:00');

-- ivan_p - DO1 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(6, 'sergey_l', 'Start', '09:00:00'),
(6, 'sergey_l', 'Success', '10:00:00');

-- ivan_p - DO2 (неудачно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(7, 'anna_m', 'Start', '11:00:00'),
(7, 'anna_m', 'Failure', '12:00:00');

-- olga_v - C1 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(8, 'elena_r', 'Start', '10:30:00'),
(8, 'elena_r', 'Success', '11:30:00');

-- dmitry_b - C1 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(9, 'maria_k', 'Start', '12:00:00'),
(9, 'maria_k', 'Success', '13:00:00');

-- dmitry_b - C2 (успешно)
INSERT INTO p2p ("check", checkingpeer, state, time) VALUES
(10, 'alex_s', 'Start', '14:30:00'),
(10, 'alex_s', 'Success', '15:45:00');

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ VERTER
-- ============================================================================
-- Добавляем автоматические проверки Verter

-- alex_s - C1 (Success)
INSERT INTO verter ("check", state, time) VALUES
(1, 'Start', '10:50:00'),
(1, 'Success', '10:52:00');

-- alex_s - C2 (Success)
INSERT INTO verter ("check", state, time) VALUES
(2, 'Start', '15:35:00'),
(2, 'Success', '15:37:00');

-- maria_k - C1 (Success)
INSERT INTO verter ("check", state, time) VALUES
(3, 'Start', '11:55:00'),
(3, 'Success', '11:57:00');

-- maria_k - C2 (Failure)
INSERT INTO verter ("check", state, time) VALUES
(4, 'Start', '14:25:00'),
(4, 'Failure', '14:27:00');

-- maria_k - C3 (Success)
INSERT INTO verter ("check", state, time) VALUES
(5, 'Start', '16:35:00'),
(5, 'Success', '16:37:00');

-- ivan_p - DO1 (Success)
INSERT INTO verter ("check", state, time) VALUES
(6, 'Start', '10:05:00'),
(6, 'Success', '10:07:00');

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ XP
-- ============================================================================
-- Добавляем полученный XP за успешные проверки

INSERT INTO xp ("check", xpamount) VALUES
(1, 250),  -- alex_s - C1
(2, 500),  -- alex_s - C2
(3, 250),  -- maria_k - C1
(5, 350),  -- maria_k - C3
(6, 300),  -- ivan_p - DO1
(8, 250),  -- olga_v - C1
(9, 250),  -- dmitry_b - C1
(10, 500); -- dmitry_b - C2

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ FRIENDS
-- ============================================================================
-- Связи дружбы между студентами

INSERT INTO friends (peer1, peer2) VALUES
('alex_s', 'maria_k'),
('alex_s', 'ivan_p'),
('maria_k', 'olga_v'),
('ivan_p', 'sergey_l'),
('dmitry_b', 'anna_m'),
('olga_v', 'elena_r');

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ RECOMMENDATIONS
-- ============================================================================
-- Рекомендации студентов друг другу

INSERT INTO recommendations (peer, recommendedpeer) VALUES
('alex_s', 'maria_k'),
('alex_s', 'ivan_p'),
('maria_k', 'alex_s'),
('maria_k', 'olga_v'),
('ivan_p', 'sergey_l'),
('olga_v', 'maria_k'),
('olga_v', 'elena_r'),
('dmitry_b', 'anna_m'),
('sergey_l', 'ivan_p');

-- ============================================================================
-- ЗАПОЛНЕНИЕ ТАБЛИЦЫ TIMETRACKING
-- ============================================================================
-- Логи входов и выходов студентов

-- alex_s - несколько дней
INSERT INTO timetracking (peer, date, time, state) VALUES
('alex_s', '2024-01-15', '08:30:00', 1),  -- Вход
('alex_s', '2024-01-15', '18:00:00', 2),  -- Выход
('alex_s', '2024-01-16', '09:00:00', 1),
('alex_s', '2024-01-16', '17:30:00', 2),
('alex_s', '2024-02-10', '08:00:00', 1),
('alex_s', '2024-02-10', '19:00:00', 2);

-- maria_k - провела весь день в кампусе 20 января
INSERT INTO timetracking (peer, date, time, state) VALUES
('maria_k', '2024-01-20', '09:00:00', 1),  -- Вход
('maria_k', '2024-01-21', '08:30:00', 1),
('maria_k', '2024-01-21', '18:00:00', 2);

-- ivan_p
INSERT INTO timetracking (peer, date, time, state) VALUES
('ivan_p', '2024-01-25', '10:00:00', 1),
('ivan_p', '2024-01-25', '16:00:00', 2),
('ivan_p', '2024-02-20', '11:00:00', 1),
('ivan_p', '2024-02-20', '15:00:00', 2);

-- olga_v - ранний приход в день рождения
INSERT INTO timetracking (peer, date, time, state) VALUES
('olga_v', '2024-01-18', '08:00:00', 1),
('olga_v', '2024-01-18', '17:00:00', 2),
('olga_v', '2024-11-05', '07:30:00', 1),  -- День рождения, ранний приход
('olga_v', '2024-11-05', '18:00:00', 2);

-- dmitry_b
INSERT INTO timetracking (peer, date, time, state) VALUES
('dmitry_b', '2024-01-22', '09:30:00', 1),
('dmitry_b', '2024-01-22', '18:30:00', 2),
('dmitry_b', '2024-02-18', '10:00:00', 1),
('dmitry_b', '2024-02-18', '17:00:00', 2);

-- Дополнительные записи для других студентов
INSERT INTO timetracking (peer, date, time, state) VALUES
('anna_m', '2024-01-15', '11:00:00', 1),
('anna_m', '2024-01-15', '16:00:00', 2),
('sergey_l', '2024-01-25', '08:45:00', 1),
('sergey_l', '2024-01-25', '17:15:00', 2),
('elena_r', '2024-01-18', '10:30:00', 1),
('elena_r', '2024-01-18', '15:30:00', 2);

-- ============================================================================
-- ПРИМЕРЫ ПРОВЕРКИ РАБОТЫ ФУНКЦИЙ
-- ============================================================================

-- Раскомментируйте для тестирования:

RAISE NOTICE '========================================';
RAISE NOTICE 'Testing Functions';
RAISE NOTICE '========================================';

-- Тест 1: Readable TransferredPoints
RAISE NOTICE 'Function 1: get_transferred_points_readable()';
-- SELECT * FROM get_transferred_points_readable();

-- Тест 2: Успешные проверки с XP
RAISE NOTICE 'Function 2: get_successful_checks_with_xp()';
-- SELECT * FROM get_successful_checks_with_xp();

-- Тест 3: Студенты, не покидавшие кампус
RAISE NOTICE 'Function 3: get_peers_not_left_campus()';
-- SELECT * FROM get_peers_not_left_campus('2024-01-20');

-- Тест 4: Изменение peer points
RAISE NOTICE 'Function 4: get_peer_points_change()';
-- SELECT * FROM get_peer_points_change();

-- Тест 5: Самое проверяемое задание
RAISE NOTICE 'Function 6: get_most_checked_task_per_day()';
-- SELECT * FROM get_most_checked_task_per_day();

-- Тест 6: Завершение блока
RAISE NOTICE 'Function 7: get_peers_completed_block()';
-- SELECT * FROM get_peers_completed_block('C');

-- Тест 7: Рекомендации
RAISE NOTICE 'Function 8: get_recommended_peer_for_check()';
-- SELECT * FROM get_recommended_peer_for_check();

-- Тест 8: Статистика по блокам
RAISE NOTICE 'Function 9: get_blocks_statistics()';
-- SELECT * FROM get_blocks_statistics('C', 'DO');

-- Тест 9: Суммарное XP
RAISE NOTICE 'Function 11: get_total_xp_by_peer()';
-- SELECT * FROM get_total_xp_by_peer();

-- Тест 10: Дни с максимальным XP
RAISE NOTICE 'Function 14: get_top_xp_days()';
-- SELECT * FROM get_top_xp_days(3);
