-- Data Checks and Data Preparation

SELECT * from artist LIMIT 5; 
SELECT * from canvas LIMIT 5;
SELECT * from museum LIMIT 5;
SELECT * from museum_hours LIMIT 5;
SELECT * from work LIMIT 5;
SELECT * from subject LIMIT 5;
SELECT * from product_size LIMIT 5;

-- Filtering duplicate entries and storing into new Table work_info
SELECT DISTINCT *
INTO work_info
FROM product_size;

-- Data Standardization for country table in museum table
UPDATE museum
SET country = 'UK'
WHERE country = 'United Kingdom';

-- Creating Country look up Table (Used in last Question)

SELECT DISTINCT (nationality) from artist

CREATE TABLE country_lookup(
    nationality VARCHAR(255),
    country VARCHAR(255)
)

INSERT INTO country_lookup (Nationality, Country)
VALUES
    ('Belgian', 'Belgium'),
    ('German', 'Germany'),
    ('Italian', 'Italy'),
    ('Norwegian', 'Norway'),
    ('Swiss', 'Switzerland'),
    ('Dutch', 'Netherlands'),
    ('American', 'USA'),
    ('Canadian', 'Canada'),
    ('Japanese', 'Japan'),
    ('Spanish', 'Spain'),
    ('Flemish', 'Belgium'),
    ('Irish', 'Ireland'),
    ('French', 'France'),
    ('Mexican', 'Mexico'),
    ('English', 'UK'),
    ('Austrian', 'Australia'),
    ('Danish', 'Denmark'),
    ('Russian', 'Russia');
--------------------------------------------------------------------------------------
--1. Fetch all the paintings which are not displayed on any museums?

SELECT work.artist_id, artist.full_name, COUNT(*) as Painting_Not_In_Any_Museum 
    FROM work
    JOIN artist
    ON artist.artist_id = work.artist_id 
    WHERE work.museum_id is NULL
    GROUP BY work.artist_id, artist.full_name


--2. Are there museums without any paintings?
SELECT museum.name, museum.city, COUNT(work.work_id) 
    FROM museum
    JOIN work 
    ON museum.museum_id = work.museum_id
    GROUP BY museum.name, museum.city

--3. How many paintings have an asking price of more than their regular price?

with cte as (
    SELECT work.name, sale_price, regular_price,
    CASE WHEN product_size.sale_price > product_size.regular_price THEN 1 ELSE 0 END as high_asking_price 
    FROM product_size
    JOIN work 
    ON product_size.work_id = work.work_id
)

SELECT * from cte where high_asking_price = 1

--4. Identify the paintings whose asking price is less than 50% of its regular price
with cte as (
    SELECT work.name, sale_price, regular_price,
    CASE WHEN product_size.sale_price < (0.5 * product_size.regular_price) THEN 1 ELSE 0 END as less_than_50_percent 
    FROM product_size
    JOIN work 
    ON product_size.work_id = work.work_id
)

SELECT * from cte where less_than_50_percent = 1

--5. Which canva size costs the most?

select cs.label as canva, ps.sale_price
	from (select *
		  , rank() over(order by sale_price desc) as rnk 
		  from product_size) ps
	join canvas cs on cs.size_id::text=ps.size_id
	where ps.rnk=1;					 

--6. Fetch the top 10 most famous painting subject

SELECT COUNT(1) as Number_Of_Painting ,subject 
FROM subject GROUP BY subject
ORDER BY Number_Of_Painting DESC
LIMIT 10;


--7. Identify the museums which are open on both Sunday and Monday. Display museum name, city.

SELECT museum.name, museum.city, museum.state, museum.country
FROM museum 
JOIN museum_hours ON museum.museum_id = museum_hours.museum_id
WHERE museum_hours.day = 'Sunday' AND exists (SELECT 1 from museum_hours mh2
                                        where mh2.museum_id = museum.museum_id AND mh2.day = 'Monday');

--8. How many museums are open every single day?
with cte as (
    SELECT m.name, COUNT(mh.day) from museum m 
    JOIN museum_hours mh ON m.museum_id = mh.museum_id
    GROUP by name 
    HAVING COUNT(mh.day) = 7
)

SELECT count(1) from cte

-- 9. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

with cte as (
    SELECT a.full_name, COUNT(w.work_id) as Number_Of_Painting,
    RANK() over (ORDER by COUNT(w.work_id) DESC) as Popularity_Rank
    FROM artist a 
    JOIN work w ON a.artist_id = w.artist_id
    GROUP BY a.full_name
)

SELECT * from cte WHERE Popularity_Rank <=5;

-- 10. Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

with cte as (
    SELECT m.name, mh.day, mh.open, mh.close
                , to_timestamp(close,'HH:MI PM') - to_timestamp(open,'HH:MI AM') as duration,
                RANK() OVER( ORDER BY to_timestamp(close,'HH:MI PM') - to_timestamp(open,'HH:MI AM') DESC) Rnk
    FROM museum m 
    JOIN museum_hours mh ON m.museum_id = mh.museum_id 
)

