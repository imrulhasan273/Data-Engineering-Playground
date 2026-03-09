-- ─────────────────────────────────────────────────────────────────────────────
-- 02_word_count.pig — Classic Word Count in Pig Latin
-- Run: pig -x mapreduce 02_word_count.pig
-- ─────────────────────────────────────────────────────────────────────────────

-- Step 1: Load the text file (one line per record)
lines = LOAD '/hive/raw/employees/employees.csv'
  USING TextLoader()
  AS (line:chararray);

-- Step 2: Tokenize each line into words
words = FOREACH lines GENERATE
  FLATTEN(TOKENIZE(LOWER(line))) AS word:chararray;

-- Step 3: Filter out empty strings and short tokens
filtered = FILTER words BY SIZE(word) > 1;

-- Step 4: Group all identical words together
grouped = GROUP filtered BY word;

-- Step 5: Count occurrences
word_count = FOREACH grouped GENERATE
  group      AS word:chararray,
  COUNT(filtered) AS count:long;

-- Step 6: Sort by count descending
sorted = ORDER word_count BY count DESC;

-- Step 7: Show top 20
top20 = LIMIT sorted 20;
DUMP top20;

-- Step 8: Store full results
STORE word_count INTO '/pig/output/wordcount'
  USING PigStorage('\t');
