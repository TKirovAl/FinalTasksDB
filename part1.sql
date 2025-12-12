-- Part 1: Создание базы данных и таблиц
-- Скрипт создает структуру базы данных для School 21

-- Удаление базы если существует и создание новой
DROP DATABASE IF EXISTS info21;
CREATE DATABASE info21;

-- Подключение к базе
\c info21;

-- Создание типа ENUM для статуса проверки
-- Определяет возможные состояния проверки: Start, Success, Failure
CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');

-- Таблица Peers: Информация о студентах
-- Хранит никнеймы и даты рождения студентов
CREATE TABLE peers (
    nickname VARCHAR PRIMARY KEY,    -- Уникальный никнейм студента
    birthday DATE NOT NULL            -- Дата рождения
);

-- Таблица Tasks: Информация о заданиях
-- Содержит иерархию заданий и максимальное количество XP
CREATE TABLE tasks (
    title VARCHAR PRIMARY KEY,                    -- Название задания (уникальное)
    parenttask VARCHAR,                           -- Родительское задание (NULL для корневых)
    maxxp INTEGER NOT NULL CHECK (maxxp > 0),    -- Максимальное XP за задание
    FOREIGN KEY (parenttask) REFERENCES tasks(title) ON DELETE SET NULL
);

-- Таблица Checks: Проверки заданий
-- Связывает студента, задание и дату проверки
CREATE TABLE checks (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID проверки
    peer VARCHAR NOT NULL,                        -- Проверяемый студент
    task VARCHAR NOT NULL,                        -- Проверяемое задание
    date DATE NOT NULL,                           -- Дата проверки
    FOREIGN KEY (peer) REFERENCES peers(nickname) ON DELETE CASCADE,
    FOREIGN KEY (task) REFERENCES tasks(title) ON DELETE CASCADE
);

-- Таблица P2P: Peer-to-peer проверки
-- Хранит информацию о взаимных проверках между студентами
CREATE TABLE p2p (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID записи P2P
    "check" BIGINT NOT NULL,                      -- Ссылка на проверку (в кавычках т.к. check - зарезервированное слово)
    checkingpeer VARCHAR NOT NULL,                -- Проверяющий студент
    state check_status NOT NULL,                  -- Статус проверки (Start/Success/Failure)
    time TIME NOT NULL,                           -- Время проверки
    FOREIGN KEY ("check") REFERENCES checks(id) ON DELETE CASCADE,
    FOREIGN KEY (checkingpeer) REFERENCES peers(nickname) ON DELETE CASCADE
);

-- Таблица Verter: Автоматические проверки
-- Результаты проверки кода автоматической системой Verter
CREATE TABLE verter (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID записи Verter
    "check" BIGINT NOT NULL,                      -- Ссылка на проверку
    state check_status NOT NULL,                  -- Статус проверки
    time TIME NOT NULL,                           -- Время проверки
    FOREIGN KEY ("check") REFERENCES checks(id) ON DELETE CASCADE
);

-- Таблица TransferredPoints: Переданные баллы
-- Учитывает баллы, переданные между студентами за P2P проверки
CREATE TABLE transferredpoints (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID передачи
    checkingpeer VARCHAR NOT NULL,                -- Проверяющий студент
    checkedpeer VARCHAR NOT NULL,                 -- Проверяемый студент
    pointsamount INTEGER NOT NULL,                -- Количество переданных баллов
    FOREIGN KEY (checkingpeer) REFERENCES peers(nickname) ON DELETE CASCADE,
    FOREIGN KEY (checkedpeer) REFERENCES peers(nickname) ON DELETE CASCADE
);

-- Таблица Friends: Дружеские связи
-- Хранит информацию о дружбе между студентами
CREATE TABLE friends (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID связи
    peer1 VARCHAR NOT NULL,                       -- Первый студент
    peer2 VARCHAR NOT NULL,                       -- Второй студент
    FOREIGN KEY (peer1) REFERENCES peers(nickname) ON DELETE CASCADE,
    FOREIGN KEY (peer2) REFERENCES peers(nickname) ON DELETE CASCADE,
    CHECK (peer1 < peer2)                         -- Гарантирует уникальность пары (предотвращает дубликаты)
);

-- Таблица Recommendations: Рекомендации
-- Студенты рекомендуют друг другу полезных проверяющих
CREATE TABLE recommendations (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID рекомендации
    peer VARCHAR NOT NULL,                        -- Студент, дающий рекомендацию
    recommendedpeer VARCHAR NOT NULL,             -- Рекомендуемый студент
    FOREIGN KEY (peer) REFERENCES peers(nickname) ON DELETE CASCADE,
    FOREIGN KEY (recommendedpeer) REFERENCES peers(nickname) ON DELETE CASCADE
);

-- Таблица XP: Полученный опыт
-- Записывает XP, полученный за успешные проверки
CREATE TABLE xp (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID записи XP
    "check" BIGINT NOT NULL,                      -- Ссылка на проверку
    xpamount INTEGER NOT NULL,                    -- Количество полученного XP
    FOREIGN KEY ("check") REFERENCES checks(id) ON DELETE CASCADE
);

-- Таблица TimeTracking: Отслеживание времени
-- Логирует входы и выходы студентов с кампуса
-- state: 1 = вход, 2 = выход
CREATE TABLE timetracking (
    id BIGSERIAL PRIMARY KEY,                     -- Уникальный ID записи
    peer VARCHAR NOT NULL,                        -- Студент
    date DATE NOT NULL,                           -- Дата посещения
    time TIME NOT NULL,                           -- Время события
    state INTEGER NOT NULL CHECK (state IN (1, 2)), -- 1 - вход, 2 - выход
    FOREIGN KEY (peer) REFERENCES peers(nickname) ON DELETE CASCADE
);

-- Создание индексов для оптимизации запросов
CREATE INDEX idx_checks_peer ON checks(peer);
CREATE INDEX idx_checks_task ON checks(task);
CREATE INDEX idx_p2p_check ON p2p("check");
CREATE INDEX idx_verter_check ON verter("check");
CREATE INDEX idx_xp_check ON xp("check");
CREATE INDEX idx_timetracking_peer_date ON timetracking(peer, date);
