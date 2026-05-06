-- system.query_log
-- системная таблица, хранящая информацию обо всех запросах всех пользователей
-- Описание нужных колонок, для удобства
-- query (String) — текст запроса.
-- read_rows (UInt64) — общее количество строк, считанных из всех таблиц и табличных функций, участвующих в запросе.
-- read_bytes (UInt64) — общее количество байтов, считанных из всех таблиц и табличных функций, участвующих в запросе.
-- result_rows (UInt64) — количество строк в результате запроса SELECT или количество строк в запросе INSERT.
-- result_bytes (UInt64) — объём RAM в байтах, использованный для хранения результата запроса.
-- memory_usage (UInt64) — потребление RAM запросом.
-- query_duration_ms (UInt64) — длительность выполнения запроса в миллисекундах.

select query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    --and (query ilike '%select now()%')
    and query not ilike '%system%'
    and type = 2
;


-------------- генерим тестовую таблицу

-- необходимая для генерации тестовой таблицы функция
SELECT * FROM generateRandom('a Int64, b String, c DateTime', 1, 10, 2) LIMIT 3;

-- создаем таблицу с тестовыми данными
drop table if exists first_test; -- удалить таблицу, если что-то пошло не так
CREATE TABLE first_test (
    id Int64,
    name_good String,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY name_good
SETTINGS index_granularity = 8192; -- типы данных, конструкции ENGINE = MergeTree() и ORDER BY name_good будут разобраны позже

-- вставляем данные
INSERT INTO first_test (id, name_good, event_time)
SELECT * FROM generateRandom('a Int64, b String, c DateTime', 1, 10, 2) LIMIT 100000;

-- строки не всегда вставляются адекватно, бывает генерит пустые/ломаные, смотри не пустые
SELECT * from first_test where name_good != '';






-------------- "обычные" функции

select abs(-2.6);
select 5/2;
select plus(1,1);
select 1 + 1;


-------------- функции для работы с датой и временем
-- кратко про типы данных:
--- DateTime - хранит и дату и время в формате timestamp (количество секунд, прошедших с 1970-01-01 00:00:00).
--- Date - хранит только дату в формате количества дней, прошедших с 1970-01-01 00:00:00. Занимает в два раза меньше места, чем DateTime

select now(); -- текущее время

SELECT now(), dateTrunc('hour', now()); -- "округление" до указанной точности

select toHour(now()); -- получить значение текущего часа в числовом формате

select now(), toStartOfHour(now()); -- альтернативный способ "округления" до указанной точности. Целая группа функций toStartOf...

select yesterday(); -- вчерашний день

select today(); -- сегодняшний день


-------------- функции сравнения

select now() > now() + 1; -- да, кликхаус отлично сравнивает даты между собой без преобразований

-- а еще он отлично суммирует дату и числа по принципу "добавлю n наименьшей градации времени". Если наименьшая градация - секунда,
-- то запись + 1 добавит ко времени 1 секунду

select now() + 100; -- добавил 100 секунд
select toDate(now()) + 1; -- добавил один день

-- функция interval

select now() + 100 hour; -- не работает, хотя ошибку синтаксиса не вызывает, что весьма опасно, т.к. кажется, что все работает ок

select now() + interval 2 day; -- волшебная функция interval

select 'a' < 'b'; -- строки сравниваются посимвольно по порядку. a - 0, b - 1 и т.д., следовательно b > a

select 5 > 10; -- числа сравнивает интуитивно понятно


-------------- условные функции

select greatest(1, 2); -- вернет наибольшее значение из переданных

select greatest('a', 'b'); -- аналогично со строками

select least(1, 2); -- вернет наименьшее значение из переданных

select max(1, 2); -- забегая наперед, min(), max() - аггрегатные функции, и работают только при group by, иы же изучаем "обычные" функции

select if(1 > 1, 'privet', 'poka'); -- условие, если да, если нет

SELECT case when 1 > 0 then 'privet' when 2 > 0 then 'poka' else '' end; -- классический case when, но появился какой-то multiif

select multiIf(greater(1, 0), 'privet', greater(2, 0), 'poka', ''); -- вот, что он на самом деле сделал

select multiIf(1 > 0, 'privet', 2 > 0, 'poka', ''); -- нормальный вид, если бы писали код сами


-------------- функции работы со строками (приводим примеры из всех разделов документации)
-- кратко про типы данных:
--- String - строка неограниченной длины. Кодировка utf-8 (стандарт). И все. Никаких размеров, ограничений и прочего.
--- FixedString - строка фиксированной длины. Полезен только в том случае, если заранее известно точное число байт.
---               Например, в случае хранения валют - USD, RUB и т.д. Во всех остальных случаях только вредит

SELECT splitByChar('!', '1!2!3!abcde'); -- разбить строку на элементы по заданному разделителю и сформировать из полученных элементов массив

SELECT concat('Hello, ', 'World! ', 1); -- если видит тип отличный от строкового - преобразует по возможности к строке

-- извлекает подстроку из строки. 
-- первый аргумент - сама строка
-- второй - отступ от начала строки, с которого следует начать извлечение
-- третий - сколько элементов после отступа необходимо изъять. Если третьего аргумента нет - берется все до конца строка
SELECT substr('Hello', 3), substr('Hello', 3, 2); 

-- удаляет пробельные символы слева. В новых версих вторым аргументов можно указать требуемые для удаления символы.
-- аналог справа - rtrim
SELECT ltrim('     ClickHouse'); 

SELECT upper('CLICKhouse'); -- переводит символы в верхний регистр

-- замена в строке всех вхождений паттерна на требуемое значение
-- первый аргумент - сама строка
-- второй аргумент - что в строке ищем
-- третий аргумент - на что второй аргумент заменить
SELECT replaceAll('Hello world Hello', 'Hello', 'Hi'); 

-- извлекает первое совпадение регулярного выражения в строке. Использует синтаксис re2, ссылка ниже
-- https://github.com/google/re2/wiki/Syntax
SELECT extract('qqbb123вфывфы456', '\d+'); -- как пример, извлекат из строки первое вхождение паттерна по поиску чисел, идущих подряд
SELECT extractAll('qqbb123вфывфы456', '\d+'); -- возвращает всех вхождения паттерна в виде массива

-- Выполняет поиска паттерна в строке. Упрощенный вариант, без регулярок. Возвращает 1 или 0 в зависимости от того, нашел паттерн или нет
-- первый аргумент - сама строка
-- сторой аргумент - что в ней ищем
--- Обозначение метасимволов:
---- % обозначает произвольное количество произвольных символов (включая ноль символов).
---- _ обозначает один произвольный символ.
---- \ используется для экранирования литералов %, _ и \.
select like('Hello world', '%Hello%');
select like('Hello world', '%hello%'); -- как видим, этот оператор регистрозависимый

select ilike('Hello world', '%Hello%');
select ilike('Hello world', '%hello%'); -- в вот ilike не регистрозависимый


-------------- функции преобразования типов

-- классический CAST - преобразует значение в указанный тип данных
select cast(64, 'String'); -- первый аргумент - значение, второй - требуемый тип
select cast('64', 'Int64'); -- число из строки сумеет вычленить, как и дату
select cast('QQ', 'Int64'); -- а вот преобразовать QQ в число, очевидно, не сможет

-- toString - преобразует что-либо в строку. Как и целая когорта функций to...
select toString(2313); -- работает
select toString(2313sadsa); -- не любую ерунду сможет перевести в строку
select cast(2313вфывф, 'String'); -- и CAST, конечно же, не поможет

-- преобразование типов может привести к потере данных, учитывай размерность
select toInt8(2132131), 2132131;

-- parseDateTimeBestEffortOrZero - распарсит почти любой кривой вариант даты в нормальный вид. 
-- parseDateTime - целая когорта функций парсинга даты
SELECT parseDateTimeBestEffortOrZero('23/10/2025 12:12:57') AS valid,
       --toDateTime('23/10/2025 12:12:57') as sad,
       parseDateTimeBestEffortOrZero('invalid') AS invalid;


-------------- функции массивов

select array(['dsada', 'dasdwqe'], ['qq', 'bb', 'gg']) as arr;
select array(213, 'qq', [1,2,'bb']) as arr; -- элементы массива должны быть одного типа
select [1, 2, 3]; -- массив также задается без ключевого слова array, [] достаточно, клик поймет

select arrayFilter(x -> x ilike '%вася%', ['Вася', 'Саша']); -- фильтруем массив
select arrayFilter(x -> x[2] ilike '%вася%', [['разработчик', 'Вася'], ['аналитик', 'Саша']]); -- фильтруем массив массивов

select arrayMap(x -> concat(x, ' крутой перец'), ['Вася', 'Саша']); -- применяем лямбда-функцию итеративно к каждому элементу массива


-------------- Тренируемся

-- реальный рабочий кейс, только, конечно же, логически изменен. Если сотрудника зовут Вася - нужно добавить " наш коллега",
-- если НЕ Вася - " не наш коллега". Ну и данные изначально даны уже в формате массива, а не распарсеных колонок. И ответ требует заказчик
-- также в формате массива. И все это приводит к тому, что от массивов не отвертеться.


select 
    arrayMap(x -> concat(x[2], ' наш коллега'), 
        arrayFilter(x -> x[2] ilike '%вася%', [['разработчик', 'Вася'], ['аналитик', 'Саша']])
    ) as result
union all
select 
    arrayMap(x -> concat(x[2], ' не наш коллега'), 
        arrayFilter(x -> x[2] not ilike '%вася%', [['разработчик', 'Вася'], ['аналитик', 'Саша']])
    ) as result;

-- а если чуть-чуть пошаманить, то можно и одной функцией массивов обойтись и убрать union all
select 
    arrayMap(x -> if(x[2] ilike '%вася%', concat(x[2], ' наш коллега'), concat(x[2], ' не наш коллега'))
        , [['разработчик', 'Вася'], ['аналитик', 'Саша']])
    as result;

-- когда, например, нужно соединить две колонки в одну и добавить разделитель
-- например, Алеша Иванов
select array(toString(id), name_good) from first_test; -- создаем массив однородных элементов

-- arrayStringConcat - функция, принимающая на вход массив и разделитель. Возвращает строку, состоящую из элементов массива,
-- разделенных разделителем
select arrayStringConcat(array(toString(id), name_good), '       !SEPARATOR!          ') as res
from first_test
where name_good != ''
limit 1000;

-- исправляем, убирая битые строки
select trim(name_good) without_space -- удаляем все пробелы из строки
from first_test
where without_space != ''; -- и вот теперь, если строка после удаления пробелов не пустая - оставляем ее

select arrayStringConcat(array(toString(id), name_good), '       !SEPARATOR!          ') as res
from first_test
where trim(name_good) != ''
limit 1000;







-------------- агрегатные функции

select any(name_good) any_f -- первое попавшееся значение колонки name_good
    , count() cnt
    , min(id) min_id
    , max(id) max_id
    , avg(id) avg_id
    , median(id) med_id -- медиана
from first_test;

select toStartOfISOYear(event_time) year_dt
    , any(name_good) any_f -- первое попавшееся значение колонки name_good
    , count() cnt
    , min(id) min_id
    , max(id) max_id
    , avg(id) avg_id
    , median(id) med_id -- медиана
from first_test
group by year_dt
order by year_dt desc;

select uniq(name_good) uniq_name -- не точный подсчет количества уникальных значений
    , uniqExact(name_good) uniqExact_name -- точный подсчет количества уникальных значений
from first_test
;

select toStartOfISOYear(event_time) year_dt
    , uniq(name_good) uniq_name -- не точный подсчет количества уникальных значений
    , uniqExact(name_good) uniqExact_name -- точный подсчет количества уникальных значений
from first_test
group by year_dt
order by year_dt desc
;

-- тест потребления ресурсов uniq
select uniq(name_good) uniq_name
from first_test
;

-- тест потребления ресурсов uniqExact
select uniqExact(name_good) uniqExact_name
from first_test
;

-- смотрим результат
select query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%тест потребления ресурсов uniq%')
    and query not ilike '%system%'
    and type = 2
;

-- тест потребления ресурсов quantile
select quantile(0.95)(id) q_id
from first_test
;

-- тест потребления ресурсов quantileExact
select quantileExact(0.95)(id) q_Exact_id
from first_test
;

-- смотрим процент ошибки
select 8318227616568580100 / 8289920562930021183; -- менее, чем на 1%

-- смотрим результат
select query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%тест потребления ресурсов quantile%')
    and query not ilike '%system%'
    and type = 2
;

-- argMin(), argMax()
select argMin(id, event_time) -- возвращает id, который соответствует минимальному значению event_time
    , argMax(id, event_time) -- возвращает id, который соответствует максимальному значению event_time
from first_test
;

-- массивы
select toStartOfISOYear(event_time) year_dt
    --, array(name_good) arr_bad -- неправильный вариант создания массива при группировке
    , groupArray(name_good) arr
    , groupUniqArray(name_good) arr_uniq -- массив уникальных значений, подсчет точный - uniqExact
from first_test
group by year_dt
order by year_dt desc
;

-- комбинаторы аггрегатных функций. If
select toStartOfISOYear(event_time) year_dt
    , count() cnt
    , countIf(name_good != '') cnt_if1
    , countIf(name_good = '') cnt_if2
from first_test
group by year_dt
order by year_dt desc
;

-- комбинаторы аггрегатных функций. Distinct
select toStartOfISOYear(event_time) year_dt
    , groupArrayDistinct(name_good) uniq_good_dst
from first_test
group by year_dt
order by year_dt desc
;

-- комбинаторы аггрегатных функций. Вкладывать их нельзя
select toStartOfISOYear(event_time) year_dt
    , uniq(groupArray(id)) uniq_sad -- напрямую вкладывать агрегатные функции друг в друга нельзя
from first_test
group by year_dt
order by year_dt desc
;

-- комбинаторы аггрегатных функций. array + агрегатная функция
select toStartOfISOYear(event_time) year_dt
    --, array(name_good) arr_bad -- напоминание - неправильный вариант создания массива при группировке
    , uniq(array(id)) uniq_good -- а вот в комбинации с применением агрегатной функции это работает
from first_test
group by year_dt
order by year_dt desc
;

-- argMinIf()
select argMin(id, event_time) -- возвращает id, который соответствует минимальному значению event_time
    , argMinIf(id, event_time, event_time > now() - interval 20 year) -- тоже самое, но с условием
from first_test
;






-------------- JOIN

-- создадим таблицы, которые будем джойнить. Сделаем их поменьше.
drop table if exists second_test; -- удалить таблицу, если что-то пошло не так
CREATE TABLE second_test (
    id UInt8, -- чтобы было больше совпадений по id
    name_good String,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY name_good
SETTINGS index_granularity = 8192; -- типы данных, конструкции ENGINE = MergeTree() и ORDER BY name_good будут разобраны позже

-- вставляем данные
INSERT INTO second_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt8, b String, c DateTime', 1, 10, 2) LIMIT 10000; -- 10 000 вместо 100 000

drop table if exists third_test; -- удалить таблицу, если что-то пошло не так
CREATE TABLE third_test (
    id UInt8, -- чтобы было больше совпадений по id
    name_good String,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY name_good
SETTINGS index_granularity = 8192; -- типы данных, конструкции ENGINE = MergeTree() и ORDER BY name_good будут разобраны позже

-- вставляем данные
INSERT INTO third_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt8, b String, c DateTime', 1, 10, 2) LIMIT 10000; -- 10 000 вместо 100 000

-- LEFT/RIGHT SEMI JOIN
-- Запрос LEFT SEMI JOIN возвращает значения столбцов для каждой строки из левой таблицы, у которой есть хотя бы одно совпадение по условию 
-- соединения в правой таблице. Если для строки найдено более одного совпадения, возвращается только первое найденное совпадение 
-- (декартово произведение отключено).

-- видим 10 000 строк - количество записей в левой таблице, для каждой нашлось совпадение
select *
from second_test t1
left semi join third_test t2
on t1.id = t2.id
;

-- классический left join в это время вернул в 40 раз больше записей, так как реализовал все соединения
select *
from second_test t1
left join third_test t2
on t1.id = t2.id
;

-- магия: раз left semi join оставляет только те записи из левой таблицы, для которых есть совпадение в правой, то очевидно, что
-- это автоматически и right semi join, ведь важен сам факт наличия совпадения. А это уже работа классического inner join.
-- и отличий между left semi join, right semi join и просто semi join не будет. И сравнивать его, по-хорошему, надо именно с inner join.
-- и его ключевое отличие от inner join в том, что он возвращает лишь первое найденное совпадение

-- LEFT/RIGHT ANTI JOIN
-- возвращает значения столбцов для всех строк левой таблицы, не имеющих совпадений со строками правой таблицы по условию соединения

-- так как для каждой строки есть совпадение - пустой вывод
select *
from second_test t1
left anti join third_test t2
on t1.id = t2.id
;

-- просто чтобы убедиться, джойним с первой таблицей, где совпадений по id точно не будет. Видим все 10 000 записей
select *
from second_test t1
left anti join first_test t2
on t1.id = t2.id
;

-- LEFT/RIGHT/INNER ANY JOIN
-- опишу своими словами. Ключевое слово - ANY. В каждом из видов соединений оно говорит лишь об одном: отключи декартово произведение.
-- Это условие в клике называется строгостью. По умолчанию строгость - ALL. Это ключевое слово просто опускается в синтаксисе записи джойна.

-- создадим таблицу, чтобы в ней были НЕ все id
drop table if exists four_test; -- удалить таблицу, если что-то пошло не так
CREATE TABLE four_test (
    id UInt8, -- чтобы было больше совпадений по id
    name_good String,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY name_good
SETTINGS index_granularity = 8192; -- типы данных, конструкции ENGINE = MergeTree() и ORDER BY name_good будут разобраны позже

-- вставляем данные
INSERT INTO four_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt8, b String, c DateTime', 1, 10, 2) LIMIT 200; -- 200, чтобы не охватить все 255 значения

select *
from second_test t1
left any join four_test t2
on t1.id = t2.id
;

-- и да, к банде left semi join, right semi join, semi join теперь присоединяется еще и inner any join. Это все одно и то же

-- LEFT/RIGHT/INNER ASOF JOIN
-- опишу своими словами. Ищет БЛИЖАЙШЕЕ по дате совпадение записей. Ключевое условие неравенства всегда должно быть последним.
-- не производит декартового произведения.

-- видим все 10 000 записей, так как LEFT
select *
from second_test t1
left asof join third_test t2
on t1.id = t2.id and t1.event_time > t2.event_time
;

-- видим, что не хватает некоторых записей
select *
from second_test t1
inner asof join third_test t2
on t1.id = t2.id and t1.event_time > t2.event_time
;

-- поиск недостающих записей
select *
from second_test t1
left asof join third_test t2
on t1.id = t2.id and t1.event_time > t2.event_time
where t1.id != t2.id
order by id
;

-- неожиданно, но inner any join дает такой же результат
select *
from second_test t1
inner any join third_test t2
on t1.id = t2.id and t1.event_time > t2.event_time
;

-- все дело в том, что ASOF не просто исполняет условие t1.event_time > t2.event_time, а именно ищет БЛИЖАЙШУЮ vtymie. дату в колонке 
-- event_time таблицы t2. ANY же просто наъодит первую попавшуюся дату, которая меньше. Смысл ASOF во временной аналитике, например,
-- найти ближайший по времени предыдущий заказ пользователя (хотя и оконки с этим справятся). По-настоящему раскрывается, когда
-- информация НЕ в одной таблице. В таком случае он позволит избежать декартового джойна (так как нужны все совпадения) с последующим
-- применением оконной функции в получившейся огромной таблице

-- Физические виды соединений. Введение.

-- создадим таблицы с нужной сортировкой
drop table if exists five_test; -- удалить таблицу, если что-то пошло не так
CREATE TABLE five_test (
    id UInt64,
    name_good String,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY id -- да, он реально физически отсортирует данные перед записью на диск по полю id
SETTINGS index_granularity = 8192; -- типы данных, конструкции ENGINE = MergeTree() и ORDER BY name_good будут разобраны позже

-- вставляем данные
INSERT INTO five_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000; 

drop table if exists six_test; -- удалить таблицу, если что-то пошло не так
CREATE TABLE six_test (
    id UInt64,
    name_good String,
    event_time DateTime
) ENGINE = MergeTree()
ORDER BY id
SETTINGS index_granularity = 8192; -- типы данных, конструкции ENGINE = MergeTree() и ORDER BY name_good будут разобраны позже

-- вставляем данные
INSERT INTO six_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000; 

-- джойним алгоритмом full_sorting_merge 
select *
from five_test t1
left join six_test t2
on t1.id = t2.id
settings join_algorithm = 'full_sorting_merge'
;

-- джойним алгоритмом hash - он используется по умолчанию
select *
from five_test t1
left join six_test t2
on t1.id = t2.id
settings join_algorithm = 'hash'
;

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- джойним алгоритмом%')
    and query not ilike '%system%'
    and type = 2
;








-------------- Куски данных. Засечки. Индексы. Гранулярность. Иммутабельность кусков. Слияния.
-------------- Мутации. Версионирование данных как best practies.

select * from system.parts where table = 'first_test';

-- видим в поле path /var/lib/clickhouse/store/d5e/d5ec8421-4a46-4cbf-b17e-f1a5fc2fe94f/all_1_1_0/
-- это и есть путь, по которому можно найти файлы таблицы и посотреть, что из себя представляет сам таблица

-- тест считанных строк с диска
select count() from first_test;

-- видим одну строку - он просто прочитал файл count.txt
select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- тест считанных строк с диска%')
    and query not ilike '%system%'
    and type = 2
;

-- тест потребления при считывании разного количества колонок
select id from first_test;

-- тест потребления при считывании разного количества колонок
select id, name_good from first_test;

-- видим, что когда читаем несколько колонок - потребление растет, это доказательство колоночного хранения
select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- тест потребления при считывании разного количества колонок%')
    and query not ilike '%system%'
    and type = 2
;

-- Засечки, индекс и гранулярность тесно связаны. SETTINGS index_granularity = 8192
select id from first_test limit 1; -- ожидаем же, что будет считана с диска одна строка, да?

-- видим, что было считано 8192 строки. По той причине, что каждая колонка в пределах файла
-- .bin хранится блоками по 8192 строки. Засечки - адреса этих блоков для КАЖДОЙ колонки таблицы.
-- Это файл .cmrk3
-- .cidx - индекс по полю name_good. Создается записью ORDER BY name_good при создании таблицы.
-- Индекс хранится в оперативной памяти, нужен для идентификации нужного блока данных, и представляет из себя хранения первого значения
-- колонки из каждого блока данных. А чтобы вычленить этот блок данных из .bin нужны засечки. 
select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- Засечки, индекс и гранулярность тесно связаны. SETTINGS index_granularity = 8192%')
    and query not ilike '%system%'
    and type = 2
;

-- Добавляем условие НЕ по индексу
select id from first_test where id = 4362037789598322025;

-- Видим, что были прочитна все 100 000 строк, так как без индекса клик не знает, какой блок данных ему нужен и читает и обратаывает
-- всю таблицу
select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- Добавляем условие НЕ по индексу%')
    and query not ilike '%system%'
    and type = 2
;

-- Добавляем условие ПО индексу
select id, name_good from first_test where name_good = ' & M@#L?';

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- Добавляем условие ПО индексу%')
    and query not ilike '%system%'
    and type = 2
;

------ Куски данных иммутабельны (не изменяемы)
-- добавим новую запись в таблицу

insert into first_test values (1, 'dsadjgsa', now());

-- смотрим количество кусков данных
select * from system.parts where table = 'first_test';

select * from first_test where name_good = 'dsadjgsa';

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%where name_good = \'dsadjgsa\'%')
    and query not ilike '%system%'
    and type = 2
;

OPTIMIZE TABLE first_test FINAL; -- вызываем слияние кусков данных

-- Мутации (не правильный способ)
alter table first_test delete where name_good = 'dsadjgsa';

-- смотрим количество кусков данных
select * from system.parts where table = 'first_test';

-- append only - концепция, при которой при необходимости изменения каких-либо записей производится не update/delete, а insert
insert into first_test values (4362037789598322025, 'new string', '1980-12-30 13:20:50');

-- а как отличать строки? помогает версионирование данных. Самый элегантный способ - dt_load DateTime DEFAULT now()
-- создаем таблицу с колонкой даты, которая заполняется автоматически
drop table if exists seven_test;
CREATE TABLE seven_test (
    id UInt64,
    name_good String,
    event_time DateTime,
    dt_load DateTime DEFAULT now() -- по умолчанию будет вставлено значение now(), если не указано иное
) ENGINE = MergeTree()
ORDER BY id 
SETTINGS index_granularity = 8192;

-- вставляем данные
INSERT INTO seven_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000; 

-- вставляем новую версию данных
insert into seven_test values (398721497434373, 'new string', '1977-09-25 08:37:12'); -- неправильный вариант

-- правильный вариант - явно указывать колонки для соответствия, не всегда парсер оптимально понимает, что и куда вставлять
INSERT INTO seven_test (id, name_good, event_time)
VALUES (398721497434373, 'new string', '2038-12-24 02:18:58');

-- видим, что новая запись появилась, и ее легко отличить от старой по dt_load
select * from seven_test where id = 398721497434373;

-- первый способ отобрать нужную запись - берем с наибольшим dt_load
select * from seven_test where id = 398721497434373 order by dt_load desc limit 1;

-- второй способ отобрать нужные записи (если id несколько) - берем с наибольшим dt_load и добавляем LIMIT BY
select * from seven_test order by dt_load desc limit 1 by id;

-- третий способ - самый частый на практике, группируем и вычленяем нужное.
select id, argMax(name_good, dt_load)
from seven_test
where id = 398721497434373
group by id 
;







-------------- Семейство движков MergeTree
-- ReplacingMergeTree

drop table if exists eight_test;
CREATE TABLE eight_test (
    id UInt64,
    name_good String,
    event_time DateTime,
    dt_load DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(dt_load) -- "схлопни" дубли по тому полю, которое указано в ORDER BY
ORDER BY id 
SETTINGS index_granularity = 8192;

-- вставляем данные
INSERT INTO eight_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000; 

-- вставляем новую версию данных
INSERT INTO eight_test (id, name_good, event_time)
VALUES (398721497434373, 'new string', '1977-09-25 08:37:12');

-- видим, что дубли не схлопнулись сразу же. Конечно же, они схдопнутся во время фонового слияния. Но есть хак.
select * from eight_test where id = 398721497434373;

-- FINAL - ключевок слово, позволяющее схлопнуть дубли ТОЛЬКО в рамках запроса. Физически слияния кусков не вызывает, а лишь
-- удаляет дубли из самого запроса, чтобы отобразить вам результат запроса SELECT без дублей.
select * from eight_test final where id = 398721497434373;

 -- вызываем слияние кусков данных, теперь понятно, что делает ключевок слово FINAL - дедупликацию
OPTIMIZE TABLE eight_test FINAL;

select * from eight_test where id = 398721497434373;

-- интересно, а из MergeTree команда OPTIMIZE TABLE ... FINAL удалит дубли при слиянии?

-- вставляем данные
INSERT INTO seven_test (id, name_good, event_time)
VALUES (398721497434373, 'new string', '2038-12-24 02:18:58');

-- смотрим, что дублей много
select * from seven_test where id = 398721497434373;

 -- вызываем слияние кусков данных
OPTIMIZE TABLE seven_test FINAL;

select * from seven_test where id = 398721497434373;









-------------- Партиционирование

drop table if exists nine_test;
CREATE TABLE nine_test (
    id UInt64,
    name_good String,
    event_time DateTime,
    dt_load DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree()
ORDER BY id 
PARTITION BY toStartOfYear(event_time) -- разбиваем на директории по году
SETTINGS index_granularity = 8192;

-- вставляем данные - легендарный в кругах клика too many parts. Нельзя одновременно писать более чем в 100 кусков
INSERT INTO nine_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000; 

-- вставляем данные, убрав ограничение на количество обрабатываемых кусков
INSERT INTO nine_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000
settings max_partitions_per_insert_block = 1000; -- поставим 1000, для теста достаточно

-- смотрим, сколько теперь кусков
select * from system.parts where table = 'nine_test';

-- партиционирование нужно, чтобы снизить нагрузку при запросах. В 99% случаев на практике партиционирование делается именно по дате.
-- при задании партиционирования создается в директории куса данных дополнительный индекс minmax по колонке партиционирования. Он нужен для
-- того, чтобы запомнить минимальную и максимальную допустимую дату в партиции. При запросах типа SELECT с указанием конкретной даты
-- клик пойдет по папкам опрашивать индекс minmax, чтобы найти нужную партицию. Это многократно снижает потребление ресурсов, но увеличивает
-- нагрузку на файловую систему и иногда вызывает легендарный too many parts (у клика ограничение - максимум 100 партов за раз можно
-- задействовать в DML - запросах, таких как insert, delete и т.д.)

-- смотрим потребление при партиционировании и условии по ключу партиционирования
select *, _partition_id -- "магическая" колонка) позволяет увидеть id партиции, которая будет считана.
from nine_test
where event_time > '1980-01-01 03:00:00'
    and event_time < '1980-12-31 00:00:00'
limit 100;

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- смотрим потребление при партиционировании и условии по ключу партиционирования%')
    and query not ilike '%system%'
    and type = 2
;










-------------- TTL - Time To Life

drop table if exists ten_test;
CREATE TABLE ten_test (
    id UInt64,
    name_good String,
    event_time DateTime,
    dt_load DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree()
ORDER BY id 
PARTITION BY toStartOfYear(event_time) 
TTL toStartOfYear(event_time) + interval 3 year -- даем жить данным только 3 года
SETTINGS index_granularity = 8192;

-- вставляем данные, убрав ограничение на количество обрабатываемых кусков
INSERT INTO ten_test (id, name_good, event_time)
SELECT * FROM generateRandom('a UInt64, b String, c DateTime', 1, 10, 2) LIMIT 1000000
settings max_partitions_per_insert_block = 1000; -- поставим 1000, для теста достаточно

-- смотрим, сколько кусков данных

select * from system.parts where table = 'ten_test';

-- а теперь смотрим только активные парты, видим 2024 год как минимальный - сработал TTL
select * from system.parts where table = 'ten_test' and active=1 order by partition;

-- самый правильный способ создания таблицы
drop table if exists eleven_test;
CREATE TABLE eleven_test (
    id UInt64,
    name_good String,
    event_time DateTime,
    dt_load DateTime DEFAULT now() -- версионирование работает за нас автоматически
) ENGINE = ReplacingMergeTree() -- схлопываем дубли, оставляя последнюю вставку
ORDER BY id -- сортируем и делаем индекс по самой часто используемой в запросах сущности
PARTITION BY toStartOfYear(event_time) -- партиционирование по самой важной дате - как правило, дата события из таблицы фактов
TTL toStartOfYear(event_time) + interval 3 year -- даем жить данным только 3 года, место на диске не бесконечное
SETTINGS 
    index_granularity = 8192, -- гранулярность индекса 8192, что на практике почти никогда не меняется
    ttl_only_drop_parts = 1 -- вместо чтения и удаления выборочно строк из партиции будет дропать всю партицию, когда она "протухнет"
;

-- рассмотрим следующий важный момент. Во время слияния кусков данных, они, конечно же, сливаются исключительно в рамках партиции.
-- А это значит, что если в индексе id, который есть в нескольких партициях - то все равно будут дубли даже после операции слияния.
-- поэтому FINAL, либо group by + argMax() наше все при работе с движком replacing

INSERT INTO ten_test (id, name_good, event_time)
VALUES (2443796381037073, 'new string', '2024-07-03 16:42:52')
    , (2443796381037073, 'new string', '2026-07-03 16:40:52')
;

-- final гарантировано схлопнет дубли
select * from ten_test final where id = 2443796381037073;

 -- вызываем слияние кусков данных + дедупликацию
OPTIMIZE TABLE ten_test FINAL;

-- ну и видим дубли - они из разных партиций, слияния такое не схлопнет
select * from ten_test where id = 2443796381037073;






-------------- MV - Materialized Views. 
-- Мат вьюхи - это сущности, которые позволяют "перехватывать" данные, которые пытаются вставить в таблицу только операцией insert.
-- Такой недотриггер от мира классических СУБД. А срабатывает лишь на insert, кстати, потому что append only, с мутациями никто заморачиваться
-- не будет. Исопльзуютсян а практике для разных целей - от переливки данных из исторической таблицы с движком MergeTree в так называемую
-- "current" таблицу (таблица текущих состояний) с движком replacing, до интеграции с внешними источники, аля кафка.

-- создаем мат вьюху, которая будет переливать данные из истории в карент. Так как 11 таблицу не наполняли - ну вот и наполним
CREATE MATERIALIZED VIEW eleven_test_mv
TO eleven_test AS
SELECT *
FROM first_test;

-- вставляем данные в первую таблицу
INSERT INTO first_test (id, name_good, event_time)
VALUES (2443796381037073, 'new string', '2024-07-03 16:42:52')
    , (2443796381037073, 'new string', '2026-07-03 16:40:52')
;

-- смотрим, что они появились в одиннадцатой
select * from eleven_test;








-------------- Словари.
-- Словари - это сущности, которые позволяют хранить таблицу целиком в оперативной памяти. Как правило, это как раз-таки таблицы измерений
-- Таблицы измерений на практике - это редко изеняемые таблицы. Например, таблица заказов с id заказов и датой - это таблица фактов. А 
-- таблица, в которой будут описаны все возможные статусы заказа - таблица измерений. Она многократно меньше таблицы фактов и, чтобы
-- не делать с ней джойн и нужны словари. Такая таблица целиком помещается в оперативную память

CREATE DICTIONARY four_test_dict
(
    id     UInt64,
    name_good   String
)
PRIMARY KEY id -- ключ, по которому к словарю будет осуществляться доступ
SOURCE(CLICKHOUSE(table 'four_test')) -- источник данных для словаря
LIFETIME(0) -- словарь никогда не будет автоматически обновляться. но можно и настроить, условно на обновление раз в минуту - ставим 60
LAYOUT(FLAT(INITIAL_ARRAY_SIZE 1000 MAX_ARRAY_SIZE 5000000));
-- FLAT - словарь хранится в RAM в виде плоского массива
-- INITIAL_ARRAY_SIZE - начальный размер массива оценивается в 1000 элементов. по умолчанию настройка равна 1024. Берем с запасом относительно
--                      200, чтобы при переаспределении RAM снизить накладные расходы, так как по словарь уже зарезервировано 1000 элементов
-- MAX_ARRAY_SIZE - ограничение максимального размера словаря, чтобы не убить сервер


-- так как словарь в RAM - при перезагрузке сервера он потеряется, и при повторном подъеме автоматически словари не грузятся в RAM.
-- нужно поднять их ручками. Для этого даем команду:
SYSTEM RELOAD DICTIONARIES;

select *
    , dictGet('four_test_dict', 'name_good', id) name_good_from_dict
from second_test
;

-- также увидели ошибку, которая заключается в том, чт оесли мы сами не дедуплицировали данные в таблице перед созданием словаря - то при
-- создании словаря будет взята лишь одна строка по ключу словаря, причем абсолютно рандомная, а не последняя по дате. Поэтому важно
-- создавать таблицу под словарь правильно. Вот реальный пример таблицы для словаря на практике:

create table dict_order_status
(
    status_id UInt16, -- статус заказа
    description String -- описание статуса
)
ENGINE = MergeTree
ORDER BY status_id
;

insert into dict_order_status (status_id, description) values
(1, 'Создан'),
(2, 'Оплачен'),
(3, 'Собран'),
(4, 'Отправлен'),
(5, 'Доставлен'),
(6, 'Получен'),
(7, 'Отменен, отказ клиента'),
(8, 'Отменен, брак')
;






-------------- CTE. Времянки.
-- в клике СТЕ - это не СТЕ. Это аналог питонячей функции - код СТЕ будет вызываться столько раз, сколько он встречается в коде. Поэтому
-- результат может быть не предсказуемым. Смотри пример

WITH cte_numbers AS (
    SELECT num
    FROM generateRandom('num UInt64', NULL)
    LIMIT 1000000
)
SELECT count()
FROM cte_numbers
WHERE num IN (SELECT num FROM cte_numbers)
;

-- очевидно, что при создании СТЕ на миллион записей мы ожидаем, что при обращении СТЕ саму на себя с проверкой на соответствие
-- колонки num мы получим тот самый миллион записей. Но получаем НЕ миллион, потому что cte_numbers вызывается дважды и дважды
-- генерит рандомные последовательности, которые один в один никогда не совпадут. Поэтому лучше использовать вместо СТЕ "времянки" - 
-- таблицы, хранящиеся в оперативной памяти

-- создаем времянку
create temporary table t1 as (
    SELECT num
    FROM generateRandom('num UInt64', NULL)
    LIMIT 1000000
)
;

-- и вот теперь получаем миллион. ВАЖНО - запросы нужно выполнять строго одновременно, так как времянки существуют только в рамках
-- запроса. Как только второй запрос исполнится - времянка автоматически удалиться. Чтобы запустить оба запроса сразу - alt + x
-- или стандартный ctrl + enter
SELECT count()
FROM t1
WHERE num IN (SELECT num FROM t1)
;







-------------- LowCardinality
-- Если в колонке низкая кардинальность (до 100 000 уникальных значений), то выгоднее хранить колонку в словарном виде. Для этого существует
-- тип данных LowCardinality. Физически в таблице вместо реальных значений колонки будет хранится цифра. А рядом будет создан словарь с
-- соответствием фицра-значение. И при обращении к колонке будет произведена обратная трансформация - вместо цифры из словаря будет получено
-- соответствующее значение. Это чем-то реально похоже на работу словарей, только в разрезе колонки, а не таблицы

-- примерно вот такой словарь будет создан под капотом при LowCardinality(String)
{
 1: 'мужчина',
 2: 'женщина'    
}

-- добавляем колонку, по умолчанию добавится последней
ALTER TABLE five_test
ADD COLUMN test_col String;

-- а теперь заполняем рандомно либо мужчина, либо женщина
ALTER TABLE five_test
UPDATE test_col = If(randBernoulli(0.5), 'мужчина', 'женщина') WHERE 1=1;

-- тест ресурсов LowCardinality. Так как бобер сам добавляет limit 200, обернем запрос, иначе не увидим разницу
select test_col from five_test limit 1000000;

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- тест ресурсов LowCardinality%')
    and query not ilike '%system%'
    and type = 2
;

-- а теперь тоже самое, только создадим колонку с типом LowCardinality(String)
-- добавляем колонку, по умолчанию добавится последней
ALTER TABLE five_test
ADD COLUMN test_lowcod LowCardinality(String);

-- а теперь заполняем рандомно либо мужчина, либо женщина
ALTER TABLE five_test
UPDATE test_lowcod = If(randBernoulli(0.5), 'мужчина', 'женщина') WHERE 1=1;

-- тест ресурсов LowCardinality
select test_lowcod from five_test limit 1000000;

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- тест ресурсов LowCardinality%')
    and query not ilike '%system%'
    and type = 2
;

-- также
SELECT
    name AS column,
    formatReadableSize(sum(data_compressed_bytes)) AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 3) AS compression_ratio
FROM system.columns
WHERE table = 'five_test'
  AND name IN ('test_col', 'test_lowcod')
GROUP BY name;









-------------- Nullable
-- ну и очень простой совет - избегайте Nullable. Для того, что хранить "ничто", клику придется под капотом создать специальный файл.
-- это абсолютно бессмысленно и в 99% случаев увеличивает как потребление ресурсов при выполнении запросов, так и засоряет жесткий диск

-- добавляем колонку, по умолчанию добавится последней
ALTER TABLE five_test
ADD COLUMN test_col_null Nullable(String);

-- а теперь заполняем рандомно либо мужчина, либо женщина
ALTER TABLE five_test
UPDATE test_col_null = If(randBernoulli(0.5), 'мужчина', Null) WHERE 1=1;

-- тест ресурсов Nullable
select test_col from five_test limit 1000000;
-- тест ресурсов Nullable
select test_col_null from five_test limit 1000000;

select query_id, query, read_rows, read_bytes, result_rows, result_bytes, memory_usage, query_duration_ms 
from system.query_log
where 1=1
    and (query ilike '%-- тест ресурсов Nullable%')
    and query not ilike '%system%'
    and type = 2
;

-- ищем созданный файл
select * from system.parts where table = 'five_test';