SELECT * 
FROM cte WHERE Rnk = 1

-- 11. Which museum has the most no of most popular painting style

with cte as (
SELECT museum.name,work.museum_id, work.style, COUNT(1) as popularity
FROM work 
JOIN subject ON work.work_id = subject.work_id
JOIN museum ON museum.museum_id = work.museum_id
WHERE work.style is not NULL AND work.museum_id is not NULL
GROUP BY museum.name,work.museum_id, work.style
ORDER by  popularity DESC
)

SELECT * from cte LIMIT 1;

-- 12. Identify the artists whose paintings are displayed in multiple countries

With cte as (
    SELECT DISTINCT artist.full_name, museum.country
    FROM artist
    JOIN work on artist.artist_id = work.artist_id
    JOIN museum on work.museum_id = museum.museum_id
)
SELECT full_name, count(1) as number_of_countries, STRING_AGG(country, ', ') as Countries
from cte 
GROUP BY full_name 
having count(1)>1
ORDER BY 2 DESC

-- 13. Identify the artist and the museum where the most expensive and least expensive painting is placed. 
--     Display the artist name, sale_price, painting name, museum name, museum city and canvas label

with cte as (
    SELECT full_name as Artist_Name
    ,work.name as Painting_Name ,museum.name as Museum_Name
    ,museum.city as Museum_City, work.style as Work_Style, product_size.regular_price as Price,
    ROW_NUMBER() OVER (ORDER BY product_size.regular_price DESC) as rnk
    FROM artist
    JOIN work ON artist.artist_id = work.artist_id
    JOIN museum ON work.museum_id = museum.museum_id
    JOIN product_size ON product_size.work_id = work.work_id
)

SELECT Artist_Name, Painting_Name, Museum_Name, Museum_City, Work_Style, Price from cte where rnk = 1 or rnk = (SELECT COUNT(1) from cte)



-- 14. What's the average difference between the sale price and original price in percentage by Work Subject 

with cte as (
    SELECT work.style, ROUND(AVG(product_size.regular_price),2) as AVG_regular_Price, ROUND(AVG(product_size.sale_price),2) as AVG_sale_Price
    FROM work    
    JOIN product_size ON work.work_id = product_size.work_id 
    GROUP BY work.style
)

SELECT *,
       ROUND(((AVG_regular_Price - AVG_sale_Price) / NULLIF(AVG_regular_Price, 0)) * 100, 2) as Discount
FROM cte;


-- 15. In an effort to celebrate and showcase the rich artistic heritage of various countries, 
-- a decision has been made to acquire a collection of paintings which are currently not featured in any museums. 
-- The focus is on displaying these artworks in museums located in the birthplaces of the respective artists. 
-- For this initative, each country will incur costs associated with acquiring the selected paintings from a central repository at the Sale Price.
-- Write a SQL query to show Country, Museum, work.style , Number of Paintings , Cost to Incure 
-- If a country has multiple museum then number of painting belonging should be divided accordingly

-- Step 1: Linking artist, country_lookup, work, work_info

-- Work_info Table contains painting with multiple sizes. But the each country is only interested to keep 2 copies

SELECT * INTO work_info_filtered
FROM (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY work_id ORDER BY regular_price DESC) as rn
    FROM work_info
) AS Top_2_Paintings
WHERE rn <= 2;

-- Step 2: Query to determine unassigned paintings

CREATE OR REPLACE VIEW unassigned_paintings as (
    SELECT 
    ROW_NUMBER() OVER (ORDER BY artist.artist_id, work.work_id, work_info_filtered.size_id) AS surrogate_key,
    artist.artist_id,
    work.work_id, 
    work_info_filtered.size_id,
    work.museum_id,
    canvas.label,
    artist.style, 
    artist.full_name, 
    artist.nationality, 
    country_lookup.country,
    work.name as painting_name,
    work_info_filtered.sale_price as sale_price,
    work_info_filtered.regular_price as regular_price
    FROM artist
    JOIN country_lookup ON artist.nationality = country_lookup.nationality
    JOIN work ON artist.artist_id = work.artist_id
    JOIN work_info_filtered ON work.work_id = work_info_filtered.work_id
    JOIN canvas on canvas.size_id::text=work_info_filtered.size_id
    WHERE work.museum_id is NULL
)

SELECT
    unassigned_paintings.country,
    COUNT(DISTINCT museum.name) as Number_of_Museums,
    COUNT(surrogate_key) AS Number_of_Paintings,
    TO_CHAR(AVG(unassigned_paintings.sale_price), '$999,999,999.99') AS Average_Cost_Of_Paintings,
    TO_CHAR(SUM(unassigned_paintings.sale_price), '$999,999,999.99') AS Acquiring_Cost
FROM unassigned_paintings
JOIN museum ON unassigned_paintings.country = museum.country
GROUP BY
    unassigned_paintings.country
ORDER BY SUM(unassigned_paintings.sale_price) DESC;