--  Data Cleaning -- 

SELECT *
FROM layoffs;

-- 1. Remove duplicates 
-- 2. Standadize the data
-- 3. Nulle values or blank values
-- 4. Remove any Columns 

CREATE TABLE layoff_staging
LIKE layoffs;
-- in case delete columns

select *
from layoff_staging;

INSERT layoff_staging
SELECT *
FROM layoffs;


-- 1. Remove Duplicates

# First let's check for duplicates

SELECT *,
ROW_NUMBER() OVER (
PArtition BY company, location, total_laid_off, `date`) AS row_num
FROM layoff_staging;
 
 -- identifying the dups by seeing if mult rows
WITH duplicate_cte AS 
(
SELECT *,
ROW_NUMBER() OVER (
PArtition BY company, location, total_laid_off, `date`, stage, country, funds_raised_millions ) AS row_num
FROM layoff_staging
)

SELECT * FROM duplicate_cte
WHERE row_num > 1;

-- casper has dupes, but we want to keep one
SELECT * 
FROM layoff_staging
WHERE company = 'Casper';

-- cannot delete from cte in mysql so create another database an edit that
-- copy to clipboard, create statement

CREATE TABLE `layoff_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

select *
from layoff_staging2;

INSERT INTO layoff_staging2
SELECT *,
ROW_NUMBER() OVER (
PArtition BY company, location, total_laid_off, `date`, stage, country, funds_raised_millions ) AS row_num
FROM layoff_staging;

SELECT * 
FROM layoff_staging2
WHERE row_num > 1;

DELETE  
FROM layoff_staging2
WHERE row_num > 1;

-- 2. Standardize Data
SELECT company, trim(company)
FROM layoff_staging2;

-- clear white space
UPDATE layoff_staging2
SET company = TRIM(company);

-- now we look at industry, crypto comes twice and null too
SELECT DISTINCT industry
FROM layoff_staging2
ORDER BY 1;

SELECT *
FROM layoff_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoff_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- no more cryptocurrency
SELECT DISTINCT industry
FROM layoff_staging2
ORDER BY 1;

-- check location, country, etc
SELECT DISTINCT location
FROM layoff_staging2
ORDER by 1;

-- seems fine
SELECT DISTINCT country
FROM layoff_staging2
ORDER by 1;

-- US has a dot, use trailing

SELECT DISTINCT location, TRIM(TRAILING '.' FROM country)
FROM layoff_staging2
ORDER by 1;

UPDATE layoff_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States';

-- data visualiztion, need to change date from text

SELECT `date`,
str_to_date(`date`, '%m/%d/%Y')
FROM layoff_staging2;

UPDATE layoff_staging2
SET `date` = str_to_date(`date`, '%m/%d/%Y');

SELECT `date`
FROM layoff_staging2;

-- changeing data type. NEVER Do THIS ON BASE TABLE

ALTER TABLE layoff_staging2
MODIFY column `date` DATE;

SELECT *
from layoff_staging2;

-- 3. Look at Null Values

-- the null values in total_laid_off, percentage_laid_off, and funds_raised_millions all look normal. I don't think I want to change that
-- I like having them null because it makes it easier for calculations during the EDA phase
-- so there isn't anything I want to change with the null values

SELECT *
from layoff_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
from layoff_staging2
WHERE industry IS NULL
OR industry = '';

-- airbnb has a travel, but one is not populated
SELECT *
from layoff_staging2
WHERE company = 'Airbnb' ;

-- some didnt work so changing all blanks to null  
UPDATE layoff_staging2
SET industry = NULL
WHERE industry = '';

-- select before update to test, lets do a join
SELECT t1.industry, t2.industry
from layoff_staging2 t1
JOIN layoff_staging2 t2
	ON t1.company = t2.company
WHERE (t1.industry is NULL OR t1.industry = '')
AND t2.industry is NOT NULL;

-- update
UPDATE layoff_staging2 t1
JOIN layoff_staging2 t2
	ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE (t1.industry is NULL)
AND t2.industry is NOT NULL;

SELECT *
from layoff_staging2
WHERE industry IS NULL
OR industry = '';

-- Bailey's still null bc it doesnt have another
-- 4. remove any columns and rows we need to

SELECT *
from layoff_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE
from layoff_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *
from layoff_staging2;

ALTER TABLE layoff_staging2
DROP COLUMN row_num;

-- Exploratory Data Analysis

SELECT MAX(total_laid_off), MAX(percentage_laid_off)
from layoff_staging2;

SELECT *
FROM layoff_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- total laid off
SELECT company, SUM(total_laid_off)
from layoff_staging2
GROUP BY company
ORDER BY 2 DESC; -- order by second column

-- looking at date range
SELECT min(`date`), max(`date`)
from layoff_staging2;

-- group by industry
SELECT industry, SUM(total_laid_off)
from layoff_staging2
GROUP BY industry
ORDER BY 2 DESC; -- order by second column

-- by country
SELECT country, SUM(total_laid_off)
from layoff_staging2
GROUP BY country
ORDER BY 2 DESC; -- order by second column

-- by year
SELECT YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC; -- order by 1st column

-- by stage
SELECT stage, SUM(total_laid_off)
from layoff_staging2
GROUP BY stage
ORDER BY 1 DESC; -- order by second column

-- rolling sum of layoffs
-- this doesnt show year
SELECT substring(`date`,6,2) AS `MONTH`, SUM(total_laid_off)
from layoff_staging2
GROUP BY `MONTH`;

SELECT substring(`date`,1,7) AS `MONTH`, SUM(total_laid_off)
from layoff_staging2
WHERE substring(`date`,1,7) is not NULL
GROUP BY `MONTH`
ORDER BY 1 ASC;

WITH Rolling_Total AS
(
SELECT substring(`date`,1,7) AS `MONTH`, SUM(total_laid_off) AS total_off
from layoff_staging2
WHERE substring(`date`,1,7) is not NULL
GROUP BY `MONTH`
ORDER BY 1 ASC
)
SELECT `MONTH`, total_off,
SUM(total_off) OVER(ORDER BY `MONTH`) as rolling_total
FROM Rolling_Total;

-- by company by year
SELECT company, YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC; -- order by third column

-- lets rank them
WITH Company_Year AS
(SELECT company, YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY company, YEAR(`date`)
)
SELECT *
FROM Company_Year;

-- rename columns
WITH Company_Year (company, years, total_laid_off) AS
(SELECT company, YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY company, YEAR(`date`)
)
SELECT *
FROM Company_Year;

-- rank them
WITH Company_Year (company, years, total_laid_off) AS
(SELECT company, YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY company, YEAR(`date`)
)
SELECT *, DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
FROM Company_Year
WHERE years is not NULL
ORDER BY Ranking ASC;

-- we want top 5 so lets do a anothe cte
-- rank them
SELECT company, YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY company, YEAR(`date`)
ORDER BY 3 DESC; -- order by third column

WITH Company_Year (company, years, total_laid_off) AS
(SELECT company, YEAR(`date`), SUM(total_laid_off)
from layoff_staging2
GROUP BY company, YEAR(`date`)
), Company_Year_Rank AS
	(
	SELECT *, DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
	FROM Company_Year
	WHERE years is not NULL
	)
SELECT *
FROM Company_Year_Rank
WHERE Ranking <= 5
;
