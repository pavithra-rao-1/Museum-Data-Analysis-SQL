select * from artist;
select * from canvas_size;
select * from image_link;
select * from museum;
select * from museum_hours;
select * from product_size;
select * from subject;
select * from work;


/*
EXEC sp_rename 'museum_hours.day', 'day_name', 'COLUMN';
EXEC sp_rename 'museum_hours.open', 'opening_time', 'COLUMN';
EXEC sp_rename 'museum_hours.close', 'closing_time', 'COLUMN';
*/


--1. Fetch all the paintings which are not displayed on any museums
SELECT W.name, A.full_name FROM work W JOIN artist A ON A.artist_id = W.artist_id WHERE museum_id IS NULL;

--2. Are there museums without any paintings?
select * from museum m where not exists (select 1 from work w where w.museum_id=m.museum_id)

--3. How many paintings have an asking price of more than their regular price?
SELECT COUNT(*) Count FROM product_size WHERE sale_price > regular_price;

--4. Identify the paintings whose asking price is less than 50% of its regular price
SELECT COUNT(*) Count FROM product_size WHERE sale_price < (0.5 * regular_price);

--5. Which canva size costs the most?
SELECT PS.size_id, CS.height, CS.width, CS.label from 
(SELECT *, RANK() OVER(ORDER BY sale_price desc) Rnk FROM product_size) PS 
JOIN canvas_size CS ON PS.size_id = CS.size_id WHERE PS.Rnk = 1;

--6. Delete duplicate records from work, product_size, subject and image_link tables
--work
SELECT work_id, name, artist_id, style, museum_id, COUNT(*) Count FROM work GROUP BY work_id, name, artist_id, style, museum_id  HAVING COUNT(*) > 1;

WITH rowranked AS (
    SELECT work_id, name, artist_id, style, museum_id,
           ROW_NUMBER() OVER (PARTITION BY work_id, name, artist_id, style, museum_id ORDER BY work_id) AS row_num
    FROM work
)
DELETE FROM rowranked
    WHERE row_num = 2;

--product_size
SELECT work_id, size_id, sale_price, regular_price, COUNT(*) Count FROM product_size
GROUP BY work_id, size_id, sale_price, regular_price HAVING COUNT(*) > 1;

WITH SALE AS (SELECT work_id, size_id, sale_price, regular_price,
ROW_NUMBER() OVER(PARTITION BY work_id, size_id, sale_price, regular_price ORDER BY size_id) rowrnk FROM product_size)
DELETE FROM SALE WHERE rowrnk > 1;

--subject
SELECT work_id, subject, COUNT(*) FROM subject GROUP BY work_id, subject HAVING COUNT(*) > 1;

WITH SALE AS(SELECT work_id, subject, ROW_NUMBER() OVER(PARTITION BY work_id, subject ORDER BY work_id) rowrnk
FROM subject) DELETE from SALE WHERE rowrnk > 1;

--image_link tables
SELECT work_id, url, thumbnail_large_url, thumbnail_small_url, COUNT(*) FROM image_link 
GROUP BY work_id, url, thumbnail_large_url, thumbnail_small_url HAVING COUNT(*) > 1;

WITH SALE AS(SELECT work_id, url, thumbnail_large_url, thumbnail_small_url, 
ROW_NUMBER() OVER(PARTITION BY work_id, url, thumbnail_large_url, thumbnail_small_url 
	ORDER BY work_id) rowrnk
FROM image_link) DELETE from SALE WHERE rowrnk > 1;


--7. Identify the museums with invalid city information in the given dataset
SELECT name, city FROM museum WHERE city like '%[0-9]%';

--8. Museum_Hours table has 1 invalid entry. Identify it and remove it
SELECT museum_id, day_name, COUNT(*) FROM museum_hours GROUP BY museum_id, day_name HAVING COUNT(*) > 1;

WITH SALE AS(SELECT museum_id, day_name, 
ROW_NUMBER() OVER(PARTITION BY museum_id, day_name 
	ORDER BY museum_id) rowrnk
FROM museum_hours) DELETE from SALE WHERE rowrnk > 1;

--9. Fetch the top 10 most famous painting subject
SELECT TOP 10 subject, COUNT(*) Count FROM subject GROUP BY subject ORDER BY Count desc;

--10. Identify the museums which are open on both Sunday and Monday. Display museum name, city.
SELECT M.name, M.city FROM museum M JOIN museum_hours MH ON M.museum_id = MH.museum_id WHERE MH.day_name IN ('Sunday','Monday');

--11. How many museums are open every single day?
SELECT M.name, M.city FROM museum M JOIN museum_hours MH ON M.museum_id = MH.museum_id WHERE MH.day_name IN ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');

--12. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
WITH POP AS(SELECT museum_id, COUNT(*) Count FROM work WHERE museum_id IS NOT NULL GROUP BY museum_id)
SELECT TOP 5 P.museum_id, M.name, M.city, P.Count FROM POP P JOIN museum M ON P.museum_id = M.museum_id
ORDER BY P.Count DESC;

--13. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
WITH POP AS(SELECT artist_id, COUNT(name) Count FROM work GROUP BY artist_id)
SELECT TOP 5 P.artist_id, A.full_name, P.Count FROM POP P JOIN artist A ON P.artist_id = A.artist_id
ORDER BY Count desc;

--14. Display the 3 least popular canva sizes
WITH POP AS (SELECT size_id, COUNT(*) Count FROM product_size GROUP BY size_id)
SELECT TOP 3 CS.label, P.size_id, P.Count 
FROM canvas_size CS JOIN POP P ON CAST(CS.size_id AS nvarchar) = P.size_id
ORDER BY P.Count ASC;

--15. Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
WITH LONG AS (SELECT museum_id, day_name, opening_time, closing_time, DATEDIFF(MINUTE, opening_time, closing_time) Working_time,
RANK() OVER(ORDER BY DATEDIFF(MINUTE, opening_time, closing_time)) ROWRNK
FROM museum_hours)
SELECT M.name, M.state, L.day_name, L.Working_time FROM LONG L JOIN museum M ON L.museum_id = M.museum_id;

--16. Which museum has the most no of most popular painting style?
WITH POP AS(SELECT museum_id, style, COUNT(museum_id) Count,
	RANK() OVER(ORDER BY COUNT(museum_id) DESC) ROWRNK
	FROM work WHERE museum_id IS NOT NULL GROUP BY style, museum_id)
SELECT M.name, M.city, P.style, P.Count FROM museum M JOIN POP P ON P.museum_id = M.museum_id
WHERE P.ROWRNK = 1;

--17. Identify the artists whose paintings are displayed in multiple countries
WITH ART AS(SELECT W.artist_id, W.museum_id, M.name, M.country FROM work W JOIN museum M ON W.museum_id = M.museum_id)
SELECT A.artist_id, AR.full_name,
COUNT(DISTINCT A.country) Country_Count 
FROM ART A JOIN artist AR ON A.artist_id = AR.artist_id 
GROUP BY A.artist_id, AR.full_name
HAVING COUNT(DISTINCT A.country) > 1
ORDER BY Country_Count DESC;

--18. Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.
WITH CITY AS (SELECT country, city, COUNT(museum_id) No_of_Museums, 
RANK() OVER(ORDER BY COUNT(museum_id) DESC) ROWRNK
FROM museum GROUP BY country, city)
SELECT STRING_AGG(country, ', ') COUNTRIES, STRING_AGG(city, ', ') CITIES FROM CITY WHERE ROWRNK = 1;

--19. Identify the artist and the museum where the most expensive and least expensive painting is placed. 
--    Display the artist name, sale_price, painting name, museum name, museum city and canvas label
WITH ART AS(SELECT work_id, size_id, sale_price, 
	RANK() OVER(ORDER BY sale_price DESC) DESC_RNK,
	RANK() OVER(ORDER BY sale_price ASC) ASC_RNK FROM product_size)
SELECT ATS.full_name Artist_Name, M.name Museum, M.city City, W.name Painting_Name, C.label, A.sale_price 
						FROM ART A JOIN work W ON A.work_id = W.work_id 
								   JOIN artist ATS ON ATS.artist_id = W.artist_id
								   JOIN museum M ON M.museum_id = W.museum_id
								   JOIN canvas_size C ON CAST(C.size_id AS nvarchar) = A.size_id
	WHERE DESC_RNK = 1 OR ASC_RNK = 1 ORDER BY sale_price;

--20. Which country has the 5th highest no of paintings?
WITH PNT AS(SELECT museum_id, COUNT(DISTINCT work_id) No_of_Paintings, 
RANK() OVER(ORDER BY COUNT(DISTINCT work_id) DESC) ROWRNK
FROM work WHERE museum_id IS NOT NULL GROUP BY museum_id)
SELECT M.name, M.country FROM museum M JOIN PNT ON M.museum_id = PNT.museum_id WHERE PNT.ROWRNK = 5;

--21. Which are the 3 most popular and 3 least popular painting styles?
WITH POP AS (SELECT style, COUNT(style) Count, 
	RANK() OVER(ORDER BY COUNT(style) DESC) DESC_RNK,
	RANK() OVER(ORDER BY COUNT(style) ASC) ASC_RNK 
	FROM work WHERE style IS NOT NULL GROUP BY style)
SELECT style, 
CASE WHEN DESC_RNK IN (1,2,3) THEN 'Most Popular'
							  ELSE 'Least Popular' END Popularity
FROM POP WHERE DESC_RNK IN (1,2,3) OR ASC_RNK IN (1,2,3);

--22. Which artist has the most no of Portraits paintings outside USA?. 
--    Display artist name, no of paintings and the artist nationality.
select full_name as artist_name, nationality, no_of_paintings
	from (
		select a.full_name, a.nationality
		,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as rnk
		from work w
		join artist a on a.artist_id=w.artist_id
		join subject s on s.work_id=w.work_id
		join museum m on m.museum_id=w.museum_id
		where s.subject='Portraits'
		and m.country != 'USA'
		group by a.full_name, a.nationality) X
	where rnk=1;